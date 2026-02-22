#!/usr/bin/env node

/**
 * Repair Demo Users Script
 *
 * Checks all provenance.app demo accounts for data consistency and repairs
 * any missing Firestore documents (user docs, org memberships).
 *
 * Usage:
 *   # Dry run (check only, no changes)
 *   node scripts/repair-demo-users.js
 *
 *   # Actually repair missing data
 *   node scripts/repair-demo-users.js --fix
 *
 *   # Check specific tier only
 *   node scripts/repair-demo-users.js --tier=pro
 *   node scripts/repair-demo-users.js --tier=pro --fix
 */

require('dotenv').config();
const { admin, db } = require('./config-json');

const args = process.argv.slice(2);
const FIX_MODE = args.includes('--fix');
const TIER_FILTER = args.find(a => a.startsWith('--tier='))?.split('=')[1];

// Demo account configurations matching seed-demo.js
const DEMO_ACCOUNTS = {
  community: {
    orgId: 'demo_org_community',
    orgName: 'DEMO-COMMUNITY',
    users: [
      { email: 'community@provenance.app', name: 'Demo Admin', role: 'owner' },
      { email: 'community1@provenance.app', name: 'Alex Rivera', role: 'member' },
    ],
    allowedActivities: [],
    tier: 'community',
  },
  pro: {
    orgId: 'demo_org_pro',
    orgName: 'DEMO-PRO',
    users: [
      { email: 'pro@provenance.app', name: 'Demo Admin', role: 'owner' },
      { email: 'pro1@provenance.app', name: 'Alex Rivera', role: 'member' },
      { email: 'pro2@provenance.app', name: 'Jordan Chen', role: 'member' },
      { email: 'pro3@provenance.app', name: 'Sam Okonkwo', role: 'member' },
      { email: 'pro4@provenance.app', name: 'Riley Thompson', role: 'member' },
      { email: 'pro5@provenance.app', name: 'Morgan Lee', role: 'member' },
      { email: 'pro6@provenance.app', name: 'Casey Johnson', role: 'member' },
      { email: 'pro7@provenance.app', name: 'Drew Williams', role: 'member' },
      { email: 'pro8@provenance.app', name: 'Quinn Martinez', role: 'member' },
      { email: 'pro9@provenance.app', name: 'Avery Davis', role: 'member' },
    ],
    allowedActivities: ['husbandry', 'observation', 'comment'],
    tier: 'pro',
  },
  scale: {
    orgId: 'demo_org_scale',
    orgName: 'DEMO-SCALE',
    users: [
      { email: 'scale@provenance.app', name: 'Demo Admin', role: 'owner' },
      { email: 'scale1@provenance.app', name: 'Alex Rivera', role: 'member' },
      { email: 'scale2@provenance.app', name: 'Jordan Chen', role: 'member' },
      { email: 'scale3@provenance.app', name: 'Sam Okonkwo', role: 'member' },
      { email: 'scale4@provenance.app', name: 'Riley Thompson', role: 'member' },
      { email: 'scale5@provenance.app', name: 'Morgan Lee', role: 'member' },
      { email: 'scale6@provenance.app', name: 'Casey Johnson', role: 'member' },
      { email: 'scale7@provenance.app', name: 'Drew Williams', role: 'member' },
      { email: 'scale8@provenance.app', name: 'Quinn Martinez', role: 'member' },
      { email: 'scale9@provenance.app', name: 'Avery Davis', role: 'member' },
    ],
    allowedActivities: ['task', 'husbandry', 'observation', 'comment'],
    tier: 'scale',
  },
};

// Track issues found
const issues = [];
const repairs = [];

async function checkAuthUser(email) {
  try {
    const user = await admin.auth().getUserByEmail(email);
    return { exists: true, uid: user.uid, displayName: user.displayName };
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return { exists: false, uid: null };
    }
    throw error;
  }
}

