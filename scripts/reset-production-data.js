#!/usr/bin/env node

/**
 * Production Data Reset Script
 *
 * Resets production data by clearing all active users and org data from the database,
 * while retaining CRC data, taxonomy, images, and other shared/reference data.
 * Also resets PID assignment counters after accounting for CRC data.
 *
 * IMPORTANT: This script MUST be run after the Data Field Unification (SOT) work
 * to wipe the production database for all users so new data is consistent with
 * the canonical field structure:
 *   - genetId at top level (not in foreignKeys or metadata)
 *   - foreignKeys.genetId synced with top-level genetId
 *   - physicalFormId instead of morphologyId
 *   - SizeSpec format (sizeBandId) instead of sizeClass
 *   - No metadata.genetId or metadata.provenanceId
 *   - No foreignKeys.genet (use foreignKeys.genetId)
 *   - No lineageId on organisms
 *
 * PRESERVED (GLOBAL/SHARED) DATA:
 *   - historical_* collections (CRC data)
 *   - taxonomy, taxonomy_species, taxonomy_provenances, taxonomy_lineages
 *   - provenance_crosswalk, community_provenances, community_genetics_*
 *   - species, group_types, site_types, tier_manifest, training_media
 *   - taxonomy_overrides
 *   - Cloud Storage (images, exports, etc.)
 *
 * DELETED DATA:
 *   - organizations (and all nested subcollections)
 *   - users
 *   - sites, groups, genets, organismRecords
 *   - events (tasks, husbandry, monitoring, outplant, etc.)
 *   - invitations
 *   - public_orgs
 *   - provenanceIds (counter documents - will be rebuilt)
 *   - Any other org-scoped root collections
 *
 * Usage:
 *   node scripts/reset-production-data.js --dry-run
 *   node scripts/reset-production-data.js --execute --reset-pids
 *   node scripts/reset-production-data.js --execute --reset-pids --delete-auth-users
 *
 * Options:
 *   --dry-run              Preview what will be deleted (DEFAULT)
 *   --execute              Actually perform deletions
 *   --reset-pids           Reset PID counters after CRC data accounting
 *   --delete-auth-users    Also delete Firebase Auth users (requires extra confirmation)
 *   --skip-storage         Skip listing/preserving storage (faster for Firestore-only reset)
 *   --verbose, -v          Show detailed progress
 *   --help, -h             Show this help message
 *
 * @tier: internal
 */

require('dotenv').config();
const { admin, db } = require('./config-json');
const { GLOBAL_COLLECTIONS } = require('./constants');
const readline = require('readline');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
  dryRun: !args.includes('--execute'),
  execute: args.includes('--execute'),
  resetPids: args.includes('--reset-pids'),
  deleteAuthUsers: args.includes('--delete-auth-users'),
  skipStorage: args.includes('--skip-storage'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  help: args.includes('--help') || args.includes('-h'),
  batchSize: 500,
};

// Extended list of collections to preserve (beyond GLOBAL_COLLECTIONS)
const PRESERVED_COLLECTIONS = new Set([
  ...GLOBAL_COLLECTIONS,
  // Historical CRC data
  'historical_datasets',
  'historical_filter_options',
  'historical_org_registry',
  // Firebase internal
  '__collection_group_ids__',
]);

// Collections that contain org-scoped data at root level
const ORG_SCOPED_ROOT_COLLECTIONS = [
  'sites',
  'groups',
  'genets',
  'organismRecords',
  'events',
  'invitations',
  'reports',
  'brand_profiles',
  'ecological_surveys',
];

// Show help
if (options.help) {
  console.log(`
🔄 SeaFoundry Production Data Reset Script

Clears all organization and user data while preserving CRC/taxonomy/reference data.

Usage: node scripts/reset-production-data.js [options]

Options:
  --dry-run              Preview what will be deleted (DEFAULT)
  --execute              Actually perform deletions
  --reset-pids           Reset PID counters after accounting for CRC data
  --delete-auth-users    Also delete Firebase Auth users
  --skip-storage         Skip storage operations
  --verbose, -v          Show detailed progress
  --help, -h             Show this help message

Examples:
  # Preview what will be deleted (dry run)
  node scripts/reset-production-data.js

  # Reset data and PID counters
  node scripts/reset-production-data.js --execute --reset-pids

  # Full reset including auth users
  node scripts/reset-production-data.js --execute --reset-pids --delete-auth-users

PRESERVED DATA:
  - CRC/Historical data (historical_* collections)
  - Taxonomy data (taxonomy_*, species)
  - Reference data (group_types, site_types, tier_manifest)
  - Provenance crosswalks (community tier genetics)
  - Training media
  - Cloud Storage (images, exports)

DELETED DATA:
  - Organizations and all nested data
  - Users and memberships
  - Sites, groups, organisms, genets
  - Events (tasks, monitoring, husbandry, etc.)
  - Invitations
  - PID counters (rebuilt if --reset-pids)
`);
  process.exit(0);
}

