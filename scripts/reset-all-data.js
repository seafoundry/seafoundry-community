#!/usr/bin/env node
/**
 * Full Data Reset Script
 *
 * Deletes ALL Firestore collections and (optionally) ALL Firebase Auth users.
 * Supports production or emulator targets.
 *
 * Usage:
 *   node scripts/reset-all-data.js --target=production --execute
 *   node scripts/reset-all-data.js --target=emulator --execute
 *
 * Options:
 *   --target=production|emulator   Required
 *   --execute                      Actually perform deletions (default is dry run)
 *   --keep-auth-users              Skip deleting Auth users
 *   --force, --yes                 Skip interactive confirmations
 *   --include-crc                  Also delete CRC/HOG collections (preserved by default)
 *   --include-demo                 Also delete demo collections (preserved by default)
 *   --only=col1,col2               Delete only these collections
 *   --skip=col1,col2               Skip these collections
 *   --max-collections=N            Limit to first N collections (after filters)
 *   --skip-subcollections          Skip deleting subcollections for all collections
 *   --skip-subcollections-for=col1,col2
 *                                 Skip subcollections for specific collections
 *   --max-docs=N                   Stop after deleting N docs per collection
 *   --batch-size=500               Firestore batch size
 *   --verbose, -v                  Verbose logging
 *   --help, -h                     Show help
 */

