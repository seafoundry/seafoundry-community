#!/usr/bin/env node
/**
 * Reset a user by email: remove Auth user and all Firestore docs tied to that user/orgs.
 *
 * Usage:
 *   node scripts/reset-user-email.js --email=dev@seafoundry.com --target=production --execute
 *   node scripts/reset-user-email.js --email=dev@seafoundry.com --target=emulator --execute
 *
 * Options:
 *   --email=address              Required (can also use EMAIL env var)
 *   --target=production|emulator Optional (default: production)
 *   --execute                    Perform deletions (default is dry run)
 *   --batch-size=500             Firestore batch size (default: 500)
 *   --scan-users                 Scan all user docs for email (case-insensitive)
 *   --domain=slug1,slug2         Also delete orgs matching these domains/slugs/urlPaths
 *   --verbose, -v                Verbose logging
 *   --help, -h                   Show help
 */

const args = process.argv.slice(2);
const options = {
  email: argValue('--email') || process.env.EMAIL,
  target: argValue('--target') || 'production',
  execute: args.includes('--execute'),
  dryRun: !args.includes('--execute'),
  batchSize: Number.parseInt(argValue('--batch-size') || '500', 10),
  scanUsers: args.includes('--scan-users'),
  domains: csvArgValue('--domain'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  help: args.includes('--help') || args.includes('-h'),
};

const EXCLUDED_COLLECTIONS = new Set([
  '__collection_group_ids__',
  'organizations',
  'users',
  'public_orgs',
]);

if (options.help || !options.email) {
  printHelp();
  process.exit(options.help ? 0 : 1);
}

if (!['production', 'emulator'].includes(options.target)) {
  console.error(`Invalid --target: ${options.target}`);
  printHelp();
  process.exit(1);
}

if (options.target === 'emulator') {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST =
    process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';
  process.env.GCLOUD_PROJECT =
    process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'seafoundryapp';
}

async function main() {
  const email = options.email.trim();
  const normalizedEmail = email.toLowerCase();
  const { admin, db, auth, label } = await getContext(options.target);

  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║                SeaFoundry User Reset (Email)                  ║');
  console.log('╚════════════════════════════════════════════════════════════════╝');
  console.log(`\nTarget: ${label}`);
  console.log(`Mode: ${options.dryRun ? '🔍 DRY RUN (preview only)' : '⚡ EXECUTE'}`);
  console.log(`Email: ${email}`);
  console.log(`Batch Size: ${options.batchSize}\n`);

  const authInfo = await lookupAuthUser(auth, email);
  const userDocs = await findUserDocs(db, email, normalizedEmail);
  const userIds = new Set(userDocs.map((doc) => doc.id));
  if (authInfo?.uid) {
    userIds.add(authInfo.uid);
  }

  const orgIds = new Set();
  const orgDetails = new Map();

  for (const doc of userDocs) {
    const data = doc.data();
    if (data?.organizationId) {
      orgIds.add(data.organizationId);
    }
  }

  for (const uid of userIds) {
    const orgSnap = await db.collection('organizations').where('createdById', '==', uid).get();
    orgSnap.docs.forEach((doc) => {
      orgIds.add(doc.id);
      orgDetails.set(doc.id, doc.data());
    });
  }

  if (options.domains?.length) {
    for (const domain of options.domains) {
      for (const field of ['domain', 'slug', 'urlPath']) {
        const snap = await db.collection('organizations').where(field, '==', domain).get();
        snap.docs.forEach((doc) => {
          orgIds.add(doc.id);
          orgDetails.set(doc.id, doc.data());
        });
      }
    }
  }

  console.log('Auth user:');
  if (authInfo?.uid) {
    console.log(`  - UID: ${authInfo.uid}`);
  } else {
    console.log('  - Not found');
  }

  console.log('\nFirestore user docs:');
  if (userDocs.length === 0) {
    console.log('  - None found');
  } else {
    userDocs.forEach((doc) => {
      const data = doc.data();
      console.log(`  - ${doc.id} (org: ${data?.organizationId ?? 'n/a'})`);
    });
  }

  console.log('\nOrganizations to delete:');
  if (orgIds.size === 0) {
    console.log('  - None found');
  } else {
    for (const orgId of orgIds) {
      const details = orgDetails.get(orgId) || {};
      console.log(
        `  - ${orgId} (${details.name ?? 'unknown'} | ${details.domain ?? 'n/a'})`,
      );
    }
  }

  if (options.dryRun) {
    console.log('\n💡 Dry run complete. Re-run with --execute to delete data.');
    process.exit(0);
  }

  if (authInfo?.uid) {
    console.log('\n👤 Deleting Firebase Auth user...');
    await auth.deleteUser(authInfo.uid);
    console.log('  ✅ Auth user deleted');
  }

  if (userDocs.length > 0) {
    console.log('\n👤 Deleting user documents...');
    for (const doc of userDocs) {
      await deleteDocumentRecursive(db, doc.ref);
      if (options.verbose) {
        console.log(`  ✅ Deleted user doc ${doc.id}`);
      }
    }
  }

  if (orgIds.size > 0) {
    console.log('\n🏢 Deleting organizations and subcollections...');
    for (const orgId of orgIds) {
      const orgRef = db.collection('organizations').doc(orgId);
      await deleteDocumentRecursive(db, orgRef);
      if (options.verbose) {
        console.log(`  ✅ Deleted org ${orgId}`);
      }
      const publicOrgRef = db.collection('public_orgs').doc(orgId);
      await deleteDocumentRecursive(db, publicOrgRef);
    }
  }

  if (orgIds.size > 0) {
    console.log('\n🧹 Deleting org-scoped root docs...');
    const collections = await db.listCollections();
    const collectionNames = collections.map((col) => col.id);

    for (const name of collectionNames) {
      if (EXCLUDED_COLLECTIONS.has(name)) continue;
      for (const orgId of orgIds) {
        await deleteDocsByOrganizationId(db, name, orgId);
      }
    }
  }

  console.log('\n✅ Reset complete.');
}

function argValue(prefix) {
  const match = args.find((arg) => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

function csvArgValue(prefix) {
  const raw = argValue(prefix);
  if (!raw) return null;
  return raw
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
}

function printHelp() {
  console.log(`
🔄 SeaFoundry User Reset (Email)

Deletes Firebase Auth user and Firestore docs tied to the user's org(s).

Usage:
  node scripts/reset-user-email.js --email=dev@seafoundry.com --target=production --execute
  node scripts/reset-user-email.js --email=dev@seafoundry.com --target=emulator --execute

Options:
  --email=address              Required (or EMAIL env var)
  --target=production|emulator Default: production
  --execute                    Perform deletions (default is dry run)
  --batch-size=500             Firestore batch size (default: 500)
  --scan-users                 Scan all users for case-insensitive email matches
  --domain=slug1,slug2         Also delete orgs matching domains/slugs/urlPaths
  --verbose, -v                Verbose logging
  --help, -h                   Show help
`);
}

async function getContext(target) {
  if (target === 'production') {
    const { admin, db } = require('./config-json');
    return { admin, db, auth: admin.auth(), label: 'production' };
  }

  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || 'seafoundryapp',
    });
  }
  return { admin, db: admin.firestore(), auth: admin.auth(), label: 'emulator' };
}

