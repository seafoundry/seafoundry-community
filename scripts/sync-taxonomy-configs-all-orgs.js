#!/usr/bin/env node

/**
 * Syncs taxonomy configs for all organizations in the system.
 * 
 * This script:
 * 1. Fetches all organization IDs from Firestore
 * 2. Runs the taxonomy config sync script (which syncs global defaults)
 * 
 * Usage:
 *   node scripts/sync-taxonomy-configs-all-orgs.js [--updatedBy=<userId>]
 *   npm run sync:taxonomy-configs:all-orgs -- --updatedBy=<userId>
 */

const { db } = require('./config');
const { syncTaxonomyConfigs } = require('./sync_taxonomy_configs');

// Parse command line arguments
const args = process.argv.slice(2);
let updatedBy = null;
let dryRun = false;
for (const arg of args) {
  if (arg.startsWith('--updatedBy=')) {
    updatedBy = arg.split('=')[1];
  } else if (arg === '--dry-run') {
    dryRun = true;
  }
}

async function syncTaxonomyConfigsForAllOrgs() {
  try {
    console.log('🌊 Syncing taxonomy configs for all organizations...\n');

    // Fetch all organizations
    console.log('📋 Fetching all organizations from Firestore...');
    const orgsSnapshot = await db.collection('organizations').get();
    
    if (orgsSnapshot.empty) {
      console.log('⚠️  No organizations found in Firestore.');
      console.log('   The sync will still run to update global taxonomy defaults.\n');
    } else {
      const orgIds = orgsSnapshot.docs.map(doc => doc.id);
      const orgNames = orgsSnapshot.docs.map(doc => doc.data().name || doc.id);
      
      console.log(`✅ Found ${orgIds.length} organization(s):`);
      orgIds.forEach((id, index) => {
        console.log(`   ${index + 1}. ${orgNames[index]} (${id})`);
      });
      console.log('');
    }

    const user = updatedBy || process.env.USER || process.env.USERNAME || 'cli_sync';
    console.log('🔄 Running taxonomy config sync via Firebase Admin...\n');
    await syncTaxonomyConfigs({ updatedBy: user, dryRun });

    console.log('\n✨ Done! Taxonomy configs synced for all organizations.');
    console.log('   Note: Taxonomy configs are global defaults shared across all orgs.');

  } catch (error) {
    console.error('\n❌ Error syncing taxonomy configs:', error.message);
    process.exit(1);
  }
}

// Run the script
syncTaxonomyConfigsForAllOrgs();










