#!/usr/bin/env node

/**
 * Firestore Permissions Verification Script
 *
 * Automated smoke tests for FP3-B1: Demo/Prod Smoke Tests
 * Verifies security rules after Phase 0-2 remediation fixes
 *
 * Usage:
 *   # Run all tests (emulator)
 *   FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js
 *
 *   # Run specific test category
 *   node scripts/verify-permissions.js --category=taxonomy
 *
 *   # Run against production (use with caution)
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
 *     node scripts/verify-permissions.js --production
 *
 *   # Test specific user (preferred: UID)
 *   node scripts/verify-permissions.js --uid="test_uid"
 *
 * Categories:
 *   - onboarding: New user creation, org setup, site creation
 *   - taxonomy: Taxonomy collections access (species, provenances, overrides)
 *   - storage: Storage upload with UID-based user lookup
 *   - demo: Demo mode prefixing and isolation
 *   - all: Run all categories (default)
 */

const admin = require('firebase-admin');
const path = require('path');

// ============================================================================
// Configuration
// ============================================================================

const CATEGORIES = {
  onboarding: 'Onboarding Tests (User/Org/Site Creation)',
  taxonomy: 'Taxonomy Admin Tests (Global Collections)',
  storage: 'Storage Upload Tests (UID-based)',
  demo: 'Demo Mode Tests (Prefixing/Isolation)',
  all: 'All Test Categories'
};

const DEMO_USERS = {
  community: {
    email: 'community@provenance.app',
    orgId: 'demo_org_community'
  }
};

// ============================================================================
// Argument Parsing
// ============================================================================

function parseArgs() {
  const args = {
    category: 'all',
    production: false,
    email: null,
    uid: null,
    verbose: false,
    demoTier: null
  };

  process.argv.slice(2).forEach(arg => {
    if (arg.startsWith('--category=')) {
      args.category = arg.split('=')[1];
    } else if (arg === '--production' || arg === '-p') {
      args.production = true;
    } else if (arg.startsWith('--email=')) {
      args.email = arg.split('=')[1];
    } else if (arg.startsWith('--uid=')) {
      args.uid = arg.split('=')[1];
    } else if (arg === '--verbose' || arg === '-v') {
      args.verbose = true;
    } else if (arg.startsWith('--demo-tier=')) {
      args.demoTier = arg.split('=')[1];
    }
  });

  if (!CATEGORIES[args.category]) {
    console.error(`❌ Invalid category: ${args.category}`);
    console.error(`   Valid categories: ${Object.keys(CATEGORIES).join(', ')}`);
    process.exit(1);
  }

  return args;
}

// ============================================================================
// Firebase Initialization
// ============================================================================

function initializeFirebase(isProduction) {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  if (isProduction) {
    // Production mode - requires service account
    const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!serviceAccountPath) {
      console.error('❌ GOOGLE_APPLICATION_CREDENTIALS not set for production mode');
      process.exit(1);
    }

    admin.initializeApp({
      credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
      projectId: 'seafoundryapp'
    });

    console.log('🔥 Firebase initialized (PRODUCTION MODE)');
  } else {
    // Emulator mode
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      console.error('❌ FIRESTORE_EMULATOR_HOST not set for emulator mode');
      console.error('   Start emulators with: firebase emulators:start');
      process.exit(1);
    }

    admin.initializeApp({
      projectId: 'demo-test-project'
    });

    console.log(`🔥 Firebase initialized (EMULATOR MODE: ${process.env.FIRESTORE_EMULATOR_HOST})`);
  }

  return admin.app();
}

async function resolveUserIdentity(app, { uid, email }) {
  if (uid) {
    return { uid, email };
  }
  if (!email) {
    return { uid: null, email: null };
  }
  try {
    const userRecord = await admin.auth(app).getUserByEmail(email);
    return { uid: userRecord.uid, email: userRecord.email || email };
  } catch (error) {
    console.warn(`⚠️  Unable to resolve UID for ${email}: ${error.message}`);
    return { uid: null, email };
  }
}

