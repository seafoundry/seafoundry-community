#!/usr/bin/env node

/**
 * Reset Dev Organization and User
 * 
 * Deletes:
 * - User document for dev@seafoundry.com
 * - Organization "seafoundry" and all its data
 * - All nested collections under organizations/{orgId}/
 * - All related records (sites, groups, organisms, events) for this organization
 * 
 * Usage:
 *   node scripts/reset-dev-org.js [--confirm]
 */

require('dotenv').config();
const { admin, db } = require('./config-json');
const readline = require('readline');

const args = process.argv.slice(2);
const needsConfirmation = !args.includes('--confirm');

const USER_EMAIL = 'dev@seafoundry.com';
const ORG_IDENTIFIER = 'seafoundry'; // Can be domain, slug, or urlPath

/**
 * Find organization by domain, slug, or urlPath
 */
async function findOrganization(identifier) {
  console.log(`\n🔍 Looking for organization: ${identifier}`);
  
  // Try by domain
  let snapshot = await db.collection('organizations')
    .where('domain', '==', identifier.toLowerCase())
    .limit(1)
    .get();
  
  if (!snapshot.empty) {
    const org = snapshot.docs[0];
    console.log(`  ✅ Found by domain: ${org.id}`);
    return { id: org.id, doc: org };
  }
  
  // Try by slug
  snapshot = await db.collection('organizations')
    .where('slug', '==', identifier.toLowerCase())
    .limit(1)
    .get();
  
  if (!snapshot.empty) {
    const org = snapshot.docs[0];
    console.log(`  ✅ Found by slug: ${org.id}`);
    return { id: org.id, doc: org };
  }
  
  // Try by urlPath
  snapshot = await db.collection('organizations')
    .where('urlPath', '==', identifier)
    .limit(1)
    .get();
  
  if (!snapshot.empty) {
    const org = snapshot.docs[0];
    console.log(`  ✅ Found by urlPath: ${org.id}`);
    return { id: org.id, doc: org };
  }
  
  // Try by ID directly
  const orgDoc = await db.collection('organizations').doc(identifier).get();
  if (orgDoc.exists) {
    console.log(`  ✅ Found by ID: ${identifier}`);
    return { id: identifier, doc: orgDoc };
  }
  
  console.log(`  ❌ Organization not found`);
  return null;
}

/**
 * Find user by email
 */
async function findUser(email) {
  console.log(`\n🔍 Looking for user: ${email}`);
  
  const snapshot = await db.collection('users')
    .where('email', '==', email)
    .limit(1)
    .get();
  
  if (snapshot.empty) {
    console.log(`  ❌ User not found`);
    return null;
  }
  
  const user = snapshot.docs[0];
  console.log(`  ✅ Found user: ${user.id}`);
  return { id: user.id, doc: user };
}

/**
 * Delete all documents in a collection
 */
