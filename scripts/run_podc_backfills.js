#!/usr/bin/env node

/**
 * Convenience runner for the recurring Pod C backfills:
 *   1. Taxonomy species search tokens
 *   2. Override history timestamps
 *
 * Usage:
 *   node scripts/run_podc_backfills.js [--dry-run] [additional args...]
 * Examples:
 *   node scripts/run_podc_backfills.js --dry-run
 *   node scripts/run_podc_backfills.js --org my-org-id --force
 */

const { execSync } = require('child_process');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const forwardedArgs = args.filter((arg) => arg !== '--dry-run');

const sharedArgs = [
  dryRun ? '--dry-run' : null,
  forwardedArgs.join(' '),
]
    .filter(Boolean)
    .join(' ')
    .trim();

const scripts = [
  {
    label: 'Taxonomy species search tokens',
    command: `node scripts/backfill_taxonomy_species_search_tokens.js ${sharedArgs}`.trim(),
  },
  {
    label: 'Override history timestamps',
    command: `node scripts/backfill_override_history_timestamps.js ${sharedArgs}`.trim(),
  },
];

function run() {
  console.log('🌊 Running Pod C backfill bundle\n');
  scripts.forEach((script, index) => {
    console.log(`${index + 1}. ${script.label}`);
    console.log(`   Command: ${script.command || '(no args)'}`);
    console.log('   --------------------------------------------------');
    try {
      execSync(script.command, { stdio: 'inherit', cwd: process.cwd() });
    } catch (error) {
      console.error(`\n❌ ${script.label} failed.`);
      process.exit(error.status ?? 1);
    }
    console.log('');
  });

  console.log(
    `✨ Pod C backfills complete (${dryRun ? 'dry-run' : 'live'} mode).`,
  );
}

run();
