#!/usr/bin/env node
/**
 * Complete user deletion script - removes from Firebase Auth and Firestore
 * Usage: EMAIL=user@example.com GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/delete-user-complete.js
 */
const admin = require('firebase-admin');
const fs = require('fs');

const EMAIL = process.env.EMAIL;
if (!EMAIL) {
  console.error('ERROR: EMAIL environment variable is required');
  console.error('Usage: EMAIL=user@example.com GOOGLE_APPLICATION_CREDENTIALS=./path/to/creds.json node scripts/delete-user-complete.js');
  process.exit(1);
}

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
if (!fs.existsSync(credPath)) {
  console.error('ERROR: Credentials file not found:', credPath);
  process.exit(1);
}

const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(creds) });
const db = admin.firestore();

async function deleteCollection(collectionRef, batchSize = 100) {
  const query = collectionRef.limit(batchSize);
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();

  if (snapshot.size >= batchSize) {
    return snapshot.size + await deleteCollection(collectionRef, batchSize);
  }
  return snapshot.size;
}

async function deleteUserComplete() {
  const userId = EMAIL.toLowerCase();
  console.log('='.repeat(60));
  console.log('DELETING USER: ' + EMAIL);
  console.log('='.repeat(60));

  // 1. Check and delete Firebase Auth user
  console.log('\n1. Firebase Auth:');
  let authUid = null;
  try {
    const authUser = await admin.auth().getUserByEmail(EMAIL);
    authUid = authUser.uid;
    console.log('   Found auth user with UID:', authUid);
    await admin.auth().deleteUser(authUid);
    console.log('   ✅ Deleted from Firebase Auth');
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      console.log('   ⚠️  User not found in Firebase Auth');
    } else {
      console.error('   ❌ Error:', e.message);
    }
  }

  // 2. Check and delete Firestore user document
  console.log('\n2. Firestore User Document:');
  let userOrgId = null;
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      userOrgId = userDoc.data().organizationId;
      console.log('   Found user doc, organizationId:', userOrgId);
      await db.collection('users').doc(userId).delete();
      console.log('   ✅ Deleted user document');
    } else {
      console.log('   ⚠️  User document does not exist');
    }
  } catch (e) {
    console.error('   ❌ Error:', e.message);
  }

  // 3. Find organizations created by this user
  console.log('\n3. Organizations Created By User:');
  const orgsToDelete = [];
  try {
    const orgsSnap = await db.collection('organizations')
      .where('createdById', '==', userId)
      .get();
    if (!orgsSnap.empty) {
      orgsSnap.forEach(doc => {
        orgsToDelete.push(doc.id);
        console.log('   Found org:', doc.id, '-', doc.data().name);
      });
    }
    // Also check with original case
    if (userId !== EMAIL) {
      const orgsSnap2 = await db.collection('organizations')
        .where('createdById', '==', EMAIL)
        .get();
      orgsSnap2.forEach(doc => {
        if (!orgsToDelete.includes(doc.id)) {
          orgsToDelete.push(doc.id);
          console.log('   Found org:', doc.id, '-', doc.data().name);
        }
      });
    }
    // Include user's current org if different
    if (userOrgId && !orgsToDelete.includes(userOrgId)) {
      orgsToDelete.push(userOrgId);
      console.log('   Adding user\'s org:', userOrgId);
    }
  } catch (e) {
    console.error('   ❌ Error:', e.message);
  }

  if (orgsToDelete.length === 0) {
    console.log('   ⚠️  No organizations to delete');
  }

  // 4. Delete each organization and its subcollections
  for (const orgId of orgsToDelete) {
    console.log('\n4. Deleting Organization:', orgId);

    // Delete subcollections
    const subcollections = [
      'members', 'slugCounts', 'groups', 'genets', 'organismRecords',
      'events', 'cohorts', 'provenances', 'sites', 'structures',
      'custom_types', 'permits', 'deliverables'
    ];

    for (const sub of subcollections) {
      try {
        const count = await deleteCollection(
          db.collection('organizations').doc(orgId).collection(sub)
        );
        if (count > 0) {
          console.log(`   ✅ Deleted ${count} docs from ${sub}`);
        }
      } catch (e) {
        // Ignore if collection doesn't exist
      }
    }

    // Delete the org document itself
    try {
      await db.collection('organizations').doc(orgId).delete();
      console.log('   ✅ Deleted organization document');
    } catch (e) {
      console.error('   ❌ Error deleting org:', e.message);
    }
  }

  // 5. Delete root-level sites for these orgs
  console.log('\n5. Root-level Sites:');
  for (const orgId of orgsToDelete) {
    try {
      const sitesSnap = await db.collection('sites')
        .where('organizationId', '==', orgId)
        .get();
      if (!sitesSnap.empty) {
        const batch = db.batch();
        sitesSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`   ✅ Deleted ${sitesSnap.size} sites for org ${orgId}`);
      }
    } catch (e) {
      console.error('   ❌ Error:', e.message);
    }
  }

  // 6. Delete root-level events for these orgs
  console.log('\n6. Root-level Events:');
  for (const orgId of orgsToDelete) {
    try {
      const eventsSnap = await db.collection('events')
        .where('organizationId', '==', orgId)
        .get();
      if (!eventsSnap.empty) {
        const batch = db.batch();
        eventsSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`   ✅ Deleted ${eventsSnap.size} events for org ${orgId}`);
      }
    } catch (e) {
      console.error('   ❌ Error:', e.message);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('DELETION COMPLETE');
  console.log('='.repeat(60));
}

deleteUserComplete()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
