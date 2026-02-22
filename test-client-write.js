// Test client-side Firestore write using Firebase Client SDK
const { initializeApp } = require('firebase/app');
const { getFirestore, doc, setDoc, deleteDoc } = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

const firebaseConfig = {
  apiKey: "AIzaSyBjCLV6OLH0sFv8n4pPM9Wz4i6J8cXHZMw",
  authDomain: "seafoundryapp.firebaseapp.com",
  projectId: "seafoundryapp",
};

async function testWrite() {
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);
  
  console.log('=== Testing Client-Side Firestore Write ===\n');
  
  // Sign in as the test user
  console.log('Signing in as dev@seafoundry.com...');
  try {
    const userCred = await signInWithEmailAndPassword(auth, 'dev@seafoundry.com', process.env.TEST_PASSWORD || 'test123');
    console.log('✓ Signed in successfully');
    console.log('  uid:', userCred.user.uid);
    console.log('  email:', userCred.user.email);
    
    // Get the ID token to see the claims
    const token = await userCred.user.getIdToken();
    console.log('  token prefix:', token.substring(0, 50) + '...');
  } catch (e) {
    console.log('❌ Sign in failed:', e.message);
    console.log('\nPlease set TEST_PASSWORD environment variable');
    process.exit(1);
  }
  
  // Try to write an organism record
  const testRecordId = 'test-record-' + Date.now();
  const orgId = 'XHGauKGIyJCoxrCFoz6U';
  const email = 'dev@seafoundry.com';
  const now = new Date().toISOString();
  
  console.log('\nAttempting to write to:', `organizations/${orgId}/organismRecords/${testRecordId}`);
  console.log('  createdById:', email);
  console.log('  organizationId:', orgId);
  
  try {
    await setDoc(doc(db, 'organizations', orgId, 'organismRecords', testRecordId), {
      id: testRecordId,
      modelType: 'organismRecord',
      organismKind: 'coral',
      organizationId: orgId,
      createdById: email,
      createdAt: now,
      updatedAt: now,
      updatedById: email,
      speciesId: 'test-species',
    });
    console.log('✅ Write succeeded!');
    
    // Clean up
    await deleteDoc(doc(db, 'organizations', orgId, 'organismRecords', testRecordId));
    console.log('🧹 Test record deleted');
  } catch (e) {
    console.log('❌ Write failed:', e.code, '-', e.message);
  }
  
  process.exit(0);
}

testWrite();
