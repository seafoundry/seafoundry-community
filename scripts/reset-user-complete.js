#!/usr/bin/env node

/**
 * Complete User Reset Script
 *
 * Comprehensive reset for a user account that handles ALL edge cases:
 * - Deletes user document (UID-based, with legacy email-ID fallback)
 * - Finds and deletes ALL organizations created by or owned by this user
 * - Deletes all org-scoped data (nested collections)
 * - Deletes all root-level records referencing those organizations
 * - Cleans up orphaned data where createdById matches the user
 *
 * This script is designed for onboarding re-testing scenarios where
 * a user needs to go through the complete onboarding flow again.
 *
 * Usage:
 *   node scripts/reset-user-complete.js [--confirm] [--email=user@example.com]
 *
 * Environment variables:
 *   RESET_USER_EMAIL - Override the target user email (default: dev@seafoundry.com)
 *   GOOGLE_APPLICATION_CREDENTIALS - Path to Firebase service account JSON
 */

require('dotenv').config();
const readline = require('readline');

// Parse command line arguments
const args = process.argv.slice(2);
const needsConfirmation = !args.includes('--confirm');
const emailArg = args.find(a => a.startsWith('--email='));
const USER_EMAIL = emailArg
  ? emailArg.split('=')[1]
  : (process.env.RESET_USER_EMAIL || 'dev@seafoundry.com');
const LEGACY_EMAIL_DOC_ID = USER_EMAIL.toLowerCase();

// Initialize Firebase Admin using shared config
require('dotenv').config();
const { admin, db } = require('./config-json');
const { getAuth } = require('firebase-admin/auth');

// All collections that may contain organization-scoped data
const ORG_SCOPED_ROOT_COLLECTIONS = [
  'sites',
  'events',
  'holdings',
  'transfers',
  'snapshot_records',
  'inventory_snapshots',
  'snapshots',
  'config',
  'media_assets',
  'permits',
  'deliverables',
  'brand_profiles',
  'invitations',
];

// Collections nested under organizations/{orgId}/
const ORG_NESTED_COLLECTIONS = [
  'groups',
  'genets',
  'organismRecords',
  'organism_records',
  'cohorts',
  'members',
  'notifications',
  'slugCounts',
  'events',
];

// Collections that might have createdById referencing this user
const CREATED_BY_COLLECTIONS = [
  'events',
  'organizations',
];

/**
 * Delete all documents in a collection matching a query
 */
async function deleteByQuery(query, label) {
  let deletedCount = 0;
  let hasMore = true;
  const batchSize = 500;

  while (hasMore) {
    const snapshot = await query.limit(batchSize).get();

    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    deletedCount += snapshot.docs.length;

    if (snapshot.docs.length < batchSize) {
      hasMore = false;
    }
  }

  if (deletedCount > 0) {
    console.log(`    ✅ Deleted ${deletedCount} ${label}`);
  }

  return deletedCount;
}

/**
 * Delete all subcollections of a document
 */
async function deleteSubcollections(docRef) {
  const subcollections = await docRef.listCollections();
  let totalDeleted = 0;

  for (const subcollection of subcollections) {
    const deleted = await deleteByQuery(
      subcollection,
      `documents from ${subcollection.id}`
    );
    totalDeleted += deleted;
  }

  return totalDeleted;
}

/**
 * Resolve Firebase Auth UID from email when available.
 */
async function resolveAuthUid(email) {
  try {
    const auth = getAuth();
    const user = await auth.getUserByEmail(email);
    return user.uid;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      console.log(`  ⚠️  Could not resolve auth UID: ${error.message}`);
    }
    return null;
  }
}

/**
 * Find user document by preferred ID and/or email fields.
 */
async function findUser(preferredUserId) {
  console.log(`\n🔍 Looking for user: ${USER_EMAIL}`);

  if (preferredUserId) {
    const preferredDoc = await db.collection('users').doc(preferredUserId).get();
    if (preferredDoc.exists) {
      console.log(`  ✅ Found user by preferred doc ID: ${preferredUserId}`);
      return { id: preferredUserId, data: preferredDoc.data(), ref: preferredDoc.ref };
    }
  }

  // Legacy fallback: user docs keyed by lowercase email.
  if (!preferredUserId || preferredUserId !== LEGACY_EMAIL_DOC_ID) {
    const userDocByLegacyId = await db.collection('users').doc(LEGACY_EMAIL_DOC_ID).get();
    if (userDocByLegacyId.exists) {
      console.log(`  ✅ Found user by legacy email doc ID: ${LEGACY_EMAIL_DOC_ID}`);
      return {
        id: LEGACY_EMAIL_DOC_ID,
        data: userDocByLegacyId.data(),
        ref: userDocByLegacyId.ref,
      };
    }
  }

  // Try by email field (case-insensitive search)
  const snapshot = await db.collection('users')
    .where('email', '==', USER_EMAIL)
    .limit(1)
    .get();

  if (!snapshot.empty) {
    const user = snapshot.docs[0];
    console.log(`  ✅ Found user by email field: ${user.id}`);
    return { id: user.id, data: user.data(), ref: user.ref };
  }

  // Try lowercase email field
  const snapshotLower = await db.collection('users')
    .where('email', '==', USER_EMAIL.toLowerCase())
    .limit(1)
    .get();

  if (!snapshotLower.empty) {
    const user = snapshotLower.docs[0];
    console.log(`  ✅ Found user by lowercase email: ${user.id}`);
    return { id: user.id, data: user.data(), ref: user.ref };
  }

  console.log(`  ⚠️  User document not found`);
  return null;
}

