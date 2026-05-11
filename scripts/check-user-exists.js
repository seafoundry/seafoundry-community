#!/usr/bin/env node
/**
 * Check if user and organization exist in Firestore
 */
require('dotenv').config();
const { admin, db } = require('./config-json');

const USER_EMAIL = process.env.CHECK_USER_EMAIL || 'dev@seafoundry.com';
const USER_ID = USER_EMAIL.toLowerCase();

async function checkUserAndOrg() {
  console.log('='.repeat(60));
  console.log('Checking Firestore for: ' + USER_EMAIL);
  console.log('='.repeat(60));

  // Check user document
  console.log('\n📋 User Document Check:');
  const userDoc = await db.collection('users').doc(USER_ID).get();
  if (userDoc.exists) {
    const data = userDoc.data();
    console.log('  ✅ User document EXISTS');
    console.log('  - ID: ' + userDoc.id);
    console.log('  - Email: ' + (data.email || 'N/A'));
    console.log('  - Name: ' + (data.name || 'N/A'));
    console.log('  - OrganizationId: ' + (data.organizationId || 'N/A'));
    console.log('  - CreatedAt: ' + (data.createdAt || 'N/A'));
  } else {
    console.log('  ❌ User document DOES NOT EXIST');
  }

  // Check organizations created by this user
  console.log('\n📋 Organizations Created By User:');
  let foundOrgs = false;

  // Try lowercase
  const orgsSnapshot = await db.collection('organizations')
    .where('createdById', '==', USER_ID)
    .get();

  if (!orgsSnapshot.empty) {
    foundOrgs = true;
    orgsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log('  ✅ Organization EXISTS: ' + doc.id);
      console.log('    - Name: ' + (data.name || 'N/A'));
      console.log('    - Domain: ' + (data.domain || 'N/A'));
    });
  }

  // Try original case if different
  if (USER_ID !== USER_EMAIL) {
    const orgsSnapshot2 = await db.collection('organizations')
      .where('createdById', '==', USER_EMAIL)
      .get();
    if (!orgsSnapshot2.empty) {
      foundOrgs = true;
      orgsSnapshot2.forEach(doc => {
        const data = doc.data();
        console.log('  ✅ Organization EXISTS: ' + doc.id);
        console.log('    - Name: ' + (data.name || 'N/A'));
        console.log('    - Domain: ' + (data.domain || 'N/A'));
      });
    }
  }

  if (!foundOrgs) {
    console.log('  ❌ No organizations found created by this user');
  }

  // If user has organizationId, check that org too
  if (userDoc.exists && userDoc.data().organizationId) {
    const orgId = userDoc.data().organizationId;
    if (orgId !== USER_ID && orgId !== USER_EMAIL) {
      console.log('\n📋 User\'s Current Organization (' + orgId + '):');
      const orgDoc = await db.collection('organizations').doc(orgId).get();
      if (orgDoc.exists) {
        const data = orgDoc.data();
        console.log('  ✅ Organization EXISTS');
        console.log('    - Name: ' + (data.name || 'N/A'));
      } else {
        console.log('  ⚠️  Organization DOES NOT EXIST (stale reference)');
        console.log('    User needs reset - organizationId points to deleted org');
      }
    } else {
      console.log('\n📋 User\'s OrganizationId = their email (pre-onboarding state)');
    }
  }

  console.log('\n' + '='.repeat(60));

  // Return status for automation
  return {
    userExists: userDoc.exists,
    userOrgId: userDoc.exists ? userDoc.data().organizationId : null,
  };
}

checkUserAndOrg()
  .then(result => {
    console.log('\n🔍 Summary:');
    console.log('  User exists: ' + result.userExists);
    console.log('  User organizationId: ' + (result.userOrgId || 'none'));
    process.exit(0);
  })
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
