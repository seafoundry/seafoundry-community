/**
 * Test script to verify site creation permissions
 * Uses Firebase Admin SDK to simulate what the security rules would evaluate
 */
const admin = require('firebase-admin');
const fs = require('fs');

// Load credentials
const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(creds),
});

const db = admin.firestore();

async function testSiteCreation() {
  const email = 'dev@seafoundry.com';
  const orgId = 'x8JmIhM0KWDheozBmdGG';
  const uid = 'mrdeny98S1TuSmjHJmpFHn7vPiN2';
  
  console.log('=== Testing Site Creation Permissions ===\n');
  
  // First, verify all the preconditions
  console.log('1. Checking preconditions...\n');
  
  // User doc
  const userDoc = await db.collection('users').doc(uid).get();
  console.log('   User doc exists:', userDoc.exists);
  if (userDoc.exists) {
    console.log('   User organizationId:', userDoc.data().organizationId);
  }
  
  // Org doc
  const orgDoc = await db.collection('organizations').doc(orgId).get();
  console.log('   Org doc exists:', orgDoc.exists);
  if (orgDoc.exists) {
    console.log('   Org createdById:', orgDoc.data().createdById);
  }
  
  // Membership doc
  const memberDoc = await db.collection('organizations').doc(orgId).collection('members').doc(uid).get();
  console.log('   Membership doc exists:', memberDoc.exists);
  
  console.log('\n2. Simulating site creation...\n');
  
  // Create a test site document
  const testSiteId = 'test-site-' + Date.now();
  const testSite = {
    id: testSiteId,
    name: 'Test Site',
    organizationId: orgId,
    createdById: uid,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    updatedById: uid,
  };
  
  console.log('   Site data:', JSON.stringify(testSite, null, 2));
  
  // Note: Admin SDK bypasses security rules, so this won't actually test the rules
  // But it will help us verify the data is correct
  console.log('\n   Admin SDK bypasses security rules, so this is just a data validation test.');
  console.log('   To actually test the rules, use the Firebase Console Rules Playground');
  console.log('   or a client SDK with the user\'s credentials.');
  
  // Check what the rules would evaluate
  console.log('\n3. Security rule evaluation (simulated):\n');
  
  // isOnboardingBatchWrite()
  console.log('   isOnboardingBatchWrite():');
  console.log('     - !exists(users/' + uid + '): ', !userDoc.exists);
  console.log('     - createdById == auth.uid: true (we set it)');
  console.log('     - organizationId != null: true');
  console.log('     Result: ', !userDoc.exists ? 'WOULD PASS' : 'FAILS (user exists)');
  
  // incomingBelongsToUserOrg()
  console.log('\n   incomingBelongsToUserOrg():');
  console.log('     - isAuthenticated(): true');
  console.log('     - userDoc.data != null:', userDoc.exists && userDoc.data() != null);
  const userOrgId = userDoc.exists ? userDoc.data().organizationId : null;
  console.log('     - request.resource.data.organizationId == userDoc.data.organizationId:');
  console.log('       ' + orgId + ' == ' + userOrgId + ': ', orgId === userOrgId);
  console.log('     Result: ', (userDoc.exists && userDoc.data() != null && orgId === userOrgId) ? 'WOULD PASS' : 'FAILS');
  
  // isMemberByUid()
  console.log('\n   isMemberByUid(' + orgId + '):');
  console.log('     - isAuthenticated(): true');
  console.log('     - exists(organizations/' + orgId + '/members/' + uid + '):', memberDoc.exists);
  console.log('     Result:', memberDoc.exists ? 'WOULD PASS' : 'FAILS');
  
  // userCreatedOrg()
  console.log('\n   userCreatedOrg(' + orgId + '):');
  const orgCreatedById = orgDoc.exists ? orgDoc.data().createdById : null;
  console.log('     - org.data.createdById == auth.uid:');
  console.log('       ' + orgCreatedById + ' == ' + uid + ': ', orgCreatedById === uid);
  console.log('     Result:', orgCreatedById === uid ? 'WOULD PASS' : 'FAILS');
  
  console.log('\n=== Overall Assessment ===');
  console.log('At least ONE of these conditions should pass for site creation:');
  console.log('  1. isOnboardingBatchWrite: FAILS (user doc exists)');
  console.log('  2. incomingBelongsToUserOrg:', (userDoc.exists && orgId === userOrgId) ? 'PASSES' : 'FAILS');
  console.log('  3. isMemberByUid:', memberDoc.exists ? 'PASSES' : 'FAILS');
  console.log('  4. isUserOnboardingEligible: FAILS (user doc exists with orgId)');
  console.log('  5. userCreatedOrg:', orgCreatedById === uid ? 'PASSES' : 'FAILS');
  
  if ((userDoc.exists && orgId === userOrgId) || memberDoc.exists || orgCreatedById === uid) {
    console.log('\n✅ Security rules SHOULD ALLOW site creation!');
    console.log('   If you\'re still getting permission denied, there might be:');
    console.log('   - Browser cache (try hard refresh Ctrl+Shift+R)');
    console.log('   - Firestore rules not deployed (run: firebase deploy --only firestore:rules)');
    console.log('   - A bug in the app code setting wrong values');
  } else {
    console.log('\n❌ Security rules would DENY site creation');
    console.log('   Missing requirements detected.');
  }
  
  console.log('\n=== Done ===');
}

testSiteCreation().then(() => process.exit(0)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
