const admin = require('firebase-admin');
const fs = require('fs');

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(creds),
});

const db = admin.firestore();

async function deleteCollection(collectionRef, batchSize = 100) {
  const query = collectionRef.limit(batchSize);
  const snapshot = await query.get();

  if (snapshot.empty) {
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();

  // Recurse for remaining docs
  if (snapshot.size >= batchSize) {
    await deleteCollection(collectionRef, batchSize);
  }
}

async function resetDevUser() {
  const email = 'dev@seafoundry.com';
  const orgId = '3c3WxBnZX4aTSObOjqJX';
  const uid = 'hnDmMPLLfIPfaG8zsosQo7xCE5R2';

  console.log('=== Resetting dev user account ===\n');
  console.log('Email:', email);
  console.log('Org ID:', orgId);
  console.log('UID:', uid);
  console.log('');

  // Delete user document
  console.log('1. Deleting user document...');
  try {
    await db.collection('users').doc(uid).delete();
    console.log('   ✅ User document deleted');
  } catch (e) {
    console.log('   ⚠️ User document not found or error:', e.message);
  }

  // Delete organization subcollections first
  console.log('2. Deleting organization subcollections...');
  const subcollections = ['members', 'slugCounts', 'groups', 'genets', 'organismRecords', 'events', 'cohorts'];
  for (const sub of subcollections) {
    try {
      const subRef = db.collection('organizations').doc(orgId).collection(sub);
      await deleteCollection(subRef);
      console.log(`   ✅ Deleted ${sub}`);
    } catch (e) {
      console.log(`   ⚠️ ${sub}: ${e.message}`);
    }
  }

  // Delete organization document
  console.log('3. Deleting organization document...');
  try {
    await db.collection('organizations').doc(orgId).delete();
    console.log('   ✅ Organization deleted');
  } catch (e) {
    console.log('   ⚠️ Organization not found or error:', e.message);
  }

  // Delete events in root collection for this org
  console.log('4. Deleting root events for org...');
  try {
    const eventsSnap = await db.collection('events').where('organizationId', '==', orgId).get();
    if (!eventsSnap.empty) {
      const batch = db.batch();
      eventsSnap.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      console.log(`   ✅ Deleted ${eventsSnap.size} root events`);
    } else {
      console.log('   ✅ No root events found');
    }
  } catch (e) {
    console.log('   ⚠️ Root events error:', e.message);
  }

  // Delete sites for this org
  console.log('5. Deleting sites for org...');
  try {
    const sitesSnap = await db.collection('sites').where('organizationId', '==', orgId).get();
    if (!sitesSnap.empty) {
      const batch = db.batch();
      sitesSnap.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      console.log(`   ✅ Deleted ${sitesSnap.size} sites`);
    } else {
      console.log('   ✅ No sites found');
    }
  } catch (e) {
    console.log('   ⚠️ Sites error:', e.message);
  }

  console.log('\n=== Reset complete ===');
  console.log('The dev@seafoundry.com user can now go through onboarding again.');
}

resetDevUser().then(() => process.exit(0)).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
