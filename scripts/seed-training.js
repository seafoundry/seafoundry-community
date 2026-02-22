#!/usr/bin/env node

/**
 * Seed training SOPs + media from config/seed_data/training.
 *
 * Usage:
 *   node scripts/seed-training.js [--overwrite] [--clear] [--clear-only]
 */

require('dotenv').config();

const TrainingSeeder = require('./seeders/training-seeder');

const args = process.argv.slice(2);
const overwrite = args.includes('--overwrite') || args.includes('-o');
const shouldClear = args.includes('--clear') || args.includes('-c');
const clearOnly = args.includes('--clear-only');

async function main() {
  try {
    const seeder = new TrainingSeeder();
    if (shouldClear) {
      await seeder.clear({ overwrite });
    }
    if (!clearOnly) {
      await seeder.seed({ overwrite });
    }
    console.log('OK: Training seeding complete.');
  } catch (error) {
    console.error('ERROR: Training seeding failed:', error.message || error);
    process.exit(1);
  }
}

main();