const readline = require('readline');
const path = require('path');
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
const options = {
  target: argValue('--target'),
  execute: args.includes('--execute'),
  dryRun: !args.includes('--execute'),
  keepAuthUsers: args.includes('--keep-auth-users'),
  force: args.includes('--force') || args.includes('--yes'),
  includeCrc: args.includes('--include-crc'),
  includeDemo: args.includes('--include-demo'),
  preserveDemoOrgs: args.includes('--preserve-demo-orgs'),
  deleteNonDemoAuthUsers: args.includes('--delete-non-demo-auth-users'),
  demoOrgIds: csvArgValue('--demo-orgs'),
  onlyCollections: csvArgValue('--only'),
  skipCollections: csvArgValue('--skip'),
  maxCollections: numberArgValue('--max-collections'),
  skipSubcollections: args.includes('--skip-subcollections'),
  skipSubcollectionsFor: csvArgValue('--skip-subcollections-for'),
  maxDocs: numberArgValue('--max-docs'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  batchSize: Number.parseInt(argValue('--batch-size') || '500', 10),
  help: args.includes('--help') || args.includes('-h'),
};

const EXCLUDED_COLLECTIONS = new Set(['__collection_group_ids__']);
const DEFAULT_DEMO_ORG_IDS = [
  'demo_org_community',
  'demo_org_pro',
  'demo_org_scale',
];
const ORG_SCOPED_COLLECTIONS = [
  'events',
  'sites',
  'groups',
  'genets',
  'organismRecords',
  'outplant_events',
  'outplant_tags',
  'monitoring_observations',
  'missions',
  'deliverables',
  'permits',
  'vessels',
  'invitations',
  'reports',
  'brand_profiles',
  'ecological_surveys',
  'user_profiles',
  'training_progress',
  'training_sops',
  'snapshots',
  'public_orgs',
];
const CRC_COLLECTIONS = new Set([
  'historical_datasets',
  'historical_filter_options',
  'historical_impact_points',
  'historical_org_registry',
  'historical_outplant_events',
  'historical_reef_aggregates',
  'provenance_crosswalk',
  'community_provenances',
  'community_genetics_provenances',
  'community_genetics_aliases',
  'community_genetics_sfids',
  'taxonomy',
  'taxonomy_species',
  'taxonomy_provenances',
  'taxonomy_lineages',
  'taxonomy_overrides',
  'species',
  'group_types',
  'site_types',
  'groupTypes',
  'siteTypes',
  'training_media',
  'training_progress',
  'training_sops',
]);
const DEMO_COLLECTIONS = new Set([
  'demo_organizations',
  'demo_sites',
  'demo_users',
]);

if (options.help || !options.target) {
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
  const { admin, db, auth, label } = await getContext(options.target);

  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║                SeaFoundry Full Data Reset                      ║');
  console.log('╚════════════════════════════════════════════════════════════════╝');
  console.log(`\nTarget: ${label}`);
  console.log(`Mode: ${options.dryRun ? '🔍 DRY RUN (preview only)' : '⚡ EXECUTE'}`);
  console.log(`Delete Auth Users: ${options.keepAuthUsers ? 'No' : 'Yes'}`);
  if (options.force) {
    console.log('Confirmations: Skipped (--force)');
  }
  if (!options.includeCrc) {
    console.log('Preserve CRC/HOG: Yes');
  }
  if (!options.includeDemo) {
    console.log('Preserve Demo: Yes');
  }
  if (options.preserveDemoOrgs) {
    const demoIds =
      options.demoOrgIds && options.demoOrgIds.length > 0
        ? options.demoOrgIds
        : DEFAULT_DEMO_ORG_IDS;
    console.log(`Preserve Demo Orgs: ${demoIds.join(', ')}`);
    if (options.deleteNonDemoAuthUsers && !options.keepAuthUsers) {
      console.log('Delete Non-Demo Auth Users: Yes');
    }
  }
  if (options.onlyCollections?.length) {
    console.log(`Only Collections: ${options.onlyCollections.join(', ')}`);
  }
  if (options.skipCollections?.length) {
    console.log(`Skip Collections: ${options.skipCollections.join(', ')}`);
  }
  if (Number.isFinite(options.maxCollections)) {
    console.log(`Max Collections: ${options.maxCollections}`);
  }
  if (options.skipSubcollections) {
    console.log('Skip Subcollections: Yes');
  } else if (options.skipSubcollectionsFor?.length) {
    console.log(`Skip Subcollections For: ${options.skipSubcollectionsFor.join(', ')}`);
  }
  if (Number.isFinite(options.maxDocs)) {
    console.log(`Max Docs Per Collection: ${options.maxDocs}`);
  }
  console.log(`Batch Size: ${options.batchSize}\n`);

  const collections = await db.listCollections();
  let collectionNames = collections
    .map((col) => col.id)
    .filter((name) => !EXCLUDED_COLLECTIONS.has(name))
    .filter((name) => {
      if (!options.includeCrc && CRC_COLLECTIONS.has(name)) return false;
      if (!options.includeDemo && DEMO_COLLECTIONS.has(name)) return false;
      return true;
    });

  if (options.onlyCollections?.length) {
    const onlySet = new Set(options.onlyCollections);
    collectionNames = collectionNames.filter((name) => onlySet.has(name));
  }

  if (options.skipCollections?.length) {
    const skipSet = new Set(options.skipCollections);
    collectionNames = collectionNames.filter((name) => !skipSet.has(name));
  }

  if (Number.isFinite(options.maxCollections)) {
    collectionNames = collectionNames.slice(0, Math.max(0, options.maxCollections));
  }

  if (collectionNames.length === 0) {
    console.log('✅ No collections found to delete.');
    process.exit(0);
  }

  console.log('Collections to delete:');
  for (const name of collectionNames) {
    console.log(`  - ${name}`);
  }

  let authUserCount = null;
  if (!options.keepAuthUsers) {
    authUserCount = await countAuthUsers(auth);
    console.log(`\nAuth users to delete: ${authUserCount}`);
  }

  if (options.dryRun) {
    console.log('\n💡 Dry run complete. Re-run with --execute to delete data.');
    process.exit(0);
  }

  if (!options.force) {
    const confirmed = await promptConfirmation(
      '\n🚨 Type "yes" to PERMANENTLY DELETE all Firestore data: ',
    );
    if (!confirmed) {
      console.log('\n❌ Deletion cancelled.');
      process.exit(0);
    }

    if (!options.keepAuthUsers) {
      const authConfirmed = await promptConfirmation(
        '\n⚠️  Type "yes" again to delete ALL Firebase Auth users: ',
      );
      if (!authConfirmed) {
        console.log('\n❌ Auth user deletion cancelled (Firestore deletion will proceed).');
        options.keepAuthUsers = true;
      }
    }
  }

  console.log('\n🚀 Deleting Firestore data...\n');

  const demoOrgIds =
    options.demoOrgIds && options.demoOrgIds.length > 0
      ? options.demoOrgIds
      : DEFAULT_DEMO_ORG_IDS;

  if (options.preserveDemoOrgs) {
    const { demoUserIds, demoUserEmails } = await collectDemoUsers(
      db,
      demoOrgIds,
    );
    await deleteNonDemoOrganizations(db, demoOrgIds);
    const deletedUserDocs = await deleteNonDemoUsers(db, demoOrgIds);
    await deleteNonDemoOrgScopedDocs(db, demoOrgIds);
    let deletedAuthUsers = 0;
    if (!options.keepAuthUsers && options.deleteNonDemoAuthUsers) {
      console.log('\n👤 Deleting non-demo Firebase Auth users...');
      deletedAuthUsers = await deleteNonDemoAuthUsers(
        auth,
        demoUserIds,
        demoUserEmails,
      );
    }
    await maybeRunPidCrosswalk({
      deletedUserDocs,
      deletedAuthUsers,
    });
    console.log('\n✅ Non-demo data deletion complete.');
    process.exit(0);
  }

  const results = {};
  for (const name of collectionNames) {
    console.log(`📂 Deleting collection: ${name}`);
    try {
      const deleted = await deleteCollectionRecursive(db, db.collection(name), name);
      results[name] = deleted;
      console.log(`    ✅ Deleted ${deleted} documents`);
    } catch (error) {
      console.warn(`    ⚠️  Failed to delete ${name}: ${error.message}`);
    }
  }

  let deletedAuthUsers = 0;
  if (!options.keepAuthUsers) {
    console.log('\n👤 Deleting Firebase Auth users...');
    deletedAuthUsers = await deleteAllAuthUsers(admin);
  }
  await maybeRunPidCrosswalk({
    deletedUserDocs: results.users ?? 0,
    deletedAuthUsers,
  });

  console.log('\n╔════════════════════════════════════════════════════════════════╗');
  console.log('║                      RESET COMPLETE                            ║');
  console.log('╚════════════════════════════════════════════════════════════════╝');
  console.log(`\nDeleted collections: ${Object.keys(results).length}`);
  if (!options.keepAuthUsers) {
    console.log(`Deleted Auth users: ${deletedAuthUsers}`);
  }
  console.log('\n✅ Full reset complete.');
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

function numberArgValue(prefix) {
  const raw = argValue(prefix);
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function printHelp() {
  console.log(`
🔄 SeaFoundry Full Data Reset

Deletes ALL Firestore collections and (optionally) ALL Firebase Auth users.

Usage:
  node scripts/reset-all-data.js --target=production --execute
  node scripts/reset-all-data.js --target=emulator --execute

Options:
  --target=production|emulator   Required
  --execute                      Actually perform deletions (default is dry run)
  --keep-auth-users              Skip deleting Auth users
  --force, --yes                 Skip interactive confirmations
  --include-crc                  Also delete CRC/HOG collections (preserved by default)
  --include-demo                 Also delete demo collections (preserved by default)
  --preserve-demo-orgs           Only delete data not tied to demo org IDs
  --demo-orgs=org1,org2          Override demo org IDs (default: demo_org_community, demo_org_pro, demo_org_scale)
  --delete-non-demo-auth-users   Delete Firebase Auth users not in demo orgs (requires --preserve-demo-orgs)
  --only=col1,col2               Delete only these collections
  --skip=col1,col2               Skip these collections
  --max-collections=N            Limit to first N collections (after filters)
  --skip-subcollections          Skip deleting subcollections for all collections
  --skip-subcollections-for=col1,col2
                                Skip subcollections for specific collections
  --max-docs=N                   Stop after deleting N docs per collection
  --batch-size=500               Firestore batch size
  --verbose, -v                  Verbose logging
  --help, -h                     Show this help message
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

function promptConfirmation(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(message, (answer) => {
      rl.close();
      resolve(answer.toLowerCase() === 'yes');
    });
  });
}

async function deleteCollectionRecursive(db, collectionRef, path) {
  let totalDeleted = 0;
  let hasMore = true;
  const shouldSkipSubcollections =
    options.skipSubcollections ||
    (options.skipSubcollectionsFor?.includes(collectionRef.id) ?? false);

  while (hasMore) {
    const snapshot = await collectionRef.limit(options.batchSize).get();
    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    const batch = db.batch();

    for (const doc of snapshot.docs) {
      if (!shouldSkipSubcollections) {
        const subcollections = await doc.ref.listCollections();
        for (const subcol of subcollections) {
          totalDeleted += await deleteCollectionRecursive(
            db,
            subcol,
            `${path}/${doc.id}/${subcol.id}`,
          );
        }
      }
      batch.delete(doc.ref);
    }

    await batch.commit();
    totalDeleted += snapshot.size;

    if (options.verbose) {
      console.log(
        `    Deleted ${snapshot.size} documents from ${path} (${totalDeleted} total)`,
      );
    }

    if (snapshot.size < options.batchSize) {
      hasMore = false;
    }

    if (Number.isFinite(options.maxDocs) && totalDeleted >= options.maxDocs) {
      if (options.verbose) {
        console.log(`    ⏭️  Stopping early after ${totalDeleted} docs (max docs reached)`);
      }
      hasMore = false;
    }
  }

  return totalDeleted;
}

async function deleteNonDemoOrganizations(db, demoOrgIds) {
  console.log('📂 Deleting non-demo organizations...');
  const snapshot = await db.collection('organizations').get();
  let deleted = 0;
  for (const doc of snapshot.docs) {
    if (demoOrgIds.includes(doc.id)) {
      continue;
    }
    const subcollections = await doc.ref.listCollections();
    for (const subcol of subcollections) {
      deleted += await deleteCollectionRecursive(
        db,
        subcol,
        `${doc.ref.path}/${subcol.id}`,
      );
    }
    await doc.ref.delete();
    deleted += 1;
  }
  console.log(`    ✅ Deleted ${deleted} non-demo org docs/subdocs`);
}

async function deleteNonDemoUsers(db, demoOrgIds) {
  console.log('📂 Deleting non-demo users...');
  let deleted = 0;
  if (demoOrgIds.length === 0) return deleted;

  const batchDelete = async (query) => {
    const snap = await query.limit(options.batchSize).get();
    if (snap.empty) return 0;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    return snap.size;
  };

  // Delete users whose organizationId is not a demo org.
  while (true) {
    const count = await batchDelete(
      db.collection('users').where('organizationId', 'not-in', demoOrgIds),
    );
    deleted += count;
    if (count < options.batchSize) break;
  }

  // Delete users missing organizationId (treat as non-demo).
  while (true) {
    const count = await batchDelete(
      db.collection('users').where('organizationId', '==', null),
    );
    deleted += count;
    if (count < options.batchSize) break;
  }

  console.log(`    ✅ Deleted ${deleted} non-demo user docs`);
  return deleted;
}

async function deleteNonDemoOrgScopedDocs(db, demoOrgIds) {
  console.log('📂 Deleting non-demo org-scoped root docs...');
  let total = 0;
  for (const collectionName of ORG_SCOPED_COLLECTIONS) {
    const collectionRef = db.collection(collectionName);
    let hasMore = true;
    let deleted = 0;
    while (hasMore) {
      const snapshot = await collectionRef
        .where('organizationId', 'not-in', demoOrgIds)
        .limit(options.batchSize)
        .get();
      if (snapshot.empty) {
        hasMore = false;
        break;
      }
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      deleted += snapshot.size;
      total += snapshot.size;
      if (snapshot.size < options.batchSize) {
        hasMore = false;
      }
    }
    if (deleted > 0 || options.verbose) {
      console.log(`    ✅ ${collectionName}: deleted ${deleted} docs`);
    }
  }
  console.log(`    ✅ Deleted ${total} non-demo org-scoped docs`);
}

async function collectDemoUsers(db, demoOrgIds) {
  const demoUserIds = new Set();
  const demoUserEmails = new Set();
  for (const orgId of demoOrgIds) {
    const snapshot = await db
      .collection('users')
      .where('organizationId', '==', orgId)
      .get();
    snapshot.docs.forEach((doc) => {
      demoUserIds.add(doc.id);
      const email = (doc.data()?.email ?? '').toLowerCase().trim();
      if (email) demoUserEmails.add(email);
    });
  }
  return { demoUserIds, demoUserEmails };
}

async function deleteNonDemoAuthUsers(auth, demoUserIds, demoUserEmails) {
  let deleted = 0;
  let nextPageToken;
  do {
    const list = await auth.listUsers(1000, nextPageToken);
    for (const userRecord of list.users) {
      const email = (userRecord.email || '').toLowerCase().trim();
      const isDemo =
        demoUserIds.has(userRecord.uid) ||
        (email && demoUserEmails.has(email)) ||
        isDemoEmail(email);
      if (isDemo) continue;
      try {
        await auth.deleteUser(userRecord.uid);
        deleted++;
        if (options.verbose && deleted % 100 === 0) {
          console.log(`    Deleted ${deleted} non-demo auth users...`);
        }
      } catch (error) {
        console.warn(
          `    ⚠️  Failed to delete auth user ${userRecord.uid}: ${error.message}`,
        );
      }
    }
    nextPageToken = list.pageToken;
  } while (nextPageToken);
  console.log(`    ✅ Deleted ${deleted} non-demo Firebase Auth users`);
  return deleted;
}

function isDemoEmail(email) {
  if (!email) return false;
  const parts = email.toLowerCase().split('@');
  if (parts.length !== 2) return false;
  const [local, domain] = parts;
  if (domain !== 'provenance.app') return false;
  const base = local.replace(/[0-9]+$/, '');
  return ['community', 'pro', 'scale'].includes(base);
}

async function maybeRunPidCrosswalk({ deletedUserDocs, deletedAuthUsers }) {
  if (!deletedUserDocs && !deletedAuthUsers) {
    return;
  }
  console.log('\n🔁 Regenerating PID crosswalk (users removed)...');
  const scriptPath = path.join(__dirname, 'generate-pid-crosswalk.js');
  const result = spawnSync(process.execPath, [scriptPath, '--execute'], {
    stdio: 'inherit',
  });
  if (result.status !== 0) {
    console.warn('    ⚠️  PID crosswalk generation failed.');
  }
}

async function countAuthUsers(auth) {
  let total = 0;
  let nextPageToken;
  do {
    const list = await auth.listUsers(1000, nextPageToken);
    total += list.users.length;
    nextPageToken = list.pageToken;
  } while (nextPageToken);
  return total;
}

async function deleteAllAuthUsers(admin) {
  let deleted = 0;
  let nextPageToken;

  do {
    const list = await admin.auth().listUsers(1000, nextPageToken);
    for (const userRecord of list.users) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
        deleted++;
        if (options.verbose && deleted % 100 === 0) {
          console.log(`    Deleted ${deleted} auth users...`);
        }
      } catch (error) {
        console.warn(`    ⚠️  Failed to delete auth user ${userRecord.uid}: ${error.message}`);
      }
    }
    nextPageToken = list.pageToken;
  } while (nextPageToken);

  console.log(`    ✅ Deleted ${deleted} Firebase Auth users`);
  return deleted;
}

main().catch((error) => {
  console.error('\n❌ Reset failed:', error.message);
  if (options.verbose) {
    console.error(error.stack);
  }
  process.exit(1);
});
