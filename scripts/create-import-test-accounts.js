#!/usr/bin/env node

/**
 * Create 20 empty Pro-tier test accounts for data import wizard testing.
 *
 * Creates Firebase Auth users, organization documents, and membership documents
 * WITHOUT seeding any inventory, genetics, or monitoring data.
 *
 * Account specifications:
 *   - Tier: Pro
 *   - Email pattern: import1@provenance.app through import20@provenance.app
 *   - Password: demo123 (same as other demo accounts)
 *   - Organization names: "Import Test Org 1" through "Import Test Org 20"
 *   - Organization IDs: import_test_org_1 through import_test_org_20
 *   - Allowed activities: ['husbandry', 'observation', 'comment'] (Pro tier features)
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
 *     node scripts/create-import-test-accounts.js
 *
 *   # Reset existing accounts before creating (delete and recreate)
 *   node scripts/create-import-test-accounts.js --reset
 *
 *   # Create specific range of accounts (default: 1-20)
 *   node scripts/create-import-test-accounts.js --start=1 --end=10
 *
 *   # Dry run (show what would be created)
 *   node scripts/create-import-test-accounts.js --dry-run
 */

require('dotenv').config();
const { admin, db } = require('./config-json');

const args = process.argv.slice(2);

const DEFAULT_PASSWORD = 'demo123';
const DEFAULT_START = 1;
const DEFAULT_END = 20;

// Pro tier configuration (matches seed-demo.js DEMO_TIER_CONFIG.pro)
const PRO_TIER_CONFIG = {
  tier: 'pro',
  allowedActivities: ['husbandry', 'observation', 'comment'],
  supportedOrganismKinds: ['coral', 'oyster', 'kelp', 'seagrass'],
};