async function checkUserDoc(uid) {
  const doc = await db.collection('users').doc(uid).get();
  return {
    exists: doc.exists,
    data: doc.exists ? doc.data() : null,
  };
}

async function checkMembership(orgId, uid) {
  const doc = await db.collection('organizations').doc(orgId)
    .collection('members').doc(uid).get();
  return {
    exists: doc.exists,
    data: doc.exists ? doc.data() : null,
  };
}

async function checkOrganization(orgId) {
  const doc = await db.collection('organizations').doc(orgId).get();
  return {
    exists: doc.exists,
    data: doc.exists ? doc.data() : null,
  };
}

async function repairUserDoc(uid, userConfig, orgId) {
  const now = new Date().toISOString();
  const userData = {
    id: uid,
    name: userConfig.name,
    email: userConfig.email.toLowerCase(),
    role: userConfig.role,
    organizationId: orgId,
    tagline: userConfig.role === 'owner' ? 'Organization Admin' : 'Team Member',
    modelType: 'user',
    createdAt: now,
    createdById: uid,
    updatedAt: now,
    updatedById: uid,
    onboardingCompletedAt: now,
    metadata: {
      isDemo: true,
      hasCompletedTour: true,
    },
  };

  if (FIX_MODE) {
    await db.collection('users').doc(uid).set(userData, { merge: true });
    repairs.push(`Created user doc for ${userConfig.email} (${uid})`);
    console.log(`  ✅ REPAIRED: Created user doc for ${userConfig.email}`);
  } else {
    console.log(`  🔧 WOULD CREATE: User doc for ${userConfig.email} (${uid})`);
  }
}

async function repairMembership(uid, userConfig, orgId) {
  const now = new Date().toISOString();
  const memberData = {
    uid: uid,
    memberId: uid,
    email: userConfig.email.toLowerCase(),
    role: userConfig.role,
    organizationId: orgId,
    createdById: uid,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
  };

  if (FIX_MODE) {
    await db.collection('organizations').doc(orgId)
      .collection('members').doc(uid).set(memberData, { merge: true });
    repairs.push(`Created membership for ${userConfig.email} in ${orgId}`);
    console.log(`  ✅ REPAIRED: Created membership for ${userConfig.email}`);
  } else {
    console.log(`  🔧 WOULD CREATE: Membership for ${userConfig.email} in ${orgId}`);
  }
}

async function repairOrganization(orgId, tierConfig) {
  const now = new Date().toISOString();
  const orgData = {
    id: orgId,
    name: tierConfig.orgName,
    slug: orgId,
    tier: tierConfig.tier,
    allowedActivities: tierConfig.allowedActivities,
    modelType: 'organization',
    createdAt: now,
    updatedAt: now,
    metadata: {
      isDemo: true,
    },
  };

  if (FIX_MODE) {
    await db.collection('organizations').doc(orgId).set(orgData, { merge: true });
    repairs.push(`Created organization ${orgId}`);
    console.log(`  ✅ REPAIRED: Created organization ${orgId}`);
  } else {
    console.log(`  🔧 WOULD CREATE: Organization ${orgId}`);
  }
}