// Prompt for confirmation
async function promptConfirmation(message) {
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

// Get all collections in Firestore
async function getAllCollections() {
  const collections = await db.listCollections();
  return collections.map((col) => col.id);
}

// Check if a collection should be preserved
function shouldPreserve(collectionName) {
  return PRESERVED_COLLECTIONS.has(collectionName);
}

// Get all subcollections for a document
async function getAllSubcollections(docRef) {
  return docRef.listCollections();
}

// Count documents in a collection including subcollections
async function countDocumentsRecursive(collectionRef, path = '') {
  let count = 0;
  const snapshot = await collectionRef.limit(10000).get();
  count += snapshot.size;

  for (const doc of snapshot.docs) {
    const subcollections = await getAllSubcollections(doc.ref);
    for (const subcol of subcollections) {
      const subCount = await countDocumentsRecursive(
        subcol,
        `${path}/${doc.id}/${subcol.id}`,
      );
      count += subCount;
    }
  }

  return count;
}

// Recursively delete all documents and subcollections
async function deleteCollectionRecursive(collectionRef, path = '') {
  let totalDeleted = 0;
  let hasMore = true;

  while (hasMore) {
    const snapshot = await collectionRef.limit(options.batchSize).get();

    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    const batch = db.batch();

    for (const doc of snapshot.docs) {
      // First, recursively delete all subcollections
      const subcollections = await getAllSubcollections(doc.ref);
      for (const subcol of subcollections) {
        const subDeleted = await deleteCollectionRecursive(
          subcol,
          `${path}/${doc.id}/${subcol.id}`,
        );
        totalDeleted += subDeleted;
      }

      // Then delete the document itself
      batch.delete(doc.ref);
    }

    await batch.commit();
    totalDeleted += snapshot.size;

    if (options.verbose) {
      console.log(
        `    Deleted ${snapshot.size} documents from ${path || collectionRef.path} (${totalDeleted} total)`,
      );
    }

    if (snapshot.size < options.batchSize) {
      hasMore = false;
    }
  }

  return totalDeleted;
}

// Delete org-scoped documents from root collections
async function deleteOrgScopedRootDocuments() {
  let totalDeleted = 0;
  const allCollections = await getAllCollections();

  for (const collectionName of allCollections) {
    if (shouldPreserve(collectionName)) {
      if (options.verbose) {
        console.log(`  ⏭️  Skipping preserved collection: ${collectionName}`);
      }
      continue;
    }

    // Check if collection has organizationId field
    if (ORG_SCOPED_ROOT_COLLECTIONS.includes(collectionName)) {
      console.log(`  📂 Deleting all documents in: ${collectionName}`);
      const deleted = await deleteCollectionRecursive(
        db.collection(collectionName),
        collectionName,
      );
      totalDeleted += deleted;
      console.log(`    ✅ Deleted ${deleted} documents`);
    }
  }

  return totalDeleted;
}

// Delete all organizations and their nested data
async function deleteAllOrganizations() {
  console.log('  📂 Deleting all organizations and nested data...');
  const orgsRef = db.collection('organizations');
  const deleted = await deleteCollectionRecursive(orgsRef, 'organizations');
  console.log(`    ✅ Deleted ${deleted} organization documents (including subcollections)`);
  return deleted;
}

// Delete all users
async function deleteAllUsers() {
  console.log('  📂 Deleting all user documents...');
  const usersRef = db.collection('users');
  const deleted = await deleteCollectionRecursive(usersRef, 'users');
  console.log(`    ✅ Deleted ${deleted} user documents`);
  return deleted;
}

// Delete public_orgs
async function deletePublicOrgs() {
  console.log('  📂 Deleting public_orgs...');
  const publicOrgsRef = db.collection('public_orgs');
  const deleted = await deleteCollectionRecursive(publicOrgsRef, 'public_orgs');
  console.log(`    ✅ Deleted ${deleted} public_orgs documents`);
  return deleted;
}

// Delete provenanceIds (counter documents)
async function deleteProvenanceIds() {
  console.log('  📂 Deleting provenanceIds counter documents...');
  const provIdRef = db.collection('provenanceIds');
  const deleted = await deleteCollectionRecursive(provIdRef, 'provenanceIds');
  console.log(`    ✅ Deleted ${deleted} provenanceId counter documents`);
  return deleted;
}

// Map 4-letter species codes to full Firestore species IDs.
// The Dart ProvenanceIdService uses the full speciesId as the counter
// document key (provenanceIds/{speciesId}), so the reset script must
// Canonical short format species IDs matching taxonomy_species collection
const SPECIES_CODE_TO_ID = {
  APAL: 'apal',
  ACER: 'acer',
  OFAV: 'ofav',
  OANN: 'oann',
  OFRA: 'ofra',
  DCYL: 'dcyl',
  APRO: 'apro',
  MYFE: 'myfe',
  PAST: 'past',
  PSTR: 'pstr',
  CNAT: 'cnat',
  MCAV: 'mcav',
};

// Load PID crosswalk and calculate next PID values per species
async function calculateNextPidValues() {
  const pidCrosswalkPath = path.join(__dirname, '..', 'crc_db', 'pid_crosswalk.json');

  if (!fs.existsSync(pidCrosswalkPath)) {
    console.warn('  ⚠️  Warning: pid_crosswalk.json not found, using default counters');
    return {};
  }

  const crosswalkData = JSON.parse(fs.readFileSync(pidCrosswalkPath, 'utf-8'));
  const nextValues = {};

  // For each species, the next PID should be totalGenotypes + 1.
  // Key by full speciesId to match the Dart ProvenanceIdService document keys.
  for (const [code, stats] of Object.entries(crosswalkData.bySpecies)) {
    const speciesId = SPECIES_CODE_TO_ID[code];
    if (!speciesId) {
      console.warn(`  ⚠️  No speciesId mapping for code ${code}, skipping`);
      continue;
    }
    nextValues[speciesId] = { count: stats.totalGenotypes, code };
  }

  console.log('  📊 Next PID values per species (accounting for CRC data):');
  for (const [speciesId, { count, code }] of Object.entries(nextValues)) {
    console.log(`    ${code} (${speciesId}): Next PID will be PID-${code}-${String(count + 1).padStart(4, '0')}`);
  }

  return nextValues;
}

// Reset PID counters after CRC data
async function resetPidCounters(nextValues) {
  if (Object.keys(nextValues).length === 0) {
    console.log('  ⏭️  No PID values to set (crosswalk not loaded)');
    return;
  }

  console.log('  🔄 Resetting PID counters...');
  const batch = db.batch();
  const now = new Date().toISOString();

  for (const [speciesId, { count, code }] of Object.entries(nextValues)) {
    // Write counter document keyed by full speciesId (matches Dart ProvenanceIdService)
    const docRef = db.collection('provenanceIds').doc(speciesId);
    batch.set(docRef, {
      next: count,
      createdAt: now,
      updatedAt: now,
      source: 'production-reset',
      note: `Reset after CRC data accounting (${count} existing ${code} PIDs)`,
    });
  }

  await batch.commit();
  console.log(`    ✅ Set ${Object.keys(nextValues).length} PID counters`);
}

// Delete all Firebase Auth users (optional, requires extra confirmation)
async function deleteAllAuthUsers() {
  console.log('  👤 Deleting Firebase Auth users...');

  let deletedCount = 0;
  let nextPageToken;

  do {
    const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);

    for (const userRecord of listUsersResult.users) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
        deletedCount++;

        if (options.verbose && deletedCount % 100 === 0) {
          console.log(`    Deleted ${deletedCount} auth users...`);
        }
      } catch (error) {
        console.warn(`    ⚠️  Failed to delete auth user ${userRecord.uid}: ${error.message}`);
      }
    }

    nextPageToken = listUsersResult.pageToken;
  } while (nextPageToken);

  console.log(`    ✅ Deleted ${deletedCount} Firebase Auth users`);
  return deletedCount;
}

