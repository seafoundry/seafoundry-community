#!/usr/bin/env node

/**
 * Demo Setup Verification Script
 *
 * Verifies that demo data has been properly seeded for the specified tier.
 * Use this after running seed-demo.js to confirm everything is set up correctly.
 *
 * NOTE: Production DB must be wiped/reset after Data Field Unification (SOT)
 * to ensure all data uses canonical fields.
 *
 * Usage:
 *   node scripts/verify-demo-setup.js --org=ORG_ID
 *   node scripts/verify-demo-setup.js --org=ORG_ID --tier=community
 *   node scripts/verify-demo-setup.js --org=ORG_ID --tier=pro --verbose
 *
 * Options:
 *   --org=ORG_ID           Organization ID to verify (required)
 *   --tier=TIER            Expected tier (community|pro|scale) for validation
 *   --verbose, -v          Show detailed counts
 *   --help, -h             Show this help message
 */

require('dotenv').config();
const { admin, db } = require('./config-json');

const args = process.argv.slice(2);

function argValue(prefix) {
  const match = args.find((arg) => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

function hasFlag(flag) {
  return args.includes(flag);
}

const options = {
  orgId: argValue('--org'),
  tier: argValue('--tier'),
  verbose: hasFlag('--verbose') || hasFlag('-v'),
  help: hasFlag('--help') || hasFlag('-h'),
};

if (options.help) {
  console.log(`
🔍 Demo Setup Verification Script

Verifies that demo data has been properly seeded.

Usage: node scripts/verify-demo-setup.js --org=ORG_ID [options]

Options:
  --org=ORG_ID           Organization ID to verify (required)
  --tier=TIER            Expected tier (community|pro|scale) for validation
  --verbose, -v          Show detailed counts
  --help, -h             Show this help message

Examples:
  # Verify a seeded organization
  node scripts/verify-demo-setup.js --org=my-demo-org

  # Verify with expected tier and verbose output
  node scripts/verify-demo-setup.js --org=my-demo-org --tier=pro --verbose
`);
  process.exit(0);
}

if (!options.orgId) {
  console.error('❌ Missing required --org parameter');
  console.error('Usage: node scripts/verify-demo-setup.js --org=ORG_ID');
  process.exit(1);
}

// Verification checks
const checks = {
  passed: 0,
  failed: 0,
  warnings: 0,
};

function pass(message) {
  checks.passed++;
  console.log(`  ✅ ${message}`);
}

function fail(message) {
  checks.failed++;
  console.log(`  ❌ ${message}`);
}

function warn(message) {
  checks.warnings++;
  console.log(`  ⚠️  ${message}`);
}

function info(message) {
  console.log(`  ℹ️  ${message}`);
}

async function countCollection(path) {
  try {
    const snapshot = await db.collection(path).get();
    return snapshot.size;
  } catch (e) {
    return 0;
  }
}

async function countOrgSubcollection(orgId, subcollection) {
  const orgRef = db.collection('organizations').doc(orgId);
  try {
    const snapshot = await orgRef.collection(subcollection).get();
    return snapshot.size;
  } catch (e) {
    return 0;
  }
}

async function countOrgScopedRootDocs(collectionName, orgId) {
  try {
    const snapshot = await db
      .collection(collectionName)
      .where('organizationId', '==', orgId)
      .get();
    return snapshot.size;
  } catch (e) {
    return 0;
  }
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║          Demo Setup Verification Script                        ║');
  console.log('╚════════════════════════════════════════════════════════════════╝');
  console.log(`\nVerifying organization: ${options.orgId}`);
  if (options.tier) {
    console.log(`Expected tier: ${options.tier}`);
  }
  console.log('');

  try {
    // 1. Check organization exists
    console.log('📋 Organization Check:');
    const orgRef = db.collection('organizations').doc(options.orgId);
    const orgSnap = await orgRef.get();

    if (!orgSnap.exists) {
      fail(`Organization "${options.orgId}" not found`);
      console.log('\n❌ Verification failed: Organization does not exist');
      process.exit(1);
    }

    const orgData = orgSnap.data();
    pass(`Organization exists: ${orgData.name || options.orgId}`);

    // Check tier
    const actualTier = orgData.tier || orgData.metadata?.tier || 'community';
    if (options.tier) {
      if (actualTier === options.tier) {
        pass(`Tier matches expected: ${actualTier}`);
      } else {
        fail(`Tier mismatch: expected ${options.tier}, got ${actualTier}`);
      }
    } else {
      info(`Organization tier: ${actualTier}`);
    }

    // Check isDemo flag
    if (orgData.metadata?.isDemo === true) {
      pass('Demo flag is set');
    } else {
      warn('Demo flag not set (metadata.isDemo)');
    }

    // 2. Check members
    console.log('\n👥 Members Check:');
    const membersCount = await countOrgSubcollection(options.orgId, 'members');
    if (membersCount > 0) {
      pass(`Found ${membersCount} member(s)`);
    } else {
      fail('No members found');
    }

    // 3. Check users
    console.log('\n👤 Users Check:');
    const usersCount = await countOrgScopedRootDocs('users', options.orgId);
    if (usersCount > 0) {
      pass(`Found ${usersCount} user document(s)`);
    } else {
      fail('No user documents found');
    }

    // 4. Check inventory data
    console.log('\n📦 Inventory Check:');

    const sitesCount = await countOrgScopedRootDocs('sites', options.orgId);
    if (sitesCount > 0) {
      pass(`Found ${sitesCount} site(s)`);
    } else {
      warn('No sites found (inventory seeding may have been skipped)');
    }

    const groupsCount = await countOrgSubcollection(options.orgId, 'groups');
    if (groupsCount > 0) {
      pass(`Found ${groupsCount} group(s)`);
    } else if (sitesCount > 0) {
      warn('No groups found (unexpected if sites exist)');
    } else {
      info('No groups found (expected if no sites)');
    }

    const genetsCount = await countOrgSubcollection(options.orgId, 'genets');
    if (genetsCount > 0) {
      pass(`Found ${genetsCount} genet(s)`);
    } else if (sitesCount > 0) {
      warn('No genets found (unexpected if sites exist)');
    } else {
      info('No genets found (expected if no sites)');
    }

    const organismsCount = await countOrgSubcollection(options.orgId, 'organismRecords');
    if (organismsCount > 0) {
      pass(`Found ${organismsCount} organism record(s)`);
    } else if (sitesCount > 0) {
      warn('No organism records found (unexpected if sites exist)');
    } else {
      info('No organism records found (expected if no sites)');
    }

    // 5. Check events
    console.log('\n📅 Events Check:');
    const eventsCount = await countOrgScopedRootDocs('events', options.orgId);
    if (eventsCount > 0) {
      pass(`Found ${eventsCount} event(s)`);

      if (options.verbose) {
        // Count by event type
        const eventsSnap = await db
          .collection('events')
          .where('organizationId', '==', options.orgId)
          .get();

        const byType = {};
        eventsSnap.docs.forEach((doc) => {
          const type = doc.data().eventTypeId || 'unknown';
          byType[type] = (byType[type] || 0) + 1;
        });

        console.log('    Events by type:');
        for (const [type, count] of Object.entries(byType).sort((a, b) => b[1] - a[1])) {
          console.log(`      - ${type}: ${count}`);
        }
      }
    } else if (sitesCount > 0) {
      warn('No events found (unexpected if inventory exists)');
    } else {
      info('No events found (expected if no inventory)');
    }

    // 6. Check taxonomy (global)
    console.log('\n🧬 Taxonomy Check:');
    const speciesCount = await countCollection('taxonomy_species');
    if (speciesCount > 0) {
      pass(`Found ${speciesCount} taxonomy species`);
    } else {
      fail('No taxonomy species found (run npm run seed:taxonomy first)');
    }

    // 7. Check PID counters
    console.log('\n🔢 PID Counters Check:');
    const pidCount = await countCollection('provenanceIds');
    if (pidCount > 0) {
      pass(`Found ${pidCount} PID counter(s)`);

      if (options.verbose) {
        const pidSnap = await db.collection('provenanceIds').get();
        console.log('    PID counters:');
        pidSnap.docs.forEach((doc) => {
          const data = doc.data();
          console.log(`      - ${doc.id}: next = ${data.next || 0}`);
        });
      }
    } else {
      info('No PID counters found (will be created on first genet creation)');
    }

    // 8. Check CRC/Historical data (optional)
    if (options.verbose) {
      console.log('\n📊 Historical/CRC Data Check:');
      const historicalCollections = [
        'historical_impact_points',
        'historical_outplant_events',
        'historical_reef_aggregates',
        'provenance_crosswalk',
      ];

      for (const col of historicalCollections) {
        const count = await countCollection(col);
        if (count > 0) {
          info(`${col}: ${count} documents`);
        }
      }
    }

    // Summary
    console.log('\n╔════════════════════════════════════════════════════════════════╗');
    console.log('║                      VERIFICATION SUMMARY                      ║');
    console.log('╚════════════════════════════════════════════════════════════════╝');
    console.log(`\n  Passed:   ${checks.passed}`);
    console.log(`  Failed:   ${checks.failed}`);
    console.log(`  Warnings: ${checks.warnings}`);

    if (checks.failed > 0) {
      console.log('\n❌ Verification FAILED - some checks did not pass');
      console.log('\nTo fix:');
      console.log(`  1. Run: node scripts/seed-demo.js --reset --org=${options.orgId} --user=YOUR_EMAIL --tier=${options.tier || 'pro'}`);
      console.log('  2. If taxonomy is missing: npm run seed:taxonomy');
      process.exit(1);
    } else if (checks.warnings > 0) {
      console.log('\n⚠️  Verification PASSED with warnings');
      process.exit(0);
    } else {
      console.log('\n✅ Verification PASSED - demo setup looks good!');
      process.exit(0);
    }
  } catch (error) {
    console.error('\n❌ Verification failed with error:', error.message);
    if (options.verbose) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();
