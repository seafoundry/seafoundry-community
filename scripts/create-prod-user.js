const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

// Try to use default credentials from gcloud
process.env.GOOGLE_APPLICATION_CREDENTIALS = process.env.GOOGLE_APPLICATION_CREDENTIALS || 
  require('os').homedir() + '/.config/gcloud/application_default_credentials.json';

initializeApp({
  projectId: 'seafoundryapp'
});

const db = getFirestore();
const auth = getAuth();

async function createProdUser() {
  const email = 'dev@seafoundry.com';
  const orgId = 'XHGauKGIyJCoxrCFoz6U';
  const now = new Date().toISOString();
  const userRecord = await auth.getUserByEmail(email);
  const uid = userRecord.uid;
  
  const userDoc = {
    id: uid,
    email: email,
    name: 'Developer',
    organizationId: orgId,
    createdById: uid,
    createdAt: now,
    updatedAt: now,
    updatedById: uid,
  };
  
  console.log('Creating user document:', uid);
  console.log('  organizationId:', orgId);
  
  await db.collection('users').doc(uid).set(userDoc, { merge: true });
  console.log('✅ User document created/updated successfully');
}

createProdUser().then(() => process.exit(0)).catch(e => { 
  console.error('Error:', e.message); 
  process.exit(1); 
});
