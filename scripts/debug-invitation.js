#!/usr/bin/env node
/**
 * Debug script to check invitation-related data in Firestore
 * and test security rules
 */

const admin = require('firebase-admin');
const { initializeApp: initializeClientApp } = require('firebase/app');
const { getFirestore: getClientFirestore, doc, setDoc, collection, addDoc } = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

// Initialize admin SDK with service account
const serviceAccount = require('../firebase-service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Firebase client config for production
const firebaseConfig = {
  apiKey: "AIzaSyCfgJMjyLOIm2Pt2OcQJ0bz_nZLHqHaM2E",
  authDomain: "seafoundryapp.firebaseapp.com",
  projectId: "seafoundryapp",
  storageBucket: "seafoundryapp.firebasestorage.app",
  messagingSenderId: "599860030371",
  appId: "1:599860030371:web:0137b5ec02a3ac3e2bc816",
};

async function main() {
  const userEmail = 'dev@seafoundry.com';
  const orgId = 'XHGauKGIyJCoxrCFoz6U';
  const userRecord = await admin.auth().getUserByEmail(userEmail);
  const userId = userRecord.uid;

  console.log('\n=== Checking Firestore Data ===\n');

  // 1. Check user document
  console.log('1. User document at users/' + userId);
  const userDoc = await db.collection('users').doc(userId).get();
  if (userDoc.exists) {
    const userData = userDoc.data();
    console.log('   ✅ EXISTS');
    console.log('   - organizationId:', userData.organizationId);
    console.log('   - email:', userData.email);
    console.log('   - role:', userData.role);
  } else {
    console.log('   ❌ NOT FOUND');
  }

  // 2. Check organization document
  console.log('\n2. Organization document at organizations/' + orgId);
  const orgDoc = await db.collection('organizations').doc(orgId).get();
  if (orgDoc.exists) {
    const orgData = orgDoc.data();
    console.log('   ✅ EXISTS');
    console.log('   - name:', orgData.name);
    console.log('   - domain:', orgData.domain);
  } else {
    console.log('   ❌ NOT FOUND');
  }

  // 3. Check all invitations for this org
  console.log('\n3. Invitations for org ' + orgId);
  const invitations = await db.collection('invitations')
    .where('organizationId', '==', orgId)
    .get();

  if (invitations.empty) {
    console.log('   📭 No invitations found');
  } else {
    console.log('   Found', invitations.size, 'invitation(s):');
    invitations.forEach(doc => {
      const data = doc.data();
      console.log('   - ID:', doc.id);
      console.log('     email:', data.email);
      console.log('     status:', data.status);
      console.log('     emailSent:', data.emailSent);
      console.log('     emailError:', data.emailError);
      console.log('     createdAt:', data.createdAt);
    });
  }

  // 4. Check all invitations (any org)
  console.log('\n4. All invitations in collection (first 10)');
  const allInvitations = await db.collection('invitations').limit(10).get();
  if (allInvitations.empty) {
    console.log('   📭 Collection is empty');
  } else {
    console.log('   Found', allInvitations.size, 'total invitation(s)');
    allInvitations.forEach(doc => {
      const data = doc.data();
      console.log('   - ID:', doc.id, '| org:', data.organizationId, '| email:', data.email, '| status:', data.status);
    });
  }

  // 5. Actually create a test invitation using admin SDK
  console.log('\n5. Creating test invitation using admin SDK...');
  const testInvitation = {
    email: 'test-invite@example.com',
    organizationId: orgId,
    invitedById: userId,
    status: 'pending',
    createdById: userId,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    updatedById: userId,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    token: 'admin-test-token-' + Date.now(),
  };

  try {
    const docRef = await db.collection('invitations').add(testInvitation);
    console.log('   ✅ SUCCESS - Created invitation with ID:', docRef.id);

    // Clean up - delete the test invitation
    await docRef.delete();
    console.log('   🗑️  Cleaned up test invitation');
  } catch (err) {
    console.log('   ❌ FAILED:', err.message);
  }

  console.log('\n=== Done ===\n');
  process.exit(0);
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
