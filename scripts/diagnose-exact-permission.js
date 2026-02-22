const admin = require('firebase-admin');
const fs = require('fs');

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(creds),
});

const db = admin.firestore();

async function diagnosePermissions() {
  const orgId = '3c3WxBnZX4aTSObOjqJX';
  const email = 'dev@seafoundry.com';
  const uid = 'hnDmMPLLfIPfaG8zsosQo7xCE5R2';

  console.log('=== Diagnosing Exact Permissions ===\n');
  console.log('Testing with:');
  console.log('  orgId:', orgId);
  console.log('  email:', email);
  console.log('  uid:', uid);
  console.log('');

  // Test 1: Read user doc
  console.log('1. Reading user doc...');
  try {
    const userDoc = await db.collection('users').doc(uid).get();
    console.log('   ✅ User doc read success');
    console.log('   - exists:', userDoc.exists);
    if (userDoc.exists) {
      console.log('   - organizationId:', userDoc.data().organizationId);
      console.log('   - email:', userDoc.data().email);
    }
  } catch (e) {
    console.log('   ❌ User doc read FAILED:', e.message);
  }

  // Test 2: Read organization
  console.log('\n2. Reading organization doc...');
  try {
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    console.log('   ✅ Org doc read success');
    console.log('   - exists:', orgDoc.exists);
    if (orgDoc.exists) {
      console.log('   - createdById:', orgDoc.data().createdById);
      console.log('   - name:', orgDoc.data().name);
    }
  } catch (e) {
    console.log('   ❌ Org doc read FAILED:', e.message);
  }

  // Test 3: Read membership
  console.log('\n3. Reading membership doc...');
  try {
    const memberDoc = await db.collection('organizations').doc(orgId).collection('members').doc(uid).get();
    console.log('   ✅ Membership doc read success');
    console.log('   - exists:', memberDoc.exists);
    if (memberDoc.exists) {
      console.log('   - data:', JSON.stringify(memberDoc.data()));
    }
  } catch (e) {
    console.log('   ❌ Membership doc read FAILED:', e.message);
  }

  // Test 4: Write to slugCounts (transaction)
  console.log('\n4. Testing slugCounts write (transaction)...');
  const testSlugRef = db.collection('organizations').doc(orgId).collection('slugCounts').doc('test_diag');
  try {
    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(testSlugRef);
      const newCount = doc.exists ? doc.data().count + 1 : 1;
      transaction.set(testSlugRef, { count: newCount });
    });
    console.log('   ✅ slugCounts transaction success');
    // Clean up
    await testSlugRef.delete();
    console.log('   ✅ slugCounts cleanup success');
  } catch (e) {
    console.log('   ❌ slugCounts transaction FAILED:', e.message);
  }

  // Test 5: Write site (simulating what the app does)
  console.log('\n5. Testing site creation...');
  const testSiteId = 'test_site_' + Date.now();
  const siteRef = db.collection('sites').doc(testSiteId);
  const siteData = {
    id: testSiteId,
    name: 'Test Diagnostic Site',
    organizationId: orgId,
    createdById: uid,
    updatedById: uid,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    siteTypeId: 'nursery',
    slug: 'testsite1',
    urlPath: 'test/testsite1',
    internalPath: 'test/' + testSiteId,
    supportedOrganismKinds: ['coral'],
    groupIdHierarchy: [],
  };
  try {
    await siteRef.set(siteData);
    console.log('   ✅ Site creation success');
    // Clean up
    await siteRef.delete();
    console.log('   ✅ Site cleanup success');
  } catch (e) {
    console.log('   ❌ Site creation FAILED:', e.message);
    console.log('   Site data:', JSON.stringify(siteData, null, 2));
  }

  // Test 6: Write event
  console.log('\n6. Testing event creation...');
  const testEventId = 'test_event_' + Date.now();
  const eventRef = db.collection('events').doc(testEventId);
  const eventData = {
    id: testEventId,
    organizationId: orgId,
    createdById: uid,
    updatedById: uid,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    eventType: 'siteCreate',
    urlPath: 'test/testsite1',
    internalPath: 'test/' + testSiteId,
    notes: 'Test event',
  };
  try {
    await eventRef.set(eventData);
    console.log('   ✅ Event creation success');
    // Clean up
    await eventRef.delete();
    console.log('   ✅ Event cleanup success');
  } catch (e) {
    console.log('   ❌ Event creation FAILED:', e.message);
    console.log('   Event data:', JSON.stringify(eventData, null, 2));
  }

  // Test 7: Batch write (site + event together)
  console.log('\n7. Testing batch write (site + event)...');
  const batch = db.batch();
  const batchSiteId = 'batch_site_' + Date.now();
  const batchEventId = 'batch_event_' + Date.now();
  const batchSiteRef = db.collection('sites').doc(batchSiteId);
  const batchEventRef = db.collection('events').doc(batchEventId);

  batch.set(batchSiteRef, {
    ...siteData,
    id: batchSiteId,
    internalPath: 'test/' + batchSiteId,
  });
  batch.set(batchEventRef, {
    ...eventData,
    id: batchEventId,
  });

  try {
    await batch.commit();
    console.log('   ✅ Batch commit success');
    // Clean up
    await batchSiteRef.delete();
    await batchEventRef.delete();
    console.log('   ✅ Batch cleanup success');
  } catch (e) {
    console.log('   ❌ Batch commit FAILED:', e.message);
  }

  console.log('\n=== Diagnosis Complete ===');
}

diagnosePermissions().then(() => process.exit(0)).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