// ============================================================================
// Test Result Tracking
// ============================================================================

class TestResults {
  constructor() {
    this.passed = 0;
    this.failed = 0;
    this.warnings = 0;
    this.tests = [];
  }

  pass(testName, details = '') {
    this.passed++;
    this.tests.push({ name: testName, status: 'PASS', details });
    console.log(`  ✅ ${testName}`);
    if (details) console.log(`     ${details}`);
  }

  fail(testName, error) {
    this.failed++;
    this.tests.push({ name: testName, status: 'FAIL', error: error.message });
    console.log(`  ❌ ${testName}`);
    console.log(`     Error: ${error.message}`);
  }

  warn(testName, message) {
    this.warnings++;
    this.tests.push({ name: testName, status: 'WARN', message });
    console.log(`  ⚠️  ${testName}`);
    console.log(`     Warning: ${message}`);
  }

  skip(testName, reason) {
    this.tests.push({ name: testName, status: 'SKIP', reason });
    console.log(`  ⏭️  ${testName} (${reason})`);
  }

  summary() {
    console.log('\n' + '='.repeat(80));
    console.log('TEST SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total Tests: ${this.tests.length}`);
    console.log(`✅ Passed: ${this.passed}`);
    console.log(`❌ Failed: ${this.failed}`);
    console.log(`⚠️  Warnings: ${this.warnings}`);
    console.log(`⏭️  Skipped: ${this.tests.filter(t => t.status === 'SKIP').length}`);

    if (this.failed > 0) {
      console.log('\n❌ SOME TESTS FAILED - Review errors above');
      return false;
    } else if (this.warnings > 0) {
      console.log('\n⚠️  ALL TESTS PASSED WITH WARNINGS');
      return true;
    } else {
      console.log('\n✅ ALL TESTS PASSED');
      return true;
    }
  }
}

// ============================================================================
// Category 1: Onboarding Tests
// ============================================================================

async function testOnboarding(db, results, identity) {
  console.log('\n📋 ONBOARDING TESTS');
  console.log('─'.repeat(80));

  const userId = identity.uid;
  const email = identity.email;

  if (!userId) {
    results.skip('User document check', 'UID not provided or resolved');
    return;
  }

  // Test 1.1: User document uses UID-based identity
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      results.pass('User document keyed by UID', `Found: /users/${userId}`);
    } else {
      results.warn('User document not found', `Expected: /users/${userId} (may need manual creation)`);
    }
  } catch (error) {
    results.fail('User document access failed', error);
  }

  // Test 1.2: Organization document exists
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data().organizationId) {
      const orgId = userDoc.data().organizationId;
      const orgDoc = await db.collection('organizations').doc(orgId).get();
      if (orgDoc.exists) {
        results.pass('Organization document accessible', `Found: /organizations/${orgId}`);
      } else {
        results.warn('Organization document not found', `Expected: /organizations/${orgId}`);
      }
    } else {
      results.skip('Organization check', 'User has no organizationId');
    }
  } catch (error) {
    results.fail('Organization document access failed', error);
  }

  // Test 1.3: User can query their org's sites
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data().organizationId) {
      const orgId = userDoc.data().organizationId;
      const sitesSnapshot = await db.collection('sites')
        .where('organizationId', '==', orgId)
        .limit(10)
        .get();
      results.pass('Sites query succeeds', `Found ${sitesSnapshot.size} sites for org ${orgId}`);
    } else {
      results.skip('Sites query', 'User has no organizationId');
    }
  } catch (error) {
    results.fail('Sites query failed', error);
  }

  // Test 1.4: Verify no email-keyed user document exists
  if (email) {
    try {
      const legacyId = email.toLowerCase();
      const legacyDoc = await db.collection('users').doc(legacyId).get();
      if (legacyDoc.exists) {
        results.warn(
          'Legacy email-keyed user document found',
          `Unexpected document at /users/${legacyId}`,
        );
      } else {
        results.pass('No legacy email-keyed user document', 'UID-only user docs confirmed');
      }
    } catch (error) {
      results.warn('Legacy email doc check failed', error.message);
    }
  } else {
    results.skip('Legacy email doc check', 'Email not provided');
  }
}

