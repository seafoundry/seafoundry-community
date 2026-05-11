const admin = require('firebase-admin');
const fs = require('fs');

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(creds),
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function deleteCollection(collectionRef, batchSize = 100) {
  const query = collectionRef.limit(batchSize);
  const snapshot = await query.get();

  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();

  if (snapshot.size >= batchSize) {
    await deleteCollection(collectionRef, batchSize);
  }
}

async function cleanup() {
  const email = 'dev@seafoundry.com';
  const userRecord = await auth.getUserByEmail(email);
  const uid = userRecord.uid;

  console.log('=== Cleaning up all dev@seafoundry.com data ===\n');

  // Delete user document
  console.log('1. Deleting user document...');
  try {
    await db.collection('users').doc(uid).delete();
    console.log('   ✅ User document deleted');
  } catch (e) {
    console.log('   ⚠️', e.message);
  }

  // Find and delete all orgs created by this user
  console.log('\n2. Finding organizations created by dev@seafoundry.com...');
  const orgsSnap = await db.collection('organizations').where('createdById', '==', uid).get();

  if (orgsSnap.empty) {
    console.log('   No organizations found');
  } else {
    console.log(`   Found ${orgsSnap.size} organization(s)`);

    for (const orgDoc of orgsSnap.docs) {
      const orgId = orgDoc.id;
      console.log(`\n   Deleting org: ${orgId}`);

      // Delete subcollections
      const subcollections = ['members', 'slugCounts', 'groups', 'genets', 'organismRecords', 'events', 'cohorts'];
      for (const sub of subcollections) {
        try {
          await deleteCollection(db.collection('organizations').doc(orgId).collection(sub));
          console.log(`      ✅ Deleted ${sub}`);
        } catch (e) {
          console.log(`      ⚠️ ${sub}: ${e.message}`);
        }
      }

      // Delete org document
      await orgDoc.ref.delete();
      console.log(`      ✅ Organization document deleted`);

      // Delete root events for this org
      const eventsSnap = await db.collection('events').where('organizationId', '==', orgId).get();
      if (!eventsSnap.empty) {
        const batch = db.batch();
        eventsSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`      ✅ Deleted ${eventsSnap.size} root events`);
      }

      // Delete sites for this org
      const sitesSnap = await db.collection('sites').where('organizationId', '==', orgId).get();
      if (!sitesSnap.empty) {
        const batch = db.batch();
        sitesSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`      ✅ Deleted ${sitesSnap.size} sites`);
      }
    }
  }

  console.log('\n=== Cleanup complete ===');
}

cleanup().then(() => process.exit(0)).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
