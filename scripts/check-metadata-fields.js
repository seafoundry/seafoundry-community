#!/usr/bin/env node
/**
 * Check metadata fields across all records
 */
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function checkMetadataFields() {
  console.log('=== Checking Metadata Fields ===\n');

  const collections = ['events', 'users', 'organizations', 'sites', 'groups', 'organismRecords'];

  for (const collectionName of collections) {
    let query = db.collection(collectionName);
    if (collectionName !== 'users' && collectionName !== 'organizations') {
      // Add org filter for non-root collections
      query = query.where('organizationId', '==', 'demo_org_pro');
    }

    const snap = await query.limit(100).get();

    const issues = [];
    snap.forEach(doc => {
      const data = doc.data();
      const id = data.id || doc.id;

      if (data.metadata !== undefined && data.metadata !== null) {
        if (Array.isArray(data.metadata)) {
          issues.push({ id: id.slice(0, 40), type: 'Array', value: JSON.stringify(data.metadata).slice(0, 80) });
        } else if (typeof data.metadata !== 'object') {
          issues.push({ id: id.slice(0, 40), type: typeof data.metadata, value: String(data.metadata).slice(0, 80) });
        }
      }
    });

    if (issues.length > 0) {
      console.log(`\n❌ ${collectionName}: ${issues.length} metadata issues`);
      issues.forEach(i => {
        console.log(`  - ${i.id}: ${i.type} - ${i.value}`);
      });
    } else {
      console.log(`✅ ${collectionName}: ${snap.size} docs checked, no metadata issues`);
    }
  }

  // Also check genets in subcollection
  const genetSnap = await db.collection('organizations').doc('demo_org_pro').collection('genets').limit(100).get();
  const genetIssues = [];
  genetSnap.forEach(doc => {
    const data = doc.data();
    const id = data.id || doc.id;

    if (data.metadata !== undefined && data.metadata !== null) {
      if (Array.isArray(data.metadata)) {
        genetIssues.push({ id: id.slice(0, 40), type: 'Array', value: JSON.stringify(data.metadata).slice(0, 80) });
      } else if (typeof data.metadata !== 'object') {
        genetIssues.push({ id: id.slice(0, 40), type: typeof data.metadata, value: String(data.metadata).slice(0, 80) });
      }
    }
  });

  if (genetIssues.length > 0) {
    console.log(`\n❌ genets (subcollection): ${genetIssues.length} metadata issues`);
    genetIssues.forEach(i => {
      console.log(`  - ${i.id}: ${i.type} - ${i.value}`);
    });
  } else {
    console.log(`✅ genets (subcollection): ${genetSnap.size} docs checked, no metadata issues`);
  }

  process.exit(0);
}

checkMetadataFields().catch(e => { console.error(e); process.exit(1); });
