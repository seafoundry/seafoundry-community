#!/usr/bin/env node

/**
 * Simulate Site Creation Security Rule Evaluation (UID-based).
 * Usage:
 *   node scripts/simulate-site-creation.js
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

async function simulateSiteCreation() {
  console.log('='.repeat(80));
  console.log('SIMULATING SITE CREATION SECURITY RULE EVALUATION (UID-BASED)');
  console.log('='.repeat(80));

  initializeFirebase();
  const db = admin.firestore();
  const auth = admin.auth();

  // Step 1: Get Firebase Auth user
  console.log('\n1. FIREBASE AUTH USER');
  console.log('-'.repeat(80));
  let authUser;
  try {
    authUser = await auth.getUserByEmail(EMAIL);
    console.log(`   UID: ${authUser.uid}`);
    console.log(`   Email: ${authUser.email}`);
  } catch (error) {
    console.log(`   ERROR: ${error.message}`);
    return;
  }

  const authUid = authUser.uid;

  // Step 2: Simulate getUserDoc()
  console.log('\n2. SECURITY RULE: getUserDoc()');
  console.log('-'.repeat(80));
  console.log(`   Looking up: /users/${authUid}`);
  const userDoc = await db.collection('users').doc(authUid).get();
  if (!userDoc.exists) {
    console.log('   [FAIL] User document does not exist!');
    console.log('   => All subsequent rules will fail');
    return;
  }
  const userData = userDoc.data();
  console.log('   [PASS] User document exists');
  console.log(`   - id: ${userData.id}`);
  console.log(`   - email: ${userData.email}`);
  console.log(`   - organizationId: ${userData.organizationId}`);

  // Step 3: Simulate incoming site data (what the app would send)
  console.log('\n3. SIMULATED INCOMING SITE DATA');
  console.log('-'.repeat(80));
  const incomingSiteData = {
    id: 'simulated-site-id',
    name: 'Test Site',
    organizationId: userData.organizationId,
    createdById: authUid,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    updatedById: authUid,
    siteTypeId: 'nursery_ex_situ',
    slug: 'site1',
    urlPath: 'seafoundry/site1',
    internalPath: `${userData.organizationId}/simulated-site-id`,
  };
  console.log('   Site data that would be sent:');
  console.log(`   - organizationId: ${incomingSiteData.organizationId}`);
  console.log(`   - createdById: ${incomingSiteData.createdById}`);

  // Step 4: Evaluate isIncomingCreator()
  console.log('\n4. SECURITY RULE: isIncomingCreator()');
  console.log('-'.repeat(80));
  console.log('   Checks:');
  console.log('   - isAuthenticated() [PASS]');
  console.log(`   - request.resource.data.createdById == request.auth.uid`);
  console.log(`     "${incomingSiteData.createdById}" == "${authUid}"`);
  const isIncomingCreator = incomingSiteData.createdById === authUid;
  console.log(`   [${isIncomingCreator ? 'PASS' : 'FAIL'}]`);

  // Step 5: Evaluate incomingBelongsToUserOrg()
  console.log('\n5. SECURITY RULE: incomingBelongsToUserOrg()');
  console.log('-'.repeat(80));
  const incomingBelongsToUserOrg =
    userData.organizationId != null &&
    incomingSiteData.organizationId === userData.organizationId;
  console.log(`   - user.organizationId == incoming.organizationId => ${incomingBelongsToUserOrg}`);

  // Step 6: Evaluate userCreatedOrg()
  console.log('\n6. SECURITY RULE: userCreatedOrg()');
  console.log('-'.repeat(80));
  console.log(`   Looking up: /organizations/${incomingSiteData.organizationId}`);
  const orgDoc = await db.collection('organizations').doc(incomingSiteData.organizationId).get();
  if (!orgDoc.exists) {
    console.log('   [FAIL] Organization does not exist');
  } else {
    const orgData = orgDoc.data();
    console.log(`   Organization createdById: "${orgData.createdById}"`);
    const userCreatedOrg = orgData.createdById === authUid;
    console.log(`   [${userCreatedOrg ? 'PASS' : 'FAIL'}]`);
  }

  // Step 7: Final evaluation
  console.log('\n7. FINAL SITE CREATE RULE EVALUATION');
  console.log('-'.repeat(80));
  console.log('   allow create: if');
  console.log('     isOnboardingBatchWrite() ||');
  console.log('     incomingBelongsToUserOrg() ||');
  console.log('     (isIncomingCreator() && userCreatedOrg(request.resource.data.organizationId))');

  const orgData = orgDoc.exists ? orgDoc.data() : null;
  const userCreatedOrg = orgData && orgData.createdById === authUid;

  const finalResult = incomingBelongsToUserOrg || (isIncomingCreator && userCreatedOrg);

  console.log('');
  console.log(`   FINAL RESULT: ${finalResult ? 'ALLOW' : 'DENY'}`);
}

simulateSiteCreation().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
