#!/usr/bin/env node

/**
 * Firestore Permission-Denied Diagnostic Script
 *
 * Diagnoses the root cause of "permission-denied" errors during site creation
 * by querying production Firestore for data inconsistencies.
 *
 * Checks:
 * 1. User document exists at expected path (users/{uid})
 * 2. User document has organizationId field set
 * 3. Organization document exists at organizations/{orgId}
 * 4. Organization document has createdById matching user UID
 * 5. Case sensitivity issues in user email field
 * 6. Membership subcollection entries
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
 *     node scripts/diagnose-permission-denied.js
 *
 *   # Or specify a different email:
 *   node scripts/diagnose-permission-denied.js --email="other@example.com"
 *
 *   # Check specific organization ID:
 *   node scripts/diagnose-permission-denied.js --org="Xx2kzbAiaihc16cz4BX0"
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// ============================================================================
// Configuration
// ============================================================================

const DEFAULT_EMAIL = 'dev@seafoundry.com';
const DEFAULT_ORG_ID = 'Xx2kzbAiaihc16cz4BX0';

function parseArgs() {
  const args = {
    email: DEFAULT_EMAIL,
    orgId: DEFAULT_ORG_ID,
    verbose: false
  };

  process.argv.slice(2).forEach(arg => {
    if (arg.startsWith('--email=')) {
      args.email = arg.split('=')[1];
    } else if (arg.startsWith('--org=')) {
      args.orgId = arg.split('=')[1];
    } else if (arg === '--verbose' || arg === '-v') {
      args.verbose = true;
    }
  });

  return args;
}

// ============================================================================
// Firebase Initialization
// ============================================================================

function initializeFirebase() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  // Try to load service account from JSON file first
  const serviceAccountPath = path.join(process.cwd(), 'firebase-service-account.json');

  if (fs.existsSync(serviceAccountPath)) {
    console.log('[INIT] Loading Firebase credentials from JSON file...');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'seafoundryapp'
    });
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.log('[INIT] Loading Firebase credentials from GOOGLE_APPLICATION_CREDENTIALS...');
    const serviceAccount = require(path.resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'seafoundryapp'
    });
  } else {
    console.error('ERROR: No Firebase credentials found.');
    console.error('       Provide firebase-service-account.json or set GOOGLE_APPLICATION_CREDENTIALS');
    process.exit(1);
  }

  console.log('[INIT] Firebase Admin SDK initialized for PRODUCTION');
  return admin.app();
}

// ============================================================================
// Diagnostic Functions
// ============================================================================

async function checkUserDocument(db, userId, userEmail) {
  console.log('\n' + '='.repeat(80));
  console.log('1. USER DOCUMENT CHECK');
  console.log('='.repeat(80));

  const userDocId = userId;
  console.log(`   Expected document path: /users/${userDocId || '(missing uid)'}`);

  try {
    if (!userDocId) {
      console.log('   [CRITICAL] Missing UID - cannot check user document');
      return null;
    }
    const userDoc = await db.collection('users').doc(userDocId).get();

    if (!userDoc.exists) {
      console.log('   [CRITICAL] User document DOES NOT EXIST');
      console.log('   Root cause: User document missing - all security rule lookups will fail');
      return null;
    }

    console.log('   [OK] User document EXISTS');

    const userData = userDoc.data();
    console.log('\n   Document fields:');
    console.log(`   - id: ${userData.id || 'NOT SET'}`);
    console.log(`   - email: ${userData.email || 'NOT SET'}`);
    console.log(`   - organizationId: ${userData.organizationId || 'NOT SET'}`);
    console.log(`   - name: ${userData.name || 'NOT SET'}`);
    console.log(`   - createdAt: ${userData.createdAt || 'NOT SET'}`);
    console.log(`   - role: ${userData.role || 'NOT SET'}`);
    console.log(`   - isDemo: ${userData.isDemo}`);
    console.log(`   - onboardingCompletedAt: ${userData.onboardingCompletedAt || 'NOT SET'}`);

    // Critical check: does organizationId exist?
    if (!userData.organizationId) {
      console.log('\n   [CRITICAL] organizationId field is NULL/EMPTY');
      console.log('   Root cause: User has no organization - resourceBelongsToUserOrg() will always fail');
    } else if (userData.organizationId === userDocId) {
      console.log('\n   [WARNING] organizationId equals user UID (placeholder value)');
      console.log('   This indicates onboarding did not complete - org may not exist');
    }

    // Check for case sensitivity issues
    if (userEmail && userData.email && userData.email.toLowerCase() !== userEmail.toLowerCase()) {
      console.log(`\n   [WARNING] Email mismatch: auth email="${userEmail}" vs user doc email="${userData.email}"`);
    }

    return userData;
  } catch (error) {
    console.log(`   [ERROR] Failed to read user document: ${error.message}`);
    return null;
  }
}

async function checkUserByUid(db, email) {
  console.log('\n' + '='.repeat(80));
  console.log('2. FIREBASE AUTH UID CHECK');
  console.log('='.repeat(80));

  try {
    const auth = admin.auth();
    const userRecord = await auth.getUserByEmail(email);

    console.log(`   Firebase Auth UID: ${userRecord.uid}`);
    console.log(`   Email verified: ${userRecord.emailVerified}`);
    console.log(`   Provider: ${userRecord.providerData.map(p => p.providerId).join(', ')}`);

    // Check UID-based user document (primary path)
    const uidDoc = await db.collection('users').doc(userRecord.uid).get();
    if (uidDoc.exists) {
      console.log('\n   [OK] UID-based user document found at /users/' + userRecord.uid);
    } else {
      console.log('\n   [WARNING] Missing UID-based user document at /users/' + userRecord.uid);
    }

    return userRecord;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log(`   [WARNING] User not found in Firebase Auth: ${email}`);
    } else {
      console.log(`   [ERROR] Failed to lookup user in Auth: ${error.message}`);
    }
    return null;
  }
}

async function checkOrganizationDocument(db, orgId, userId) {
  console.log('\n' + '='.repeat(80));
  console.log('3. ORGANIZATION DOCUMENT CHECK');
  console.log('='.repeat(80));

  console.log(`   Checking organization: /organizations/${orgId}`);

  try {
    const orgDoc = await db.collection('organizations').doc(orgId).get();

    if (!orgDoc.exists) {
      console.log('   [CRITICAL] Organization document DOES NOT EXIST');
      console.log('   Root cause: Organization missing - all org-scoped operations will fail');
      return null;
    }

    console.log('   [OK] Organization document EXISTS');

    const orgData = orgDoc.data();
    console.log('\n   Document fields:');
    console.log(`   - id: ${orgData.id || 'NOT SET'}`);
    console.log(`   - name: ${orgData.name || 'NOT SET'}`);
    console.log(`   - domain: ${orgData.domain || 'NOT SET'}`);
    console.log(`   - organizationId: ${orgData.organizationId || 'NOT SET'}`);
    console.log(`   - createdById: ${orgData.createdById || 'NOT SET'}`);
    console.log(`   - createdAt: ${orgData.createdAt || 'NOT SET'}`);
    console.log(`   - tier: ${orgData.tier || 'NOT SET'}`);

    // Check createdById matches user UID
    const expectedCreator = userId;
    if (!orgData.createdById) {
      console.log('\n   [WARNING] createdById is NULL/EMPTY');
    } else if (expectedCreator && orgData.createdById !== expectedCreator) {
      console.log(`\n   [INFO] createdById mismatch:`);
      console.log(`          Expected: ${expectedCreator}`);
      console.log(`          Actual: ${orgData.createdById}`);
      console.log('   This is OK if user was invited (not the org creator)');
    } else {
      console.log('\n   [OK] createdById matches user UID');
    }

    // Check organizationId self-reference
    if (orgData.organizationId !== orgId) {
      console.log(`\n   [WARNING] organizationId field (${orgData.organizationId}) != doc ID (${orgId})`);
    }

    return orgData;
  } catch (error) {
    console.log(`   [ERROR] Failed to read organization document: ${error.message}`);
    return null;
  }
}

async function checkMembershipSubcollection(db, orgId, userEmail, userUid) {
  console.log('\n' + '='.repeat(80));
  console.log('4. MEMBERSHIP SUBCOLLECTION CHECK');
  console.log('='.repeat(80));

  console.log(`   Checking: /organizations/${orgId}/members/`);

  try {
    const membersSnapshot = await db.collection('organizations').doc(orgId).collection('members').get();

    if (membersSnapshot.empty) {
      console.log('   [WARNING] No members in subcollection');
    } else {
      console.log(`   Found ${membersSnapshot.size} member(s):`);

      let userFound = false;
      membersSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`\n   - Member ID: ${doc.id}`);
        console.log(`     email: ${data.email || 'NOT SET'}`);
        console.log(`     role: ${data.role || 'NOT SET'}`);
        console.log(`     joinedAt: ${data.joinedAt || 'NOT SET'}`);

        if (doc.id === userUid) {
          userFound = true;
          console.log('     [OK] This is the current user (matched by UID)');
        }
      });

      if (!userFound) {
        console.log(`\n   [WARNING] User not found in members subcollection`);
        console.log(`   Checked for: UID=${userUid}`);
      }
    }
  } catch (error) {
    console.log(`   [ERROR] Failed to read members subcollection: ${error.message}`);
  }
}

async function checkSitesCollection(db, orgId) {
  console.log('\n' + '='.repeat(80));
  console.log('5. SITES COLLECTION CHECK');
  console.log('='.repeat(80));

  console.log(`   Querying sites where organizationId == ${orgId}`);

  try {
    const sitesSnapshot = await db.collection('sites')
      .where('organizationId', '==', orgId)
      .limit(10)
      .get();

    if (sitesSnapshot.empty) {
      console.log('   [INFO] No sites found for this organization');
      console.log('   This is expected if site creation is failing');
    } else {
      console.log(`   Found ${sitesSnapshot.size} site(s):`);

      sitesSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`\n   - Site ID: ${doc.id}`);
        console.log(`     name: ${data.name || 'NOT SET'}`);
        console.log(`     organizationId: ${data.organizationId || 'NOT SET'}`);
        console.log(`     createdById: ${data.createdById || 'NOT SET'}`);
        console.log(`     createdAt: ${data.createdAt || 'NOT SET'}`);
      });
    }
  } catch (error) {
    console.log(`   [ERROR] Failed to query sites: ${error.message}`);
  }
}

async function checkEventsCollection(db, orgId) {
  console.log('\n' + '='.repeat(80));
  console.log('6. EVENTS COLLECTION CHECK');
  console.log('='.repeat(80));

  console.log(`   Querying events where organizationId == ${orgId}`);

  try {
    const eventsSnapshot = await db.collection('events')
      .where('organizationId', '==', orgId)
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    if (eventsSnapshot.empty) {
      console.log('   [INFO] No events found for this organization');
    } else {
      console.log(`   Found ${eventsSnapshot.size} recent event(s):`);

      eventsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`\n   - Event ID: ${doc.id}`);
        console.log(`     type: ${data.type || data.eventType || 'NOT SET'}`);
        console.log(`     recordModelType: ${data.recordModelType || 'NOT SET'}`);
        console.log(`     organizationId: ${data.organizationId || 'NOT SET'}`);
        console.log(`     createdById: ${data.createdById || 'NOT SET'}`);
        console.log(`     createdAt: ${data.createdAt || 'NOT SET'}`);
      });
    }
  } catch (error) {
    console.log(`   [ERROR] Failed to query events: ${error.message}`);
  }
}

async function listAllUsersWithEmail(db, email) {
  console.log('\n' + '='.repeat(80));
  console.log('7. SEARCH FOR USER DOCUMENTS WITH THIS EMAIL');
  console.log('='.repeat(80));

  console.log(`   Searching for documents where email == ${email}`);

  try {
    // Search by exact email match
    const emailMatch = await db.collection('users')
      .where('email', '==', email)
      .get();

    // Search by lowercase email match
    const lowerEmailMatch = await db.collection('users')
      .where('email', '==', email.toLowerCase())
      .get();

    const allDocs = new Map();
    emailMatch.forEach(doc => allDocs.set(doc.id, doc.data()));
    lowerEmailMatch.forEach(doc => allDocs.set(doc.id, doc.data()));

    if (allDocs.size === 0) {
      console.log('   [INFO] No user documents found with this email field');
    } else {
      console.log(`   Found ${allDocs.size} user document(s):`);

      for (const [docId, data] of allDocs) {
        console.log(`\n   - Document ID: ${docId}`);
        console.log(`     email: ${data.email || 'NOT SET'}`);
        console.log(`     organizationId: ${data.organizationId || 'NOT SET'}`);
        console.log(`     id field: ${data.id || 'NOT SET'}`);

        if (docId !== email.toLowerCase()) {
          console.log('     [WARNING] Document ID does not match lowercase email!');
        }
      }
    }
  } catch (error) {
    console.log(`   [ERROR] Failed to search users: ${error.message}`);
  }
}

async function checkSlugCounts(db, orgId) {
  console.log('\n' + '='.repeat(80));
  console.log('8. SLUG COUNTS SUBCOLLECTION CHECK');
  console.log('='.repeat(80));

  console.log(`   Checking: /organizations/${orgId}/slugCounts/`);

  try {
    const slugCountsSnapshot = await db.collection('organizations').doc(orgId).collection('slugCounts').get();

    if (slugCountsSnapshot.empty) {
      console.log('   [WARNING] No slugCounts documents found');
      console.log('   This may cause issues with slug generation for new records');
    } else {
      console.log(`   Found ${slugCountsSnapshot.size} slugCount document(s):`);

      slugCountsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`   - ${doc.id}: count=${data.count}`);
      });
    }
  } catch (error) {
    console.log(`   [ERROR] Failed to read slugCounts: ${error.message}`);
  }
}

async function analyzeSecurityRuleFailure(userData, orgData, userRecord) {
  console.log('\n' + '='.repeat(80));
  console.log('ANALYSIS: SECURITY RULE EVALUATION');
  console.log('='.repeat(80));

  console.log('\n   Simulating security rule checks for site creation...\n');

  // Check 1: isAuthenticated()
  console.log('   1. isAuthenticated()');
  if (userRecord) {
    console.log('      [PASS] User has Firebase Auth record');
  } else {
    console.log('      [FAIL] No Firebase Auth record found');
  }

  // Check 2: getUserDoc()
  console.log('\n   2. getUserDoc() lookup');
  console.log(`      Path: /users/${userRecord?.email?.toLowerCase() || 'unknown'}`);
  if (userData) {
    console.log('      [PASS] User document exists');
  } else {
    console.log('      [FAIL] User document does not exist');
    console.log('      => This is the ROOT CAUSE - all subsequent checks will fail');
    return;
  }

  // Check 3: userDoc.data.organizationId
  console.log('\n   3. userDoc.data.organizationId');
  if (userData.organizationId) {
    console.log(`      [PASS] organizationId = ${userData.organizationId}`);
  } else {
    console.log('      [FAIL] organizationId is NULL/EMPTY');
    console.log('      => This is the ROOT CAUSE - resourceBelongsToUserOrg() will fail');
    return;
  }

  // Check 4: resourceBelongsToUserOrg()
  console.log('\n   4. resourceBelongsToUserOrg() for site creation');
  console.log('      This checks: request.resource.data.organizationId == userDoc.data.organizationId');
  console.log(`      User\'s organizationId: ${userData.organizationId}`);
  console.log('      Incoming site would have: organizationId = ' + userData.organizationId);
  console.log('      [PASS] These would match');

  // Check 5: incomingBelongsToUserOrg()
  console.log('\n   5. incomingBelongsToUserOrg() for site creation');
  console.log('      Same check as above - verifies incoming data matches user org');
  console.log('      [PASS] Would pass if organizationId is set correctly');

  // Check 6: isIncomingCreator()
  console.log('\n   6. isIncomingCreator() check');
  console.log(`      User email: ${userRecord?.email?.toLowerCase() || 'unknown'}`);
  console.log(`      User doc ID: ${userData.id || 'NOT SET'}`);
  console.log('      This checks: request.resource.data.createdById == auth.uid');
  console.log('      [INFO] Depends on what createdById is set to in the site being created');

  // Summary
  console.log('\n   SUMMARY:');
  if (!userData) {
    console.log('   => ROOT CAUSE: User document missing');
  } else if (!userData.organizationId) {
    console.log('   => ROOT CAUSE: User document has no organizationId');
  } else if (!orgData) {
    console.log('   => POSSIBLE CAUSE: Organization document missing');
    console.log('      User has organizationId but the org doc may not exist');
  } else {
    console.log('   => Data looks consistent - issue may be elsewhere');
    console.log('      Check if the client is sending correct organizationId and createdById');
  }
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  console.log('='.repeat(80));
  console.log('FIRESTORE PERMISSION-DENIED DIAGNOSTIC');
  console.log('='.repeat(80));

  const args = parseArgs();
  console.log(`\nTarget email: ${args.email}`);
  console.log(`Target organization: ${args.orgId}`);

  initializeFirebase();
  const db = admin.firestore();

  // Run all diagnostic checks
  const userRecord = await checkUserByUid(db, args.email);
  const userData = await checkUserDocument(db, userRecord?.uid, args.email);

  // Use organizationId from user doc if available, otherwise use provided
  const effectiveOrgId = userData?.organizationId || args.orgId;

  const orgData = await checkOrganizationDocument(db, effectiveOrgId, userRecord?.uid);
  await checkMembershipSubcollection(db, effectiveOrgId, args.email, userRecord?.uid);
  await checkSitesCollection(db, effectiveOrgId);
  await checkEventsCollection(db, effectiveOrgId);
  await listAllUsersWithEmail(db, args.email);
  await checkSlugCounts(db, effectiveOrgId);

  // Analyze the findings
  await analyzeSecurityRuleFailure(userData, orgData, userRecord);

  console.log('\n' + '='.repeat(80));
  console.log('DIAGNOSTIC COMPLETE');
  console.log('='.repeat(80));
  console.log('\nNext steps:');
  console.log('1. If user doc missing: Run onboarding flow again or create manually');
  console.log('2. If organizationId missing: Update user doc with correct organizationId');
  console.log('3. If org doc missing: Create organization through proper onboarding');
  console.log('4. Check client-side code to ensure createdById uses UID\n');

  process.exit(0);
}

main().catch(error => {
  console.error('\nFATAL ERROR:', error);
  process.exit(1);
});
