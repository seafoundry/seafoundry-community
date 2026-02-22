#!/usr/bin/env node
/**
 * Test security rules configuration for onboarding
 * Run with: GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/test-rules-config.js
 */
require('dotenv').config();
const { admin, db } = require('./config-json');

const TEST_EMAIL = process.env.TEST_EMAIL || 'dev@seafoundry.com';
const TEST_UID = process.env.TEST_UID || null;

async function resolveUid() {
  if (TEST_UID) return TEST_UID;
  try {
    const userRecord = await admin.auth().getUserByEmail(TEST_EMAIL);
    return userRecord.uid;
  } catch (error) {
    console.warn('⚠️  Unable to resolve UID for test email:', error.message);
    return null;
  }
}

async function testRulesConfig() {
  const resolvedUid = await resolveUid();

  console.log('='.repeat(60));
  console.log('Testing Security Rules Configuration');
  console.log('='.repeat(60));
  console.log('');
  console.log('Test email: ' + TEST_EMAIL);
  console.log('Test UID: ' + (resolvedUid || 'N/A'));
  console.log('');

  if (!resolvedUid) {
    console.log('No UID resolved. Provide TEST_UID or ensure the user exists in Auth.');
    process.exit(1);
  }

  // Check if user document exists
  console.log('1. Checking existing user document...');
  const userDoc = await db.collection('users').doc(resolvedUid).get();
  if (userDoc.exists) {
    const userData = userDoc.data();
    console.log('   User document EXISTS at /users/' + resolvedUid);
    console.log('   - email: ' + (userData.email || 'N/A'));
    console.log('   - organizationId: ' + (userData.organizationId || 'N/A'));
    console.log('   - createdById: ' + (userData.createdById || 'N/A'));

    // Check if organizationId is stale (points to non-existent org)
    if (userData.organizationId) {
      const orgRef = db.collection('organizations').doc(userData.organizationId);
      const orgDoc = await orgRef.get();
      if (!orgDoc.exists) {
        console.log('');
        console.log('   ** WARNING: organizationId points to non-existent org!');
        console.log('   ** The user document may need to be reset');
      } else {
        console.log('   - Organization exists: ' + orgDoc.data().name);
      }
    }
  } else {
    console.log('   User document does NOT exist at /users/' + resolvedUid);
    console.log('   (This is expected for a new user during onboarding)');
  }

  console.log('');
  console.log('2. Security rules configuration:');
  console.log('   For USER CREATE at /users/{userId}:');
  console.log('   - Rule checks: request.auth.uid == userId');
  console.log('   - userId would be: ' + resolvedUid);
  console.log('   - request.auth.uid returns: ' + resolvedUid);
  console.log('   - Expected match: YES');

  console.log('');
  console.log('3. For ORGANIZATION CREATE at /organizations/{orgId}:');
  console.log('   - Rule checks: isAuthenticated() && request.resource.data.organizationId == orgId');
  console.log('   - Expected match: YES (orgId is set equal to organizationId field)');

  console.log('');
  console.log('4. For EVENT CREATE at /events/{eventId}:');
  console.log('   - Rule checks: recordModelType == "organization" && createdById == request.auth.uid');
  console.log('   - Expected match: YES (if createdById is ' + resolvedUid + ')');

  console.log('');
  console.log('='.repeat(60));
  console.log('If onboarding still fails, check:');
  console.log('1. Is request.auth.uid the expected value in Firebase Auth?');
  console.log('2. Is the user hitting the correct Firebase project?');
  console.log('3. Check Firebase Console > Firestore > Rules to test rules');
  console.log('='.repeat(60));
}

testRulesConfig()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
