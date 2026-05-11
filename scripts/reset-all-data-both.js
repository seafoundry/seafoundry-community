#!/usr/bin/env node
/**
 * Wrapper to reset both production and emulator.
 *
 * Usage:
 *   node scripts/reset-all-data-both.js --execute
 *
 * Options are forwarded to scripts/reset-all-data.js
 *   --execute
 *   --keep-auth-users
 *   --force, --yes
 *   --batch-size=500
 *   --verbose, -v
 *   --help, -h
 */

const { spawnSync } = require('child_process');
const path = require('path');

const args = process.argv.slice(2);
const help = args.includes('--help') || args.includes('-h');

if (help) {
  console.log(`
🔄 SeaFoundry Full Data Reset (Production + Emulator)

Runs scripts/reset-all-data.js for both production and emulator.

Usage:
  node scripts/reset-all-data-both.js --execute

Options:
  --execute                      Actually perform deletions (default is dry run)
  --keep-auth-users              Skip deleting Auth users
  --force, --yes                 Skip interactive confirmations
  --batch-size=500               Firestore batch size
  --verbose, -v                  Verbose logging
  --help, -h                     Show this help message
`);
  process.exit(0);
}

const scriptPath = path.join(__dirname, 'reset-all-data.js');
const forwardedArgs = args.filter((arg) => !arg.startsWith('--target='));

const targets = ['production', 'emulator'];

for (const target of targets) {
  console.log(`\n=== Reset target: ${target} ===\n`);
  const result = spawnSync(
    process.execPath,
    [scriptPath, `--target=${target}`, ...forwardedArgs],
    { stdio: 'inherit' },
  );

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}
