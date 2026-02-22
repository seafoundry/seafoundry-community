#!/usr/bin/env node

/**
 * Fix missing createdById on demo organization documents.
 *
 * This script:
 * 1. Finds the specified organization document
 * 2. Checks if createdById is null or missing
 * 3. Gets the first admin member of the org
 * 4. Updates the organization's createdById to that member
 *
 * Usage:
 *   node scripts/fix-demo-org-creator.js --org=demo_org_pro
 *   node scripts/fix-demo-org-creator.js --org=demo_org_community
 */

require('dotenv').config();
const { db } = require('./config-json');

const args = process.argv.slice(2);

function argValue(prefix) {
  const match = args.find((arg) => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

async function main() {
  const orgId = argValue('--org');

  if (!orgId) {
    console.error('Usage: node scripts/fix-demo-org-creator.js --org=ORG_ID');
    console.error('Example: node scripts/fix-demo-org-creator.js --org=demo_org_pro');
    process.exit(1);
  }

  console.log(`INFO: Looking up organization ${orgId}...`);

  const orgRef = db.collection('organizations').doc(orgId);
  const orgSnap = await orgRef.get();

  if (!orgSnap.exists) {
    console.error(`ERROR: Organization ${orgId} not found.`);
    process.exit(1);
  }

  const orgData = orgSnap.data();
  console.log(`INFO: Found organization: ${orgData.name}`);
  console.log(`INFO: Current createdById: ${orgData.createdById || '(null)'}`);

  if (orgData.createdById) {
    console.log('INFO: Organization already has a createdById. Nothing to fix.');
    process.exit(0);
  }

  // Find members of the organization
  console.log('INFO: Looking for organization members...');
  const membersSnap = await orgRef.collection('members').get();

  if (membersSnap.empty) {
    console.error('ERROR: No members found for this organization.');
    console.error('TIP: Re-run the seeding script with --reset to regenerate the org.');
    process.exit(1);
  }

  // Look for an admin member first, then fall back to any member
  let creatorId = null;
  let creatorEmail = null;

  for (const doc of membersSnap.docs) {
    const member = doc.data();
    if (member.role === 'admin') {
      creatorId = doc.id;
      creatorEmail = member.email;
      break;
    }
    if (!creatorId) {
      creatorId = doc.id;
      creatorEmail = member.email;
    }
  }

  console.log(`INFO: Found ${membersSnap.size} member(s).`);
  console.log(`INFO: Will use member ${creatorId} (${creatorEmail}) as creator.`);

  // Update the organization
  const now = new Date().toISOString();
  await orgRef.update({
    createdById: creatorId,
    updatedAt: now,
  });

  console.log(`OK: Updated organization ${orgId} createdById to ${creatorId}`);
}

main().catch((error) => {
  console.error('ERROR:', error.message || error);
  process.exit(1);
});