async function checkTier(tierName, tierConfig) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Checking ${tierName.toUpperCase()} tier (${tierConfig.orgId})`);
  console.log('='.repeat(60));

  // Check organization exists
  const orgCheck = await checkOrganization(tierConfig.orgId);
  if (!orgCheck.exists) {
    issues.push(`Organization ${tierConfig.orgId} does not exist`);
    console.log(`❌ Organization ${tierConfig.orgId} does not exist`);
    await repairOrganization(tierConfig.orgId, tierConfig);
  } else {
    console.log(`✅ Organization ${tierConfig.orgId} exists`);
  }

  // Check each user
  for (const userConfig of tierConfig.users) {
    console.log(`\n  Checking ${userConfig.email}...`);

    // Check Firebase Auth
    const authCheck = await checkAuthUser(userConfig.email);
    if (!authCheck.exists) {
      issues.push(`Auth user ${userConfig.email} does not exist`);
      console.log(`  ❌ Auth user does not exist`);
      console.log(`     ⚠️  Cannot repair - Firebase Auth user must be created via seed-demo.js`);
      continue;
    }
    console.log(`  ✅ Auth user exists (uid: ${authCheck.uid})`);

    // Check Firestore user document
    const userDocCheck = await checkUserDoc(authCheck.uid);
    if (!userDocCheck.exists) {
      issues.push(`User doc missing for ${userConfig.email} (uid: ${authCheck.uid})`);
      console.log(`  ❌ User document missing in /users/${authCheck.uid}`);
      await repairUserDoc(authCheck.uid, userConfig, tierConfig.orgId);
    } else {
      // Check if organizationId matches
      const currentOrgId = userDocCheck.data?.organizationId;
      if (currentOrgId !== tierConfig.orgId) {
        issues.push(`User ${userConfig.email} has wrong orgId: ${currentOrgId} (expected: ${tierConfig.orgId})`);
        console.log(`  ⚠️  User doc has wrong organizationId: ${currentOrgId}`);
        if (FIX_MODE) {
          await db.collection('users').doc(authCheck.uid).update({
            organizationId: tierConfig.orgId,
            updatedAt: new Date().toISOString(),
          });
          repairs.push(`Fixed organizationId for ${userConfig.email}`);
          console.log(`  ✅ REPAIRED: Updated organizationId`);
        } else {
          console.log(`  🔧 WOULD FIX: Update organizationId to ${tierConfig.orgId}`);
        }
      } else {
        console.log(`  ✅ User document exists with correct organizationId`);
      }
    }

    // Check membership document
    const memberCheck = await checkMembership(tierConfig.orgId, authCheck.uid);
    if (!memberCheck.exists) {
      issues.push(`Membership missing for ${userConfig.email} in ${tierConfig.orgId}`);
      console.log(`  ❌ Membership document missing`);
      await repairMembership(authCheck.uid, userConfig, tierConfig.orgId);
    } else {
      console.log(`  ✅ Membership document exists`);
    }
  }
}

async function main() {
  console.log('\n🔍 Demo User Repair Script');
  console.log(`Mode: ${FIX_MODE ? '🔧 FIX (will make changes)' : '👀 DRY RUN (check only)'}`);
  if (TIER_FILTER) {
    console.log(`Filter: ${TIER_FILTER} tier only`);
  }
  console.log('');

  const tiersToCheck = TIER_FILTER
    ? { [TIER_FILTER]: DEMO_ACCOUNTS[TIER_FILTER] }
    : DEMO_ACCOUNTS;

  if (TIER_FILTER && !DEMO_ACCOUNTS[TIER_FILTER]) {
    console.error(`❌ Unknown tier: ${TIER_FILTER}`);
    console.error('   Valid tiers: community, pro, scale');
    process.exit(1);
  }

  for (const [tierName, tierConfig] of Object.entries(tiersToCheck)) {
    await checkTier(tierName, tierConfig);
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('SUMMARY');
  console.log('='.repeat(60));

  if (issues.length === 0) {
    console.log('\n✅ All demo accounts are healthy!');
  } else {
    console.log(`\n❌ Found ${issues.length} issue(s):`);
    issues.forEach((issue, i) => console.log(`   ${i + 1}. ${issue}`));
  }

  if (FIX_MODE && repairs.length > 0) {
    console.log(`\n🔧 Made ${repairs.length} repair(s):`);
    repairs.forEach((repair, i) => console.log(`   ${i + 1}. ${repair}`));
  } else if (!FIX_MODE && issues.length > 0) {
    console.log('\n💡 Run with --fix to repair these issues:');
    console.log('   node scripts/repair-demo-users.js --fix');
  }

  console.log('');
  process.exit(issues.length > 0 && !FIX_MODE ? 1 : 0);
}

main().catch((error) => {
  console.error('\n❌ Script failed:', error.message);
  console.error(error.stack);
  process.exit(1);
});
