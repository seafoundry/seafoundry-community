#!/usr/bin/env node

/**
 * Backfill Membership Documents for Existing Users
 *
 * This script creates missing membership documents in /organizations/{orgId}/members/{uid}
 * for users who were created before the membership subcollection pattern was implemented.
 *
 * The Firestore security rules use isMemberByUid() which checks for these documents.
 * Without them, users get "permission denied" errors even in their own organization.
 *
 * Usage:
 *   # Dry run first (shows what would be created)
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
 *     node scripts/backfill-membership-docs.js --dry-run
 *
 *   # Execute (actually creates the documents)
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
 *     node scripts/backfill-membership-docs.js --execute
 *
 *   # For a specific organization only
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
 *     node scripts/backfill-membership-docs.js --execute --org=VTkDdPBIiZRJYKRAjS1m
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function initializeFirebase() {
  if (admin.apps.length > 0) return admin.app();

  // Try loading credentials from JSON file first
  const serviceAccountPath = path.join(process.cwd(), 'firebase-service-account.json');
  if (fs.existsSync(serviceAccountPath)) {
    console.log('Loading Firebase credentials from JSON file...');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id,
    });
    console.log(`Initialized for project: ${serviceAccount.project_id}`);
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.log('Using GOOGLE_APPLICATION_CREDENTIALS environment variable...');
    admin.initializeApp();
  } else {
    console.error('ERROR: No Firebase credentials found.');
    console.error('Either place firebase-service-account.json in project root');
    console.error('or set GOOGLE_APPLICATION_CREDENTIALS environment variable.');
    process.exit(1);
  }

  return admin.app();
}

async function backfillMembershipDocs(dryRun = true, specificOrgId = null) {
  const db = admin.firestore();
  const auth = admin.auth();
  const roleMap = {
    admin: 'admin',
    owner: 'admin',
    advanced_user: 'practitioner_plus',
    manager: 'practitioner_plus',
    editor: 'practitioner_plus',
    practitioner_plus: 'practitioner_plus',
    practitioner: 'practitioner',
    member: 'practitioner',
    user: 'practitioner',
    view_only: 'view_only',
    viewer: 'view_only',
    novice: 'view_only',
  };
  const normalizeRole = (role) => roleMap[`${role || ''}`.toLowerCase()] || 'practitioner';

  console.log('\n=== Backfill Membership Documents ===');
  console.log(`Mode: ${dryRun ? 'DRY RUN (no changes)' : 'EXECUTE (will create documents)'}`);
  if (specificOrgId) {
    console.log(`Target org: ${specificOrgId}`);
  }
  console.log('');

  // Get all users with an organizationId
  let usersQuery = db.collection('users').where('organizationId', '!=', '');
  const usersSnapshot = await usersQuery.get();

  console.log(`Found ${usersSnapshot.size} users with organizationId\n`);

  let created = 0;
  let skipped = 0;
  let alreadyExists = 0;
  let errors = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const email = userData.email || userDoc.id;
    const orgId = userData.organizationId;

    // Filter to specific org if requested
    if (specificOrgId && orgId !== specificOrgId) {
      continue;
    }

    // Skip users whose orgId equals their email (incomplete onboarding)
    if (orgId === email || orgId === userDoc.id) {
      console.log(`SKIP: ${email} - orgId is placeholder (${orgId})`);
      skipped++;
      continue;
    }

    // Skip demo orgs
    if (orgId.startsWith('demo_org_')) {
      console.log(`SKIP: ${email} - demo organization`);
      skipped++;
      continue;
    }

    try {
      // Get Firebase Auth UID for this user
      let authUser;
      try {
        authUser = await auth.getUserByEmail(email);
      } catch (authError) {
        if (authError.code === 'auth/user-not-found') {
          console.log(`SKIP: ${email} - no Firebase Auth record`);
          skipped++;
          continue;
        }
        throw authError;
      }

      const uid = authUser.uid;

      // Check if organization exists
      const orgDoc = await db.collection('organizations').doc(orgId).get();
      if (!orgDoc.exists) {
        console.log(`SKIP: ${email} - organization ${orgId} doesn't exist`);
        skipped++;
        continue;
      }

      // Check if membership doc already exists
      const membershipRef = db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid);

      const membershipDoc = await membershipRef.get();

      if (membershipDoc.exists) {
        console.log(`EXISTS: ${email} -> /organizations/${orgId}/members/${uid}`);
        alreadyExists++;
        continue;
      }

      // Determine role - check if user is the org creator/admin
      const orgData = orgDoc.data();
      const isAdmin =
        userData.createdById === uid ||
        orgData.createdById === uid ||
        userData.role === 'owner' ||
        userData.role === 'admin';

      const role = isAdmin ? 'admin' : normalizeRole(userData.role);

      const membershipData = {
        uid: uid,
        email: email.toLowerCase(),
        role: role,
        joinedAt: userData.createdAt || new Date().toISOString(),
        createdById: uid,
        organizationId: orgId,
        backfilledAt: new Date().toISOString(),
        backfillReason: 'Missing membership document for existing user',
      };

      if (dryRun) {
        console.log(`WOULD CREATE: /organizations/${orgId}/members/${uid}`);
        console.log(`  Email: ${email}, Role: ${role}`);
      } else {
        await membershipRef.set(membershipData);
        console.log(`CREATED: /organizations/${orgId}/members/${uid} (${email}, ${role})`);
      }

      created++;
    } catch (error) {
      console.log(`ERROR: ${email} - ${error.message}`);
      errors++;
    }
  }

  console.log('\n=== Summary ===');
  console.log(`Would create / Created: ${created}`);
  console.log(`Already exists: ${alreadyExists}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Errors: ${errors}`);

  if (dryRun && created > 0) {
    console.log('\nTo create these membership documents, run with --execute');
  }

  return { created, alreadyExists, skipped, errors };
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = !args.includes('--execute');
  const orgArg = args.find((a) => a.startsWith('--org='));
  const specificOrgId = orgArg ? orgArg.split('=')[1] : null;

  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Backfill Membership Documents

Usage:
  node scripts/backfill-membership-docs.js [options]

Options:
  --dry-run     Show what would be created without making changes (default)
  --execute     Actually create the membership documents
  --org=ID      Only process users in a specific organization
  --help, -h    Show this help message

Examples:
  # See what would be created
  GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \\
    node scripts/backfill-membership-docs.js --dry-run

  # Create membership docs for all users
  GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \\
    node scripts/backfill-membership-docs.js --execute

  # Create membership docs for specific org
  GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \\
    node scripts/backfill-membership-docs.js --execute --org=VTkDdPBIiZRJYKRAjS1m
`);
    process.exit(0);
  }

  initializeFirebase();
  await backfillMembershipDocs(dryRun, specificOrgId);
  process.exit(0);
}

main().catch((error) => {
  console.error('FATAL:', error);
  process.exit(1);
});