/**
 * Find all organizations created by or associated with this user
 */
async function findUserOrganizations(userId, user) {
  console.log(`\n🔍 Looking for organizations associated with: ${userId}`);
  const organizations = [];

  // Find by createdById
  const createdBySnapshot = await db.collection('organizations')
    .where('createdById', '==', userId)
    .get();

  for (const doc of createdBySnapshot.docs) {
    console.log(`  ✅ Found org created by user: ${doc.id} (${doc.data().name || 'unnamed'})`);
    organizations.push({ id: doc.id, data: doc.data() });
  }

  // Find by createdById with lowercase
  const createdByLowerSnapshot = await db.collection('organizations')
    .where('createdById', '==', userId.toLowerCase())
    .get();

  for (const doc of createdByLowerSnapshot.docs) {
    if (!organizations.find(o => o.id === doc.id)) {
      console.log(`  ✅ Found org created by user (lowercase): ${doc.id} (${doc.data().name || 'unnamed'})`);
      organizations.push({ id: doc.id, data: doc.data() });
    }
  }

  // If user has organizationId set, include that org too.
  if (user && user.data && user.data.organizationId) {
    const userOrgId = user.data.organizationId;
    if (!organizations.find(o => o.id === userOrgId) && userOrgId !== userId && userOrgId !== userId.toLowerCase()) {
      const orgDoc = await db.collection('organizations').doc(userOrgId).get();
      if (orgDoc.exists) {
        console.log(`  ✅ Found user's current org: ${userOrgId} (${orgDoc.data().name || 'unnamed'})`);
        organizations.push({ id: userOrgId, data: orgDoc.data() });
      }
    }
  }

  if (organizations.length === 0) {
    console.log(`  ⚠️  No organizations found for this user`);
  }

  return organizations;
}

/**
 * Delete an organization and all its data
 */
async function deleteOrganization(orgId) {
  console.log(`\n🗑️  Deleting organization: ${orgId}`);
  let totalDeleted = 0;

  const orgDocRef = db.collection('organizations').doc(orgId);

  // Delete nested collections
  console.log(`  📂 Deleting nested collections...`);
  for (const collectionName of ORG_NESTED_COLLECTIONS) {
    const collectionRef = orgDocRef.collection(collectionName);
    const deleted = await deleteByQuery(collectionRef, `${collectionName} documents`);
    totalDeleted += deleted;
  }

  // Delete any other subcollections
  const subDeleted = await deleteSubcollections(orgDocRef);
  totalDeleted += subDeleted;

  // Delete root-level records with this organizationId
  console.log(`  📂 Deleting root-level records...`);
  for (const collectionName of ORG_SCOPED_ROOT_COLLECTIONS) {
    const query = db.collection(collectionName).where('organizationId', '==', orgId);
    const deleted = await deleteByQuery(query, `${collectionName} records`);
    totalDeleted += deleted;
  }

  // Delete the organization document itself
  await orgDocRef.delete();
  console.log(`  ✅ Deleted organization document: ${orgId}`);

  return totalDeleted + 1;
}

/**
 * Clean up orphaned records created by this user
 */
async function cleanupOrphanedRecords(userId) {
  console.log(`\n🧹 Cleaning up orphaned records created by: ${userId}`);
  let totalDeleted = 0;

  for (const collectionName of CREATED_BY_COLLECTIONS) {
    // Check both original case and lowercase
    for (const createdById of [userId, userId.toLowerCase()]) {
      const query = db.collection(collectionName).where('createdById', '==', createdById);
      const deleted = await deleteByQuery(query, `orphaned ${collectionName} (createdById: ${createdById})`);
      totalDeleted += deleted;
    }
  }

  return totalDeleted;
}

/**
 * Delete user's intro/profile subcollections
 */
async function deleteUserSubcollections(userId) {
  console.log(`\n🗑️  Deleting user subcollections...`);
  const userDocRef = db.collection('users').doc(userId);
  return await deleteSubcollections(userDocRef);
}

/**
 * Delete Firebase Auth user by email
 */
async function deleteAuthUser(email) {
  console.log(`\n🔐 Deleting Firebase Auth user: ${email}`);
  try {
    const auth = getAuth();
    const user = await auth.getUserByEmail(email);
    await auth.deleteUser(user.uid);
    console.log(`  ✅ Firebase Auth user deleted (UID: ${user.uid})`);
    return true;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log(`  ⚠️  Firebase Auth user not found`);
    } else {
      console.log(`  ⚠️  Could not delete Auth user: ${error.message}`);
    }
    return false;
  }
}

