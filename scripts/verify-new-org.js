const admin = require('firebase-admin');
const fs = require('fs');

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(creds),
});

const db = admin.firestore();

async function verify() {
  const email = 'dev@seafoundry.com';
  const orgId = '3c3WxBnZX4aTSObOjqJX';
  const uid = 'hnDmMPLLfIPfaG8zsosQo7xCE5R2';
  
  console.log('=== Verifying Firestore State ===\n');
  
  // Check user
  const userDoc = await db.collection('users').doc(uid).get();
  console.log('User doc:', userDoc.exists ? 'EXISTS' : 'MISSING');
  if (userDoc.exists) {
    console.log('  organizationId:', userDoc.data().organizationId);
  }
  
  // Check org
  const orgDoc = await db.collection('organizations').doc(orgId).get();
  console.log('Org doc:', orgDoc.exists ? 'EXISTS' : 'MISSING');
  if (orgDoc.exists) {
    console.log('  createdById:', orgDoc.data().createdById);
  }
  
  // Check membership
  const memberDoc = await db.collection('organizations').doc(orgId).collection('members').doc(uid).get();
  console.log('Membership doc:', memberDoc.exists ? 'EXISTS' : 'MISSING');
  if (memberDoc.exists) {
    console.log('  data:', JSON.stringify(memberDoc.data()));
  }
  
  console.log('\n=== Security Rule Evaluation ===');
  console.log('For site creation with:');
  console.log('  organizationId:', orgId);
  console.log('  createdById:', uid);
  console.log('  auth.uid:', uid);
  console.log('');
  console.log('incomingBelongsToUserOrg(): ', userDoc.exists && userDoc.data().organizationId === orgId ? 'PASS' : 'FAIL');
  console.log('isMemberByUid():', memberDoc.exists ? 'PASS' : 'FAIL');
  console.log('userCreatedOrg():', orgDoc.exists && orgDoc.data().createdById === uid ? 'PASS' : 'FAIL');
}

verify().then(() => process.exit(0)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