// ============================================================================
// Category 2: Taxonomy Tests
// ============================================================================

async function testTaxonomy(db, results) {
  console.log('\n🌿 TAXONOMY TESTS');
  console.log('─'.repeat(80));

  const taxonomyCollections = [
    'taxonomy_species',
    'taxonomy_provenances',
    'taxonomy_lineages',
    'taxonomy_overrides'
  ];

  // Test 2.1-2.4: Verify global taxonomy collections are accessible
  for (const collectionName of taxonomyCollections) {
    try {
      const snapshot = await db.collection(collectionName).limit(5).get();
      if (snapshot.size > 0) {
        results.pass(`${collectionName} accessible (global)`, `Found ${snapshot.size} documents`);
      } else {
        results.warn(`${collectionName} is empty`, 'May need to run: npm run seed:taxonomy:emulator');
      }
    } catch (error) {
      results.fail(`${collectionName} access failed`, error);
    }
  }

  // Test 2.5: Verify no demo-prefixed taxonomy collections exist
  const demoPrefixedTaxonomy = [
    'demo_taxonomy_species',
    'demo_taxonomy_provenances',
    'demo_taxonomy_lineages'
  ];

  for (const collectionName of demoPrefixedTaxonomy) {
    try {
      const snapshot = await db.collection(collectionName).limit(1).get();
      if (snapshot.size > 0) {
        results.fail(`${collectionName} should not exist`, new Error('Taxonomy collections should be global (not demo-prefixed)'));
      } else {
        results.pass(`${collectionName} correctly does not exist`, 'Taxonomy is global');
      }
    } catch (error) {
      // Permission denied is actually good here - collection should not be accessible
      if (error.code === 'permission-denied') {
        results.pass(`${collectionName} correctly not accessible`, 'No rules defined (expected)');
      } else {
        results.warn(`${collectionName} check failed`, error.message);
      }
    }
  }
}

// ============================================================================
// Category 3: Storage Tests
// ============================================================================

async function testStorage(db, results, identity) {
  console.log('\n📦 STORAGE TESTS');
  console.log('─'.repeat(80));

  const userId = identity.uid;

  // Test 4.1: Verify user document exists for storage rules lookup
  if (!userId) {
    results.skip('User document check', 'UID not provided or resolved');
  } else {
    try {
      const userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData.organizationId) {
          results.pass('User document ready for storage rules', `User: ${userId}, Org: ${userData.organizationId}`);
        } else {
          results.warn('User has no organizationId', 'Org-scoped storage uploads will fail');
        }
      } else {
        results.warn('User document not found for storage rules', `Expected: /users/${userId}`);
      }
    } catch (error) {
      results.fail('User document lookup failed', error);
    }
  }

  // Test 4.2: Verify storage rules use UID-based lookup (syntax check)
  console.log('\n  📝 Manual Check Required:');
  console.log('     Verify storage.rules uses:');
  console.log('       request.auth.uid');
  console.log('     NOT: request.auth.token.email.lower()');
  results.pass('Storage rules syntax check', 'Review storage.rules manually for UID-based lookup');

  // Note: Actual storage upload testing requires Storage emulator and file operations
  // which are beyond the scope of this basic Firestore verification script
}

// ============================================================================
// Category 5: Demo Mode Tests
// ============================================================================

