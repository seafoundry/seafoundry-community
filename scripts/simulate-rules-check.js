#!/usr/bin/env node
/**
 * Simulate Firestore security rules check for production/demo users (UID-based).
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/simulate-rules-check.js
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/simulate-rules-check.js --demo
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const app = initializeApp({
  credential: cert(require('../firebase-service-account.json'))
});

const db = getFirestore(app);
const auth = getAuth(app);

const isDemoMode = process.argv.includes('--demo');

const USER_EMAIL = isDemoMode ? 'pro@provenance.app' : 'dev@seafoundry.com';
const ORG_ID = isDemoMode ? 'demo_org_pro' : '0X7z4AiZBbnKxcMWx5KJ';

async function simulateRulesCheck() {
  console.log('🔍 Simulating Firestore Security Rules Check (UID-based)\n');
  console.log(`Mode: ${isDemoMode ? 'DEMO' : 'PRODUCTION'}`);
  console.log(`Email: ${USER_EMAIL}`);
  console.log(`Org ID: ${ORG_ID}`);
  console.log('='.repeat(60));

  let authUser;
  try {
    authUser = await auth.getUserByEmail(USER_EMAIL);
    console.log('\n📝 AUTH USER (from Firebase Auth):');
    console.log(`   - UID: ${authUser.uid}`);
    console.log(`   - Email: ${authUser.email}`);
  } catch (e) {
    console.log('❌ Auth user not found:', e.message);
    return;
  }

  const authUid = authUser.uid;

  // 1. Check user doc at UID path (what incomingBelongsToUserOrg does)
  console.log('\n' + '='.repeat(60));
  console.log('SIMULATING: incomingBelongsToUserOrg()');
  console.log('='.repeat(60));

  const userDocPath = `users/${authUid}`;
  console.log(`\n📄 Looking up user doc at: ${userDocPath}`);
  const userDoc = await db.collection('users').doc(authUid).get();

  if (userDoc.exists) {
    const userData = userDoc.data();
    console.log('   ✅ User doc EXISTS');
    console.log(`   - id: ${userData.id}`);
    console.log(`   - email: ${userData.email}`);
    console.log(`   - organizationId: ${userData.organizationId}`);

    console.log(`\n🔍 Comparing organizationIds:`);
    console.log(`   - User doc organizationId: ${userData.organizationId}`);
    console.log(`   - Expected (incoming data): ${ORG_ID}`);
    if (userData.organizationId === ORG_ID) {
      console.log('   ✅ MATCH - incomingBelongsToUserOrg() would return TRUE');
    } else {
      console.log('   ❌ MISMATCH - incomingBelongsToUserOrg() would return FALSE');
    }
  } else {
    console.log('   ❌ User doc does NOT exist!');
    console.log('   ⚠️ incomingBelongsToUserOrg() would return FALSE');
  }

  // 2. Check membership doc (what isMemberByUid does)
  console.log('\n' + '='.repeat(60));
  console.log('SIMULATING: isMemberByUid()');
  console.log('='.repeat(60));

  const memberDocPath = `organizations/${ORG_ID}/members/${authUid}`;
  console.log(`\n📄 Looking up membership doc at: ${memberDocPath}`);
  const memberDoc = await db.collection('organizations').doc(ORG_ID).collection('members').doc(authUid).get();

  if (memberDoc.exists) {
    console.log('   ✅ Membership doc EXISTS');
    console.log('   ✅ isMemberByUid() would return TRUE');
  } else {
    console.log('   ❌ Membership doc does NOT exist!');
    console.log('   ❌ isMemberByUid() would return FALSE');
  }

  // 3. createdById checks
  console.log('\n' + '='.repeat(60));
  console.log('SIMULATING: createdById check');
  console.log('='.repeat(60));

  console.log(`\n🔑 Rule requires: request.resource.data.createdById == request.auth.uid`);
  console.log(`   - request.auth.uid = "${authUid}"`);
  console.log(`   - If user.id in app = "${authUid}", this check PASSES`);

  if (userDoc.exists) {
    const userData = userDoc.data();
    console.log(`\n🧾 User doc sanity:`);
    console.log(`   - user.id field: "${userData.id}"`);
    console.log(`   - user.email field: "${userData.email}"`);
    if (userData.id === authUid) {
      console.log('   ✅ user.id matches auth uid - createdById check should PASS');
    } else {
      console.log('   ❌ user.id does NOT match auth uid - createdById check may FAIL');
    }
  }

  console.log('\n✅ Simulation complete');
}

simulateRulesCheck().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
