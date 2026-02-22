#!/usr/bin/env node

/**
 * Check all sites in the database
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function initializeFirebase() {
  const serviceAccountPath = path.join(process.cwd(), 'firebase-service-account.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id
    });
  }
  return admin.app();
}

async function main() {
  console.log('='.repeat(80));
  console.log('CHECKING ALL SITES IN DATABASE');
  console.log('='.repeat(80));

  initializeFirebase();
  const db = admin.firestore();

  // Check top-level sites collection
  console.log('\n1. TOP-LEVEL /sites COLLECTION:');
  console.log('-'.repeat(80));
  const sitesSnapshot = await db.collection('sites').get();
  console.log(`   Total sites: ${sitesSnapshot.size}`);
  sitesSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`   - ${doc.id}: name="${data.name}", orgId="${data.organizationId}"`);
  });

  // Check org-nested sites for each org
  console.log('\n2. ORG-NESTED SITES:');
  console.log('-'.repeat(80));
  const orgsSnapshot = await db.collection('organizations').get();
  for (const orgDoc of orgsSnapshot.docs) {
    const orgId = orgDoc.id;
    const orgData = orgDoc.data();
    console.log(`\n   Organization: ${orgId} (${orgData.name})`);

    const nestedSites = await db.collection('organizations').doc(orgId).collection('sites').get();
    if (nestedSites.empty) {
      console.log('     No nested sites');
    } else {
      nestedSites.forEach(siteDoc => {
        const data = siteDoc.data();
        console.log(`     - ${siteDoc.id}: name="${data.name}"`);
      });
    }
  }

  // Check for any data in demo_sites
  console.log('\n3. DEMO_SITES COLLECTION:');
  console.log('-'.repeat(80));
  const demoSitesSnapshot = await db.collection('demo_sites').get();
  console.log(`   Total demo sites: ${demoSitesSnapshot.size}`);

  console.log('\n' + '='.repeat(80));
  console.log('DONE');
  console.log('='.repeat(80));

  process.exit(0);
}

main().catch(error => {
  console.error('FATAL:', error);
  process.exit(1);
});