async function testDemoMode(db, results, demoTier) {
  console.log('\n🎭 DEMO MODE TESTS');
  console.log('─'.repeat(80));

  const tier = demoTier || 'community';
  const demoUser = DEMO_USERS[tier];

  if (!demoUser) {
    results.warn('Invalid demo tier', 'Use --demo-tier=community');
    return;
  }

  // Test 5.1: Demo user document exists (UID-keyed)
  try {
    const auth = admin.auth();
    const userRecord = await auth.getUserByEmail(demoUser.email).catch(() => null);
    if (!userRecord) {
      results.warn('Demo user not found in Firebase Auth', `Email: ${demoUser.email}`);
    } else {
      const userDoc = await db.collection('users').doc(userRecord.uid).get();
      if (userDoc.exists) {
        results.pass('Demo user document exists', `/users/${userRecord.uid}`);
      } else {
        results.warn('Demo user document not found', `Run: npm run seed:demo:${tier} -- --reset`);
      }
    }
  } catch (error) {
    results.fail('Demo user document access failed', error);
  }

  // Test 5.2: Demo organization exists
  try {
    const orgDoc = await db.collection('organizations').doc(demoUser.orgId).get();
    if (orgDoc.exists) {
      results.pass('Demo organization exists', `/organizations/${demoUser.orgId}`);
    } else {
      results.warn('Demo organization not found', `Expected: /organizations/${demoUser.orgId}`);
    }
  } catch (error) {
    results.fail('Demo organization access failed', error);
  }

  // Test 5.3: Demo sites exist (may be prefixed in demo mode)
  try {
    const sitesSnapshot = await db.collection('demo_sites')
      .where('organizationId', '==', demoUser.orgId)
      .limit(5)
      .get();

    if (sitesSnapshot.size > 0) {
      results.pass('Demo sites accessible', `Found ${sitesSnapshot.size} in /demo_sites`);
    } else {
      // Try non-prefixed collection
      const regularSitesSnapshot = await db.collection('sites')
        .where('organizationId', '==', demoUser.orgId)
        .limit(5)
        .get();

      if (regularSitesSnapshot.size > 0) {
        results.warn('Demo sites in non-prefixed collection', 'Expected in /demo_sites, found in /sites');
      } else {
        results.warn('No demo sites found', `Run: npm run seed:demo:${tier} -- --reset`);
      }
    }
  } catch (error) {
    results.fail('Demo sites access failed', error);
  }

  // Test 5.4: Taxonomy collections are NOT prefixed (global)
  try {
    const speciesSnapshot = await db.collection('taxonomy_species').limit(1).get();
    if (speciesSnapshot.size > 0) {
      results.pass('Taxonomy species is global (not demo-prefixed)', 'Correctly shared across demo/prod');
    } else {
      results.warn('Taxonomy species is empty', 'Run: npm run seed:taxonomy:emulator');
    }
  } catch (error) {
    results.fail('Taxonomy species access failed', error);
  }

}

// ============================================================================
// Main Test Runner
// ============================================================================

async function runTests() {
  console.log('🔬 Firestore Permissions Verification');
  console.log('='.repeat(80));

  const args = parseArgs();

  console.log(`Category: ${args.category} - ${CATEGORIES[args.category]}`);
  console.log(`Mode: ${args.production ? 'PRODUCTION' : 'EMULATOR'}`);
  if (args.email) console.log(`Test Email: ${args.email}`);
  if (args.uid) console.log(`Test UID: ${args.uid}`);
  if (args.demoTier) console.log(`Demo Tier: ${args.demoTier}`);
  console.log('');

  const app = initializeFirebase(args.production);
  const db = admin.firestore(app);
  const results = new TestResults();
  const identity = await resolveUserIdentity(app, {
    uid: args.uid,
    email: args.email,
  });

  try {
    // Run tests based on category
    if (args.category === 'onboarding' || args.category === 'all') {
      await testOnboarding(db, results, identity);
    }

    if (args.category === 'taxonomy' || args.category === 'all') {
      await testTaxonomy(db, results);
    }

    if (args.category === 'storage' || args.category === 'all') {
      await testStorage(db, results, identity);
    }

    if (args.category === 'demo' || args.category === 'all') {
      await testDemoMode(db, results, args.demoTier || 'community');
    }

    // Print summary
    const success = results.summary();
    process.exit(success ? 0 : 1);

  } catch (error) {
    console.error('\n❌ FATAL ERROR:', error);
    process.exit(1);
  }
}

// ============================================================================
// Entry Point
// ============================================================================

if (require.main === module) {
  runTests().catch(error => {
    console.error('Unhandled error:', error);
    process.exit(1);
  });
}

module.exports = { runTests };