// Count all data to be deleted
async function countDataToDelete() {
  const counts = {
    organizations: 0,
    users: 0,
    orgScopedRoot: 0,
    publicOrgs: 0,
    provenanceIds: 0,
    preserved: 0,
    authUsers: 0,
  };

  console.log('📊 Counting data to delete...\n');

  // Count organizations
  console.log('  Counting organizations...');
  const orgSnap = await db.collection('organizations').get();
  counts.organizations = orgSnap.size;
  for (const doc of orgSnap.docs) {
    const subcollections = await getAllSubcollections(doc.ref);
    for (const subcol of subcollections) {
      const subCount = await countDocumentsRecursive(subcol, `organizations/${doc.id}/${subcol.id}`);
      counts.organizations += subCount;
    }
  }
  console.log(`    Found ${counts.organizations} organization documents (including subcollections)`);

  // Count users
  console.log('  Counting users...');
  const userSnap = await db.collection('users').get();
  counts.users = userSnap.size;
  console.log(`    Found ${counts.users} user documents`);

  // Count org-scoped root collections
  console.log('  Counting org-scoped root collections...');
  for (const collectionName of ORG_SCOPED_ROOT_COLLECTIONS) {
    try {
      const snap = await db.collection(collectionName).limit(10000).get();
      counts.orgScopedRoot += snap.size;
    } catch (e) {
      // Collection may not exist
    }
  }
  console.log(`    Found ${counts.orgScopedRoot} org-scoped root documents`);

  // Count public_orgs
  console.log('  Counting public_orgs...');
  const publicOrgSnap = await db.collection('public_orgs').get();
  counts.publicOrgs = publicOrgSnap.size;
  console.log(`    Found ${counts.publicOrgs} public_orgs documents`);

  // Count provenanceIds
  console.log('  Counting provenanceIds...');
  const provIdSnap = await db.collection('provenanceIds').get();
  counts.provenanceIds = provIdSnap.size;
  console.log(`    Found ${counts.provenanceIds} provenanceId counter documents`);

  // Count preserved collections (informational)
  console.log('  Counting preserved collections...');
  for (const collectionName of GLOBAL_COLLECTIONS) {
    try {
      const snap = await db.collection(collectionName).limit(10000).get();
      counts.preserved += snap.size;
    } catch (e) {
      // Collection may not exist
    }
  }
  console.log(`    Found ${counts.preserved} documents in preserved collections (will NOT be deleted)`);

  // Count auth users if requested
  if (options.deleteAuthUsers) {
    console.log('  Counting Firebase Auth users...');
    let authUserCount = 0;
    let nextPageToken;
    do {
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      authUserCount += listUsersResult.users.length;
      nextPageToken = listUsersResult.pageToken;
    } while (nextPageToken);
    counts.authUsers = authUserCount;
    console.log(`    Found ${counts.authUsers} Firebase Auth users`);
  }

  return counts;
}

