#!/usr/bin/env node

/**
 * SeaFoundry Firestore migration script
 * -------------------------------------
 * Converts legacy `event_death` / `death` inventory events into the unified
 * `event_population_loss` format while preserving metadata for rollback.
 *
 * Usage:
 *   node scripts/migrate-death-to-population-loss.js [options]
 *
 * Options:
 *   --dry-run, -d           Preview the migration without writing changes
 *   --rollback, -r          Restore previously migrated events
 *   --limit, -l <number>    Limit the number of documents processed
 *   --batch-size <number>   Write batch size (default: 400, max 500)
 *   --verbose, -v           Print each processed document id
 *   --force, -f             Skip interactive confirmation
 *   --backup, -b            Write processed documents to backups/ as JSON
 *   --help, -h              Show detailed usage
 */

const path = require('path');
const fs = require('fs').promises;
const readline = require('readline');
const { db, admin } = require('./config-json');

const LEGACY_EVENT_TYPES = ['event_death', 'death'];
const TARGET_EVENT_TYPE_ID = 'event_population_loss';
const MORTALITY_REASON_ID = 'population_loss_reason_mortality';
const MIGRATION_FIELD = 'migrationDeath';
const DEFAULT_BATCH_SIZE = 400;

const args = process.argv.slice(2);
const options = {
  dryRun: false,
  rollback: false,
  verbose: false,
  force: false,
  backup: false,
  limit: null,
  batchSize: DEFAULT_BATCH_SIZE,
};

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  switch (arg) {
    case '--dry-run':
    case '-d':
      options.dryRun = true;
      break;
    case '--rollback':
    case '-r':
      options.rollback = true;
      break;
    case '--verbose':
    case '-v':
      options.verbose = true;
      break;
    case '--force':
    case '-f':
      options.force = true;
      break;
    case '--backup':
    case '-b':
      options.backup = true;
      break;
    case '--limit':
    case '-l': {
      const value = parseInt(args[i + 1], 10);
      if (Number.isNaN(value) || value <= 0) {
        console.error('❌ Invalid --limit value. Must be a positive integer.');
        process.exit(1);
      }
      options.limit = value;
      i += 1;
      break;
    }
    case '--batch-size': {
      const value = parseInt(args[i + 1], 10);
      if (Number.isNaN(value) || value <= 0 || value > 500) {
        console.error('❌ Invalid --batch-size. Must be between 1 and 500.');
        process.exit(1);
      }
      options.batchSize = value;
      i += 1;
      break;
    }
    case '--help':
    case '-h':
      showHelp();
      process.exit(0);
      break;
    default:
      console.error(`❌ Unknown option: ${arg}`);
      showHelp();
      process.exit(1);
  }
}

if (options.rollback && options.dryRun) {
  console.log('ℹ️  Running rollback in dry-run mode');
}

async function promptConfirmation(message) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(`${message} (y/N): `, (answer) => {
      rl.close();
      resolve(['y', 'yes'].includes(answer.trim().toLowerCase()));
    });
  });
}

function showHelp() {
  console.log(`
🔄 SeaFoundry Migration: death → population loss

Converts legacy "death" inventory events to the modern population loss model.
Stores original values under the "${MIGRATION_FIELD}" map for rollback.

Usage:
  node scripts/migrate-death-to-population-loss.js [options]

Options:
  --dry-run, -d           Preview updates without writing to Firestore
  --rollback, -r          Restore events that were previously migrated
  --limit, -l <number>    Limit number of documents processed
  --batch-size <number>   Write batch size (default: ${DEFAULT_BATCH_SIZE}, max 500)
  --verbose, -v           Print each processed document id
  --force, -f             Skip confirmation prompts
  --backup, -b            Save processed documents to backups/
  --help, -h              Show this message
`);
}