function argValue(prefix) {
  const match = args.find((arg) => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

function hasFlag(flag) {
  return args.includes(flag);
}

/**
 * Ensure Firebase Auth user exists, creating if necessary.
 */
async function ensureAuthUser({ email, displayName, password }) {
  const normalizedEmail = (email || '').toLowerCase();
  try {
    const existing = await admin.auth().getUserByEmail(normalizedEmail);
    if (displayName && existing.displayName !== displayName) {
      await admin.auth().updateUser(existing.uid, { displayName });
    }
    return { user: existing, created: false };
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  try {
    const user = await admin.auth().createUser({
      email: normalizedEmail,
      password: password || DEFAULT_PASSWORD,
      displayName,
      emailVerified: true,
    });
    return { user, created: true };
  } catch (error) {
    if (error?.code === 'auth/email-already-exists') {
      const existing = await admin.auth().getUserByEmail(normalizedEmail);
      return { user: existing, created: false };
    }
    throw error;
  }
}

/**
 * Delete Firebase Auth user if exists.
 */
async function deleteAuthUser(email) {
  try {
    const user = await admin.auth().getUserByEmail(email.toLowerCase());
    await admin.auth().deleteUser(user.uid);
    return true;
  } catch (error) {
    if (error?.code === 'auth/user-not-found') {
      return false;
    }
    throw error;
  }
}

/**
 * Delete organization document and its subcollections.
 */
async function deleteOrganization(orgId) {
  const orgRef = db.collection('organizations').doc(orgId);
  const orgSnap = await orgRef.get();

  if (!orgSnap.exists) {
    return false;
  }

  // Known subcollections under organization documents
  const subcollections = [
    'organismRecords',
    'groups',
    'genets',
    'comments',
    'channels',
    'members',
    'snapshots',
    'notifications',
    'audit_logs',
  ];

  for (const subcollection of subcollections) {
    const subRef = orgRef.collection(subcollection);
    const subSnap = await subRef.limit(500).get();
    if (!subSnap.empty) {
      const batch = db.batch();
      subSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }

  await orgRef.delete();
  return true;
}

/**
 * Delete user document from Firestore.
 */
async function deleteUserDocument(userId) {
  const userRef = db.collection('users').doc(userId);
  const userSnap = await userRef.get();
  if (userSnap.exists) {
    await userRef.delete();
    return true;
  }
  return false;
}

/**
 * Delete organization-scoped collections (sites, events, etc.).
 */
async function deleteOrgScopedCollections(orgId) {
  const collections = ['sites', 'events', 'brand_profiles', 'public_genets'];
  let deletedCount = 0;

  for (const collectionName of collections) {
    const query = db.collection(collectionName).where('organizationId', '==', orgId);
    const snapshot = await query.limit(500).get();
    if (!snapshot.empty) {
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      deletedCount += snapshot.docs.length;
    }
  }

  return deletedCount;
}

/**
 * Create organization document with Pro tier settings.
 */
async function createOrganization({ orgId, orgName, userId }) {
  const now = new Date().toISOString();
  const slug = orgId.replace(/_/g, '-');

  await db.collection('organizations').doc(orgId).set({
    id: orgId,
    name: orgName,
    nameLowercase: orgName.toLowerCase(),
    domain: slug,
    slug,
    urlPath: slug,
    internalPath: orgId,
    organizationId: orgId,
    modelType: 'organization',
    createdAt: now,
    updatedAt: now,
    createdById: userId,
    updatedById: userId,
    activities: ['nes', 'nis', 'op', 'gb', 'bl', 'ref'],
    speciesIds: [],
    supportedOrganismKinds: PRO_TIER_CONFIG.supportedOrganismKinds,
    allowedActivities: PRO_TIER_CONFIG.allowedActivities,
    tier: PRO_TIER_CONFIG.tier,
    metadata: {
      tier: PRO_TIER_CONFIG.tier,
      plan: PRO_TIER_CONFIG.tier,
      isDemo: false,
      isImportTestOrg: true,
    },
  });
}

/**
 * Create user document in Firestore.
 */
async function createUserDocument({ userId, email, displayName, orgId }) {
  const now = new Date().toISOString();

  await db.collection('users').doc(userId).set({
    id: userId,
    name: displayName,
    email: email.toLowerCase(),
    role: 'admin',
    organizationId: orgId,
    tagline: 'Import Test Admin',
    modelType: 'user',
    createdAt: now,
    updatedAt: now,
    createdById: userId,
    updatedById: userId,
    onboardingCompletedAt: now,
    metadata: {
      isImportTestUser: true,
      hasCompletedTour: true,
    },
  });
}

/**
 * Create membership document linking user to organization.
 */
async function createMembership({ userId, email, orgId }) {
  const now = new Date().toISOString();

  await db.collection('organizations').doc(orgId)
    .collection('members').doc(userId).set({
      uid: userId,
      memberId: userId,
      email: email.toLowerCase(),
      role: 'admin',
      organizationId: orgId,
      createdById: userId,
      joinedAt: now,
      createdAt: now,
      updatedAt: now,
    });
}

/**
 * Create a single import test account.
 */
async function createImportTestAccount({ index, reset, dryRun }) {
  const email = `import${index}@provenance.app`;
  const orgId = `import_test_org_${index}`;
  const orgName = `Import Test Org ${index}`;
  const displayName = `Import Tester ${index}`;

  if (dryRun) {
    console.log(`[DRY RUN] Would create: ${email} -> ${orgName} (${orgId})`);
    return { email, orgId, orgName, status: 'dry-run' };
  }

  // Reset if requested
  if (reset) {
    console.log(`  Resetting existing data for ${email}...`);
    const authDeleted = await deleteAuthUser(email);
    const orgDeleted = await deleteOrganization(orgId);
    const scopedDeleted = await deleteOrgScopedCollections(orgId);
    if (authDeleted || orgDeleted || scopedDeleted > 0) {
      console.log(`    Deleted: auth=${authDeleted}, org=${orgDeleted}, scoped=${scopedDeleted}`);
    }
  }

  // Create Firebase Auth user
  const { user, created: authCreated } = await ensureAuthUser({
    email,
    displayName,
    password: DEFAULT_PASSWORD,
  });
  const userId = user.uid;

  // Create organization document
  await createOrganization({ orgId, orgName, userId });

  // Create user document
  await createUserDocument({ userId, email, displayName, orgId });

  // Create membership
  await createMembership({ userId, email, orgId });

  const status = authCreated ? 'created' : 'updated';
  console.log(`  ${status.toUpperCase()}: ${email} -> ${orgName}`);

  return { email, orgId, orgName, userId, status };
}

function showHelp() {
  console.log(`
Create 20 empty Pro-tier test accounts for data import wizard testing.

Usage:
  node scripts/create-import-test-accounts.js [options]

Options:
  --help         Show this help message
  --reset        Delete existing accounts before creating (clean slate)
  --dry-run      Show what would be created without making changes
  --start=N      Start index (default: 1)
  --end=N        End index (default: 20)

Examples:
  # Create all 20 accounts
  node scripts/create-import-test-accounts.js

  # Reset and recreate all accounts
  node scripts/create-import-test-accounts.js --reset

  # Create only accounts 1-5
  node scripts/create-import-test-accounts.js --start=1 --end=5

  # Preview what would be created
  node scripts/create-import-test-accounts.js --dry-run

Account Details:
  Email pattern:  import1@provenance.app - import20@provenance.app
  Password:       demo123
  Tier:           Pro
  Features:       Husbandry, Observation, Comment, Data Import Wizard
  Status:         Empty organizations (no seed data)
`);
}

async function main() {
  if (hasFlag('--help') || hasFlag('-h')) {
    showHelp();
    process.exit(0);
  }

  const startIndex = parseInt(argValue('--start'), 10) || DEFAULT_START;
  const endIndex = parseInt(argValue('--end'), 10) || DEFAULT_END;
  const reset = hasFlag('--reset');
  const dryRun = hasFlag('--dry-run');

  console.log('\n' + '='.repeat(70));
  console.log('CREATE IMPORT TEST ACCOUNTS');
  console.log('='.repeat(70));
  console.log(`  Range: import${startIndex}@provenance.app to import${endIndex}@provenance.app`);
  console.log(`  Tier: Pro`);
  console.log(`  Password: ${DEFAULT_PASSWORD}`);
  console.log(`  Reset existing: ${reset}`);
  console.log(`  Dry run: ${dryRun}`);
  console.log('='.repeat(70) + '\n');

  const accounts = [];

  for (let i = startIndex; i <= endIndex; i++) {
    try {
      const account = await createImportTestAccount({ index: i, reset, dryRun });
      accounts.push(account);
    } catch (error) {
      console.error(`  ERROR creating import${i}@provenance.app: ${error.message}`);
      accounts.push({
        email: `import${i}@provenance.app`,
        orgId: `import_test_org_${i}`,
        status: 'error',
        error: error.message,
      });
    }
  }

  console.log('\n' + '='.repeat(70));
  console.log('IMPORT TEST ACCOUNTS SUMMARY');
  console.log('='.repeat(70));
  console.log(`\nAll accounts use password: ${DEFAULT_PASSWORD}\n`);

  const created = accounts.filter((a) => a.status === 'created').length;
  const updated = accounts.filter((a) => a.status === 'updated').length;
  const errors = accounts.filter((a) => a.status === 'error').length;
  const dryRunCount = accounts.filter((a) => a.status === 'dry-run').length;

  if (dryRun) {
    console.log(`Dry run complete. ${dryRunCount} accounts would be created.\n`);
  } else {
    console.log(`Created: ${created} | Updated: ${updated} | Errors: ${errors}\n`);
  }

  console.log('Account list:');
  accounts.forEach((a) => {
    const statusIcon = a.status === 'error' ? 'X' : a.status === 'dry-run' ? '?' : '+';
    console.log(`  [${statusIcon}] ${a.email} -> ${a.orgName || a.orgId}`);
  });

  console.log('\nPro tier features available:');
  console.log('  - Husbandry');
  console.log('  - Observation');
  console.log('  - Comment');
  console.log('  - Data Import Wizard');
  console.log('\n');
}

main().then(() => {
  console.log('Done!');
  process.exit(0);
}).catch((error) => {
  console.error('ERROR:', error.message || error);
  process.exit(1);
});