async function main() {
  try {
    console.log('╔════════════════════════════════════════════════════════════════╗');
    console.log('║       SeaFoundry Production Data Reset Script                  ║');
    console.log('╚════════════════════════════════════════════════════════════════╝');
    console.log(`\nMode: ${options.dryRun ? '🔍 DRY RUN (preview only)' : '⚡ EXECUTE'}`);
    console.log(`Reset PIDs: ${options.resetPids ? 'Yes' : 'No'}`);
    console.log(`Delete Auth Users: ${options.deleteAuthUsers ? 'Yes' : 'No'}`);
    console.log('');

    // Step 1: Count data
    const counts = await countDataToDelete();

    const totalToDelete =
      counts.organizations +
      counts.users +
      counts.orgScopedRoot +
      counts.publicOrgs +
      counts.provenanceIds;

    if (totalToDelete === 0) {
      console.log('\n✅ No data found to delete - database appears empty');
      process.exit(0);
    }

    // Step 2: Show summary
    console.log('\n╔════════════════════════════════════════════════════════════════╗');
    console.log('║                        DELETION SUMMARY                        ║');
    console.log('╚════════════════════════════════════════════════════════════════╝');
    console.log('\n  WILL BE DELETED:');
    console.log(`    Organizations (+ subcollections): ${counts.organizations}`);
    console.log(`    Users: ${counts.users}`);
    console.log(`    Org-scoped root docs: ${counts.orgScopedRoot}`);
    console.log(`    Public orgs: ${counts.publicOrgs}`);
    console.log(`    PID counters: ${counts.provenanceIds}`);
    if (options.deleteAuthUsers) {
      console.log(`    Firebase Auth users: ${counts.authUsers}`);
    }
    console.log(`    ─────────────────────────────`);
    console.log(`    TOTAL: ${totalToDelete} Firestore documents${options.deleteAuthUsers ? ` + ${counts.authUsers} auth users` : ''}`);

    console.log('\n  WILL BE PRESERVED:');
    console.log(`    CRC/Historical data: ✅`);
    console.log(`    Taxonomy data: ✅`);
    console.log(`    Reference data: ✅`);
    console.log(`    Cloud Storage: ✅`);
    console.log(`    (${counts.preserved} documents in preserved collections)`);

    if (options.resetPids) {
      console.log('\n  PID COUNTER RESET:');
      await calculateNextPidValues();
    }

    // Step 3: Dry run stops here
    if (options.dryRun) {
      console.log('\n💡 This is a DRY RUN. Run with --execute to actually delete the data.');
      console.log('\nExample:');
      console.log('  node scripts/reset-production-data.js --execute --reset-pids');
      process.exit(0);
    }

    // Step 4: Get confirmation
    console.log('\n⚠️  WARNING: This will PERMANENTLY DELETE all organization and user data!');

    const confirmed = await promptConfirmation(
      '\n🚨 Type "yes" to PERMANENTLY DELETE all this data: ',
    );

    if (!confirmed) {
      console.log('\n❌ Deletion cancelled');
      process.exit(0);
    }

    // Extra confirmation for auth users
    if (options.deleteAuthUsers) {
      const authConfirmed = await promptConfirmation(
        '\n⚠️  You also requested to delete Firebase Auth users. Type "yes" again to confirm: ',
      );

      if (!authConfirmed) {
        console.log('\n❌ Auth user deletion cancelled (Firestore deletion will still proceed)');
        options.deleteAuthUsers = false;
      }
    }

    // Step 5: Execute deletions
    console.log('\n🚀 Performing deletion...\n');

    const results = {
      organizations: 0,
      users: 0,
      orgScopedRoot: 0,
      publicOrgs: 0,
      provenanceIds: 0,
      authUsers: 0,
    };

    // Delete org-scoped root collections first
    console.log('\n📦 Phase 1: Deleting org-scoped root collections...');
    results.orgScopedRoot = await deleteOrgScopedRootDocuments();

    // Delete organizations
    console.log('\n📦 Phase 2: Deleting organizations...');
    results.organizations = await deleteAllOrganizations();

    // Delete users
    console.log('\n📦 Phase 3: Deleting users...');
    results.users = await deleteAllUsers();

    // Delete public_orgs
    console.log('\n📦 Phase 4: Deleting public_orgs...');
    results.publicOrgs = await deletePublicOrgs();

    // Delete provenanceIds
    console.log('\n📦 Phase 5: Deleting provenanceIds...');
    results.provenanceIds = await deleteProvenanceIds();

    // Reset PID counters
    if (options.resetPids) {
      console.log('\n📦 Phase 6: Resetting PID counters...');
      const nextValues = await calculateNextPidValues();
      await resetPidCounters(nextValues);
    }

    // Delete auth users
    if (options.deleteAuthUsers) {
      console.log('\n📦 Phase 7: Deleting Firebase Auth users...');
      results.authUsers = await deleteAllAuthUsers();
    }

    // Final summary
    console.log('\n╔════════════════════════════════════════════════════════════════╗');
    console.log('║                      DELETION COMPLETE                         ║');
    console.log('╚════════════════════════════════════════════════════════════════╝');
    console.log(`\n  Organizations: ${results.organizations} documents`);
    console.log(`  Users: ${results.users} documents`);
    console.log(`  Org-scoped root: ${results.orgScopedRoot} documents`);
    console.log(`  Public orgs: ${results.publicOrgs} documents`);
    console.log(`  PID counters: ${results.provenanceIds} documents`);
    if (options.deleteAuthUsers) {
      console.log(`  Auth users: ${results.authUsers} users`);
    }
    if (options.resetPids) {
      console.log(`  PID counters: Reset with CRC data accounting ✅`);
    }

    console.log('\n✅ Production data reset complete!');
    console.log('\n📝 Next steps:');
    console.log('   1. Run demo seeding: node scripts/seed-demo.js --reset --tier=pro --org=ORG_ID --user=USER_EMAIL');
    console.log('   2. Or import fresh data using CSV imports');

  } catch (error) {
    console.error('\n❌ Operation failed:', error.message);
    if (options.verbose) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Run the reset
main();
