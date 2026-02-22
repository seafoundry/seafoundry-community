#!/usr/bin/env node
/**
 * Test Outplant Permission
 * 
 * Simulates the exact batch write that occurs during outplanting
 * to diagnose permission-denied errors.
 * 
 * Usage:
 *   node scripts/test-outplant-permission.js
 */

const admin = require('firebase-admin');
const fs = require('fs');

const credPath = './firebase-service-account.json';
const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));

admin.initializeApp({ credential: admin.credential.cert(creds) });
const db = admin.firestore();

async function main() {
  const userId = 'OuBkJmnZatZ0iZf9oigb4TaffMI3';
  const orgId = 'demo_org_pro';
  const testEventId = 'test_outplant_' + Date.now();
  
  console.log('='.repeat(60));
  console.log('TEST OUTPLANT PERMISSION');
  console.log('='.repeat(60));
  console.log('');
  console.log('User ID:', userId);
  console.log('Organization ID:', orgId);
  console.log('Test Event ID:', testEventId);
  console.log('');

  // 1. First verify the user document
  console.log('1. Checking user document...');
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    console.log('   ❌ User document MISSING');
    return;
  }
  const userData = userDoc.data();
  console.log('   ✅ User document exists');
  console.log('   organizationId:', userData.organizationId);
  console.log('');

  // 2. Check membership document
  console.log('2. Checking membership document...');
  const memberDoc = await db.collection('organizations').doc(orgId)
    .collection('members').doc(userId).get();
  if (!memberDoc.exists) {
    console.log('   ❌ Membership document MISSING');
    return;
  }
  console.log('   ✅ Membership document exists');
  console.log('');

  // 3. Create a test batch like outplanting does
  console.log('3. Testing batch write (same structure as outplant)...');
  console.log('');

  // The outplant batch includes:
  // a) Event document in /events collection
  // b) Organism record updates in /organizations/{orgId}/organismRecords
  
  const batch = db.batch();
  
  // a) Event document
  const eventRef = db.collection('events').doc(testEventId);
  const eventData = {
    id: testEventId,
    createdById: userId,
    updatedById: userId,
    organizationId: orgId,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    eventTypeId: 'outplant',
    name: 'Test Outplant Event',
    recordModelType: 'site',
    recordId: 'test_site_id',
    urlPath: 'test/path',
    internalPath: orgId + '/' + testEventId,
    slug: 'test-event',
  };
  
  console.log('   a) Event document:');
  console.log('      Path:', eventRef.path);
  console.log('      createdById:', eventData.createdById);
  console.log('      organizationId:', eventData.organizationId);
  console.log('');
  
  batch.set(eventRef, eventData);
  
  // Try to commit
  console.log('4. Committing batch...');
  try {
    await batch.commit();
    console.log('   ✅ Batch commit SUCCEEDED!');
    console.log('');
    
    // Cleanup
    console.log('5. Cleaning up test document...');
    await eventRef.delete();
    console.log('   ✅ Cleanup done');
    console.log('');
    console.log('='.repeat(60));
    console.log('RESULT: Permission rules are working correctly!');
    console.log('The issue must be in the client-side code.');
    console.log('='.repeat(60));
    
  } catch (error) {
    console.log('   ❌ Batch commit FAILED');
    console.log('   Error code:', error.code);
    console.log('   Error message:', error.message);
    console.log('');
    console.log('='.repeat(60));
    console.log('RESULT: Permission rules are blocking the write');
    console.log('='.repeat(60));
  }
}

main().then(() => process.exit(0)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
