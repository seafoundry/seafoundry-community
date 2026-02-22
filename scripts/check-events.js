#!/usr/bin/env node

/**
 * Check events collection for the dev user's organization
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function initializeFirebase() {
  const serviceAccountPath = path.join(process.cwd(), 'firebase-service-account.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id
    });
  }
  return admin.app();
}

async function main() {
  console.log('='.repeat(80));
  console.log('CHECKING EVENTS FOR DEV USER ORGANIZATION');
  console.log('='.repeat(80));

  initializeFirebase();
  const db = admin.firestore();

  const orgId = 'Xx2kzbAiaihc16cz4BXO';
  const email = 'dev@seafoundry.com';

  // Check top-level events collection
  console.log('\n1. TOP-LEVEL /events COLLECTION (filtered by orgId):');
  console.log('-'.repeat(80));
  const eventsSnapshot = await db.collection('events')
    .where('organizationId', '==', orgId)
    .get();
  console.log(`   Total events for org: ${eventsSnapshot.size}`);
  eventsSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`   - ${doc.id}:`);
    console.log(`     type: ${data.eventType || data.type}`);
    console.log(`     recordModelType: ${data.recordModelType}`);
    console.log(`     createdById: ${data.createdById}`);
    console.log(`     organizationId: ${data.organizationId}`);
  });

  // Check org-nested events
  console.log('\n2. ORG-NESTED /organizations/{orgId}/events COLLECTION:');
  console.log('-'.repeat(80));
  const nestedEventsSnapshot = await db.collection('organizations').doc(orgId).collection('events').get();
  console.log(`   Total nested events: ${nestedEventsSnapshot.size}`);
  nestedEventsSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`   - ${doc.id}:`);
    console.log(`     type: ${data.eventType || data.type}`);
    console.log(`     recordModelType: ${data.recordModelType}`);
  });

  // Check what collection the app uses for events
  console.log('\n3. CHECKING WHERE EVENTS ARE WRITTEN:');
  console.log('-'.repeat(80));

  // Check if there are any events at all in top-level that match our format
  const allEventsSnapshot = await db.collection('events').limit(10).get();
  console.log(`   Sample of all events in top-level collection:`);
  allEventsSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`   - ${doc.id}: recordModelType=${data.recordModelType}, orgId=${data.organizationId}`);
  });

  console.log('\n' + '='.repeat(80));
  console.log('ANALYSIS');
  console.log('='.repeat(80));

  console.log('\nKey points:');
  console.log('1. Check if events are being written to top-level or nested collection');
  console.log('2. Check if the app RecordRepository uses the correct collection');
  console.log('3. The security rules for /events require incomingBelongsToUserOrg()');

  process.exit(0);
}

main().catch(error => {
  console.error('FATAL:', error);
  process.exit(1);
});
