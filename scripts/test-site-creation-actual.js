#!/usr/bin/env node

/**
 * Actually test site creation against production Firestore
 *
 * This tests the actual write operation to see if it succeeds or fails.
 * Uses Admin SDK which bypasses security rules - so this is really
 * just to verify the data is correctly formed.
 *
 * For actual security rule testing, we'd need to use the emulator.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const EMAIL = 'dev@seafoundry.com';

function initializeFirebase() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  const serviceAccountPath = path.join(process.cwd(), 'firebase-service-account.json');
  if (fs.existsSync(serviceAccountPath)) {
    console.log('[INIT] Loading Firebase credentials...');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'seafoundryapp'
    });
  } else {
    console.error('ERROR: firebase-service-account.json not found');
    process.exit(1);
  }

  return admin.app();
}

async function testSiteCreation() {
  console.log('='.repeat(80));
  console.log('TESTING ACTUAL SITE CREATION (ADMIN SDK)');
  console.log('='.repeat(80));

  initializeFirebase();
  const db = admin.firestore();
  const auth = admin.auth();

  // Get user data
  const authUser = await auth.getUserByEmail(EMAIL);
  const userDoc = await db.collection('users').doc(authUser.uid).get();
  if (!userDoc.exists) {
    console.log('User not found!');
    return;
  }
  const userData = userDoc.data();
  console.log('\nUser data:');
  console.log(`  id: ${userData.id}`);
  console.log(`  email: ${userData.email}`);
  console.log(`  organizationId: ${userData.organizationId}`);

  // Get organization data
  const orgDoc = await db.collection('organizations').doc(userData.organizationId).get();
  if (!orgDoc.exists) {
    console.log('Organization not found!');
    return;
  }
  const orgData = orgDoc.data();
  console.log('\nOrganization data:');
  console.log(`  id: ${orgData.id}`);
  console.log(`  name: ${orgData.name}`);
  console.log(`  domain: ${orgData.domain}`);

  // Generate IDs for test
  const siteId = db.collection('sites').doc().id;
  const eventId = db.collection('events').doc().id;
  const now = new Date().toISOString();

  // Create site data exactly as the app would
  const siteData = {
    id: siteId,
    name: 'Test Site from Script',
    organizationId: userData.organizationId,
    createdById: userData.id, // Should be UID
    createdAt: now,
    updatedAt: now,
    updatedById: userData.id,
    siteTypeId: 'nursery_ex_situ',
    groupIdHierarchy: ['group_type_tank'],
    slug: `site-test-${Date.now()}`,
    urlPath: `${orgData.domain}/site-test-${Date.now()}`,
    internalPath: `${userData.organizationId}/${siteId}`,
  };

  // Create event data
  const eventData = {
    id: eventId,
    eventType: 'create',
    recordId: siteId,
    recordModelType: 'site',
    organizationId: userData.organizationId,
    createdById: userData.id,
    createdAt: now,
    updatedAt: now,
    updatedById: userData.id,
    slug: `event-${Date.now()}`,
    urlPath: `${orgData.domain}/site-test-${Date.now()}/event-${Date.now()}`,
    internalPath: `${userData.organizationId}/${eventId}`,
    snapshot: siteData,
  };

  console.log('\n' + '='.repeat(80));
  console.log('SITE DATA TO WRITE:');
  console.log('='.repeat(80));
  console.log(JSON.stringify(siteData, null, 2));

  console.log('\n' + '='.repeat(80));
  console.log('EVENT DATA TO WRITE:');
  console.log('='.repeat(80));
  console.log(JSON.stringify(eventData, null, 2));

  // Try to write using batch
  console.log('\n' + '='.repeat(80));
  console.log('ATTEMPTING BATCH WRITE (Admin SDK - bypasses security rules)');
  console.log('='.repeat(80));

  try {
    const batch = db.batch();
    batch.set(db.collection('sites').doc(siteId), siteData);
    batch.set(db.collection('events').doc(eventId), eventData);
    await batch.commit();
    console.log('\n[SUCCESS] Batch write succeeded!');
    console.log(`  Site ID: ${siteId}`);
    console.log(`  Event ID: ${eventId}`);

    // Clean up test data
    console.log('\nCleaning up test data...');
    await db.collection('sites').doc(siteId).delete();
    await db.collection('events').doc(eventId).delete();
    console.log('Test data cleaned up.');
  } catch (error) {
    console.log(`\n[FAILURE] Batch write failed: ${error.message}`);
    console.log(error);
  }

  console.log('\n' + '='.repeat(80));
  console.log('NOTE: Admin SDK bypasses security rules.');
  console.log('To test actual security rules, use Firebase emulator.');
  console.log('='.repeat(80));

  process.exit(0);
}

testSiteCreation().catch(error => {
  console.error('FATAL:', error);
  process.exit(1);
});