async function lookupAuthUser(auth, email) {
  try {
    const user = await auth.getUserByEmail(email);
    return { uid: user.uid, email: user.email };
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return null;
    }
    throw error;
  }
}

async function findUserDocs(db, email, normalizedEmail) {
  const found = new Map();
  const variants = new Set([email, normalizedEmail]);

  for (const value of variants) {
    const snap = await db.collection('users').where('email', '==', value).get();
    snap.docs.forEach((doc) => found.set(doc.id, doc));
  }

  if (found.size === 0 && options.scanUsers) {
    const snap = await db.collection('users').get();
    snap.docs.forEach((doc) => {
      const data = doc.data();
      const docEmail = (data?.email ?? '').toLowerCase();
      if (docEmail === normalizedEmail) {
        found.set(doc.id, doc);
      }
    });
  }

  return Array.from(found.values());
}

async function deleteDocumentRecursive(db, docRef) {
  const subcollections = await docRef.listCollections();
  for (const subcol of subcollections) {
    await deleteCollectionRecursive(db, subcol);
  }
  try {
    await docRef.delete();
  } catch (error) {
    if (options.verbose) {
      console.log(`  ⚠️  Failed to delete ${docRef.path}: ${error.message}`);
    }
  }
}

async function deleteCollectionRecursive(db, collectionRef) {
  let hasMore = true;
  while (hasMore) {
    const snapshot = await collectionRef.limit(options.batchSize).get();
    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      const subcollections = await doc.ref.listCollections();
      for (const subcol of subcollections) {
        await deleteCollectionRecursive(db, subcol);
      }
      batch.delete(doc.ref);
    }
    await batch.commit();

    if (snapshot.size < options.batchSize) {
      hasMore = false;
    }
  }
}

async function deleteDocsByOrganizationId(db, collectionName, orgId) {
  let hasMore = true;
  while (hasMore) {
    const snapshot = await db
      .collection(collectionName)
      .where('organizationId', '==', orgId)
      .limit(options.batchSize)
      .get();
    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    for (const doc of snapshot.docs) {
      await deleteDocumentRecursive(db, doc.ref);
      if (options.verbose) {
        console.log(`  ✅ ${collectionName}: deleted ${doc.id}`);
      }
    }

    if (snapshot.size < options.batchSize) {
      hasMore = false;
    }
  }
}

main().catch((error) => {
  console.error('\n❌ Reset failed:', error.message);
  if (options.verbose) {
    console.error(error.stack);
  }
  process.exit(1);
});