async function fetchDocuments() {
  const fieldName = options.rollback ? `${MIGRATION_FIELD}.eventTypeId` : 'eventTypeId';
  const valueLabel = options.rollback ? 'rollback' : 'forward';
  const results = [];

  for (const legacyValue of LEGACY_EVENT_TYPES) {
    if (options.limit && results.length >= options.limit) break;

    let query = db.collection('events').where(fieldName, '==', legacyValue);
    if (options.limit) {
      query = query.limit(options.limit - results.length);
    }

    const snapshot = await query.get();
    if (snapshot.empty) continue;

    for (const doc of snapshot.docs) {
      results.push(doc);
      if (options.verbose) {
        console.log(`  • ${valueLabel} candidate: ${doc.id}`);
      }
      if (options.limit && results.length >= options.limit) {
        break;
      }
    }
  }

  return results;
}

function buildForwardUpdate(doc) {
  const data = doc.data();
  const migrationPayload = {
    eventTypeId: data.eventTypeId,
    lossReasonId: Object.prototype.hasOwnProperty.call(data, 'lossReasonId')
      ? data.lossReasonId
      : null,
    migratedAt: new Date().toISOString(),
    version: 1,
  };

  const nextLossReasonId = data.lossReasonId || MORTALITY_REASON_ID;

  return {
    eventTypeId: TARGET_EVENT_TYPE_ID,
    lossReasonId: nextLossReasonId,
    [MIGRATION_FIELD]: migrationPayload,
  };
}

function buildRollbackUpdate(doc) {
  const data = doc.data();
  const migration = data[MIGRATION_FIELD];
  if (!migration) {
    return null;
  }

  const rollback = {
    eventTypeId: migration.eventTypeId,
    [MIGRATION_FIELD]: admin.firestore.FieldValue.delete(),
  };

  if (migration.lossReasonId === null || typeof migration.lossReasonId === 'undefined') {
    rollback.lossReasonId = admin.firestore.FieldValue.delete();
  } else {
    rollback.lossReasonId = migration.lossReasonId;
  }

  return rollback;
}

async function createBackup(docs) {
  if (!docs.length) return null;
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.join(process.cwd(), 'backups');
  await fs.mkdir(backupDir, { recursive: true });
  const backupFile = path.join(backupDir, `death_to_population_loss_${timestamp}.json`);

  const payload = docs.map((doc) => ({ id: doc.id, data: doc.data() }));
  await fs.writeFile(backupFile, JSON.stringify(payload, null, 2));
  console.log(`💾 Backup saved to ${backupFile}`);
  return backupFile;
}

async function applyUpdates(updates) {
  if (!updates.length) return;

  let batch = db.batch();
  let batchCount = 0;

  for (let i = 0; i < updates.length; i += 1) {
    const { ref, data } = updates[i];
    batch.update(ref, data);
    batchCount += 1;

    if (batchCount === options.batchSize || i === updates.length - 1) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }
}

async function main() {
  console.log(options.rollback
    ? '↩️  Running rollback: population loss → death'
    : '➡️  Running migration: death → population loss');

  const docs = await fetchDocuments();
  if (!docs.length) {
    console.log('✅ No matching documents found. Nothing to do.');
    return;
  }

  console.log(`📄 Found ${docs.length} document(s) to process`);

  if (!options.force && !options.dryRun) {
    const confirm = await promptConfirmation('Proceed with Firestore updates?');
    if (!confirm) {
      console.log('⚠️  Operation cancelled.');
      return;
    }
  }

  if (options.backup) {
    await createBackup(docs);
  }

  const updates = [];
  for (const doc of docs) {
    const payload = options.rollback ? buildRollbackUpdate(doc) : buildForwardUpdate(doc);
    if (!payload) continue;
    updates.push({ ref: doc.ref, data: payload });
  }

  if (!updates.length) {
    console.log('⚠️  No documents required updates after filtering.');
    return;
  }

  if (options.dryRun) {
    console.log(`📝 Dry run complete – ${updates.length} document(s) would be updated.`);
    return;
  }

  await applyUpdates(updates);
  console.log(`✅ Successfully ${options.rollback ? 'restored' : 'updated'} ${updates.length} document(s).`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  });