/**
 * Main reset function
 */
async function resetUser() {
  console.log('\n' + '='.repeat(60));
  console.log(`🔄 COMPLETE USER RESET: ${USER_EMAIL}`);
  console.log('='.repeat(60));

  const stats = {
    userDeleted: false,
    authUserDeleted: false,
    organizationsDeleted: 0,
    totalRecordsDeleted: 0,
  };

  const resolvedUid = await resolveAuthUid(USER_EMAIL);
  const lookupUserId = resolvedUid || LEGACY_EMAIL_DOC_ID;
  if (resolvedUid) {
    console.log(`  ✅ Resolved auth UID: ${resolvedUid}`);
  } else {
    console.log('  ⚠️  No auth UID found, falling back to legacy email doc lookup');
  }

  // Step 1: Find user
  const user = await findUser(lookupUserId);
  const finalUserId = user?.id || lookupUserId;

  // Step 2: Find all organizations
  const organizations = await findUserOrganizations(finalUserId, user);

  // Step 3: Delete each organization and its data
  for (const org of organizations) {
    const deleted = await deleteOrganization(org.id);
    stats.organizationsDeleted++;
    stats.totalRecordsDeleted += deleted;
  }

  // Step 4: Clean up orphaned records
  const orphanedDeleted = await cleanupOrphanedRecords(finalUserId);
  stats.totalRecordsDeleted += orphanedDeleted;

  // Step 5: Delete user subcollections
  if (user) {
    const subDeleted = await deleteUserSubcollections(user.id);
    stats.totalRecordsDeleted += subDeleted;
  }

  // Step 6: Delete user document
  if (user) {
    console.log(`\n🗑️  Deleting user document: ${user.id}`);
    await user.ref.delete();
    stats.userDeleted = true;
    console.log(`  ✅ User document deleted`);
  }

  // Also delete any fallback IDs if they still exist.
  const fallbackIds = new Set([lookupUserId, LEGACY_EMAIL_DOC_ID, USER_EMAIL]);
  if (user != null) {
    fallbackIds.remove(user.id);
  }
  for (const fallbackId of fallbackIds) {
    if (!fallbackId || fallbackId.trim() === '') continue;
    const userDocRef = db.collection('users').doc(fallbackId);
    const userDoc = await userDocRef.get();
    if (userDoc.exists) {
      console.log(`\n🗑️  Deleting fallback user document ID: ${fallbackId}`);
      await userDocRef.delete();
      stats.userDeleted = true;
      console.log('  ✅ Fallback user document deleted');
    }
  }

  // Step 7: Delete Firebase Auth user
  stats.authUserDeleted = await deleteAuthUser(USER_EMAIL);

  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 RESET SUMMARY');
  console.log('='.repeat(60));
  console.log(`  User: ${USER_EMAIL}`);
  console.log(`  User document deleted: ${stats.userDeleted ? '✅ Yes' : '⚠️  Not found'}`);
  console.log(`  Auth user deleted: ${stats.authUserDeleted ? '✅ Yes' : '⚠️  Not found/failed'}`);
  console.log(`  Organizations deleted: ${stats.organizationsDeleted}`);
  console.log(`  Total records deleted: ${stats.totalRecordsDeleted}`);
  console.log('='.repeat(60));

  console.log('\n📝 Next steps:');
  console.log(`  1. Login at provenance.seafoundry.com with ${USER_EMAIL}`);
  console.log('  2. You should be redirected to the onboarding flow');
  console.log('  3. Complete organization setup to verify it works');

  return stats;
}

/**
 * Prompt for confirmation
 */
async function promptConfirmation() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  console.log('\n⚠️  WARNING: This will permanently delete:');
  console.log(`  - Firebase Auth account for ${USER_EMAIL}`);
  console.log(`  - User document for ${USER_EMAIL}`);
  console.log('  - ALL organizations created by this user');
  console.log('  - ALL data associated with those organizations');
  console.log('  - ALL orphaned records created by this user');

  const answer = await new Promise(resolve => {
    rl.question('\nType "yes" to confirm: ', resolve);
  });

  rl.close();
  return answer.toLowerCase() === 'yes';
}

/**
 * Main execution
 */
async function main() {
  try {
    console.log(`\n🎯 Target user: ${USER_EMAIL}`);
    console.log(`   Legacy email doc ID: ${LEGACY_EMAIL_DOC_ID}`);

    if (needsConfirmation) {
      const confirmed = await promptConfirmation();
      if (!confirmed) {
        console.log('\n❌ Reset cancelled.');
        process.exit(0);
      }
    }

    await resetUser();

  } catch (error) {
    console.error('\n❌ Error during reset:', error.message);
    if (error.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// Run the script
main().then(() => {
  console.log('\n✅ Script completed successfully');
  process.exit(0);
}).catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