async function deleteCollection(collectionPath, batchSize = 500) {
  const collectionRef = db.collection(collectionPath);
  let deletedCount = 0;
  let hasMore = true;

  while (hasMore) {
    const snapshot = await collectionRef.limit(batchSize).get();
    
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

  return deletedCount;
}

/**
 * Delete all subcollections of a document
 */
async function deleteSubcollections(docRef) {
  const subcollections = await docRef.listCollections();
  let totalDeleted = 0;
  
  for (const subcollection of subcollections) {
    console.log(`    Deleting subcollection: ${subcollection.path}`);
    const deleted = await deleteCollection(subcollection.path);
    totalDeleted += deleted;
    if (deleted > 0) {
      console.log(`      ✅ Deleted ${deleted} documents`);
    }
  }
  
  return totalDeleted;
}

/**
 * Delete all records with matching organizationId
 */
async function deleteRecordsByOrgId(collectionName, organizationId) {
  console.log(`\n  📂 Deleting ${collectionName} records for org ${organizationId}...`);
  
  let deletedCount = 0;
  let hasMore = true;
  const batchSize = 500;

  while (hasMore) {
    const snapshot = await db.collection(collectionName)
      .where('organizationId', '==', organizationId)
      .limit(batchSize)
      .get();
    
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
    console.log(`    ✅ Deleted ${deletedCount} ${collectionName} records`);
  }
  
  return deletedCount;
}

/**
 * Main reset function
 */
async function resetDevOrg() {
  console.log('\n🗑️  Starting reset for dev organization and user...\n');
  
  // Step 1: Find organization
  const org = await findOrganization(ORG_IDENTIFIER);
  if (!org) {
    console.log('\n❌ Organization not found. Nothing to delete.');
    return;
  }
  
  const orgId = org.id;
  console.log(`\n📋 Organization ID: ${orgId}`);
  
  // Step 2: Find user
  const user = await findUser(USER_EMAIL);
  
  // Step 3: Delete nested organization collections
  console.log(`\n🗑️  Deleting nested organization collections...`);
  const orgDocRef = db.collection('organizations').doc(orgId);
  const nestedDeleted = await deleteSubcollections(orgDocRef);
  if (nestedDeleted > 0) {
    console.log(`  ✅ Deleted ${nestedDeleted} documents from nested collections`);
  }
  
  // Step 4: Delete organization-scoped records
  console.log(`\n🗑️  Deleting organization-scoped records...`);
  const nestedCollections = [
    'groups',
    'genets',
    'organismRecords',
  ];
  
  let totalRecordsDeleted = 0;
  for (const collectionName of nestedCollections) {
    const collectionPath = `organizations/${orgId}/${collectionName}`;
    const deleted = await deleteCollection(collectionPath);
    totalRecordsDeleted += deleted;
  }
  
  if (totalRecordsDeleted > 0) {
    console.log(`  ✅ Deleted ${totalRecordsDeleted} records from nested collections`);
  }
  
  // Step 5: Delete root-level records with organizationId
  console.log(`\n🗑️  Deleting root-level records for organization...`);
  const rootCollections = [
    'sites',
    'events',
  ];
  
  let totalRootDeleted = 0;
  for (const collectionName of rootCollections) {
    const deleted = await deleteRecordsByOrgId(collectionName, orgId);
    totalRootDeleted += deleted;
  }
  
  if (totalRootDeleted > 0) {
    console.log(`  ✅ Deleted ${totalRootDeleted} root-level records`);
  }
  
  // Step 6: Delete organization document
  console.log(`\n🗑️  Deleting organization document...`);
  await orgDocRef.delete();
  console.log(`  ✅ Deleted organization: ${orgId}`);
  
  // Step 7: Delete user document
  if (user) {
    console.log(`\n🗑️  Deleting user document...`);
    await db.collection('users').doc(user.id).delete();
    console.log(`  ✅ Deleted user: ${user.id} (${USER_EMAIL})`);
  } else {
    console.log(`\n⚠️  User not found, skipping user deletion`);
  }
  
  console.log(`\n✅ Reset complete!`);
  console.log(`\n📊 Summary:`);
  console.log(`  - Organization deleted: ${orgId}`);
  if (user) {
    console.log(`  - User deleted: ${user.id}`);
  }
  console.log(`  - Nested collections deleted: ${nestedDeleted} documents`);
  console.log(`  - Organization records deleted: ${totalRecordsDeleted} documents`);
  console.log(`  - Root records deleted: ${totalRootDeleted} documents`);
}

/**
 * Prompt for confirmation
 */
async function promptConfirmation() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const answer = await new Promise(resolve => {
    rl.question(`\n⚠️  Are you sure you want to DELETE the organization "${ORG_IDENTIFIER}" and user "${USER_EMAIL}"? (type "yes" to confirm): `, resolve);
  });

  rl.close();
  return answer.toLowerCase() === 'yes';
}

/**
 * Main execution
 */
async function main() {
  try {
    if (needsConfirmation) {
      const confirmed = await promptConfirmation();
      if (!confirmed) {
        console.log('\n❌ Reset cancelled.');
        process.exit(0);
      }
    }
    
    await resetDevOrg();
    
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
  process.exit(0);
}).catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});

