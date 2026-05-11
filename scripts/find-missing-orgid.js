/**
 * Script to find Firestore documents missing organizationId field.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/find-missing-orgid.js
 *
 * This script identifies documents that were created before organizationId
 * was consistently written, which causes cross-org filtering issues.
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();

async function findMissingOrgId() {
  console.log('=== Finding documents with missing organizationId ===\n');

  const results = {
    total: 0,
    byCollection: {},
  };

  // Root-level collections to check
  const rootCollections = ['events', 'sites'];

  for (const col of rootCollections) {
    console.log(`Checking root collection: ${col}...`);

    // Check for null organizationId
    const nullSnap = await db.collection(col)
      .where('organizationId', '==', null)
      .get();

    // Check for empty string organizationId
    const emptySnap = await db.collection(col)
      .where('organizationId', '==', '')
      .get();

    // Also get all docs to check for missing field entirely
    const allSnap = await db.collection(col).get();
    const missingFieldDocs = allSnap.docs.filter(d => {
      const data = d.data();
      return !('organizationId' in data);
    });

    const totalMissing = nullSnap.size + emptySnap.size + missingFieldDocs.length;
    results.byCollection[col] = {
      null: nullSnap.size,
      empty: emptySnap.size,
      missingField: missingFieldDocs.length,
      total: totalMissing,
      samples: [],
    };
    results.total += totalMissing;

    console.log(`  ${col}: ${totalMissing} docs missing organizationId`);
    console.log(`    - null: ${nullSnap.size}, empty: ${emptySnap.size}, missing field: ${missingFieldDocs.length}`);

    // Sample docs
    const sampleDocs = [
      ...nullSnap.docs.slice(0, 3),
      ...emptySnap.docs.slice(0, 3),
      ...missingFieldDocs.slice(0, 3),
    ].slice(0, 5);

    for (const doc of sampleDocs) {
      const data = doc.data();
      const sample = {
        path: doc.ref.path,
        urlPath: data.urlPath || 'N/A',
        createdAt: data.createdAt?.toDate?.()?.toISOString() || 'N/A',
      };
      results.byCollection[col].samples.push(sample);
      console.log(`    Sample: ${sample.path} (urlPath: ${sample.urlPath})`);
    }
    console.log('');
  }

  // Check nested collections under organizations
  console.log('Checking nested collections under organizations...\n');

  const orgsSnap = await db.collection('organizations').get();
  const nestedCollections = ['groups', 'genets', 'organismRecords'];

  for (const org of orgsSnap.docs) {
    const orgId = org.id;

    for (const sub of nestedCollections) {
      const collPath = `organizations/${orgId}/${sub}`;
      const subRef = org.ref.collection(sub);

      // Check for null
      const nullSnap = await subRef.where('organizationId', '==', null).get();

      // Check for empty
      const emptySnap = await subRef.where('organizationId', '==', '').get();

      // Check for missing field
      const allSnap = await subRef.get();
      const missingFieldDocs = allSnap.docs.filter(d => {
        const data = d.data();
        return !('organizationId' in data);
      });

      // Also check for wrong organizationId (doesn't match parent org)
      const wrongOrgDocs = allSnap.docs.filter(d => {
        const data = d.data();
        return data.organizationId && data.organizationId !== orgId;
      });

      const totalMissing = nullSnap.size + emptySnap.size + missingFieldDocs.length;

      if (totalMissing > 0 || wrongOrgDocs.length > 0) {
        const key = `${orgId}/${sub}`;
        results.byCollection[key] = {
          null: nullSnap.size,
          empty: emptySnap.size,
          missingField: missingFieldDocs.length,
          wrongOrg: wrongOrgDocs.length,
          total: totalMissing,
          samples: [],
        };
        results.total += totalMissing;

        console.log(`  ${collPath}: ${totalMissing} missing, ${wrongOrgDocs.length} wrong orgId`);

        // Sample docs
        const sampleDocs = [
          ...nullSnap.docs.slice(0, 2),
          ...emptySnap.docs.slice(0, 2),
          ...missingFieldDocs.slice(0, 2),
        ].slice(0, 3);

        for (const doc of sampleDocs) {
          const data = doc.data();
          console.log(`    Sample: ${doc.ref.path} (urlPath: ${data.urlPath || 'N/A'})`);
        }

        if (wrongOrgDocs.length > 0) {
          console.log(`    Wrong orgId samples:`);
          for (const doc of wrongOrgDocs.slice(0, 2)) {
            const data = doc.data();
            console.log(`      ${doc.ref.path} has orgId=${data.organizationId}, expected ${orgId}`);
          }
        }
      }
    }
  }

  // Summary
  console.log('\n=== SUMMARY ===');
  console.log(`Total documents with missing/invalid organizationId: ${results.total}`);
  console.log('\nBreakdown by collection:');
  for (const [col, data] of Object.entries(results.byCollection)) {
    if (data.total > 0 || data.wrongOrg > 0) {
      console.log(`  ${col}: ${data.total} missing${data.wrongOrg ? `, ${data.wrongOrg} wrong org` : ''}`);
    }
  }

  return results;
}

// Run the script
findMissingOrgId()
  .then((results) => {
    console.log('\n=== COMPLETE ===');
    if (results.total > 0) {
      console.log('\nRecommendation: Run cleanup script or re-seed demo data with correct organizationId values.');
    } else {
      console.log('\nAll documents have valid organizationId. No cleanup needed.');
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
