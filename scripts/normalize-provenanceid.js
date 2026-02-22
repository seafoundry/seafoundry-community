#!/usr/bin/env node

/**
 * SeaFoundry Firestore migration script
 * -------------------------------------
 * NOTE: Production DB will be wiped after Data Field Unification (SOT).
 * This script may be re-run post-wipe if needed for imported data.
 *
 * Normalizes genet `provenanceId` identifiers into a canonical format:
 *     PID-{SPECIES_CODE}-{SEQUENCE}
 *
 * - SPECIES_CODE: derived from `speciesId` (uppercased alphanumeric)
 * - SEQUENCE: last numeric group found in provenanceId/doc id, padded to N digits
 *
 * The script stores the previous value under `provenanceIdNormalization` so that the
 * change can be rolled back later.
 */

const path = require('path');
const fs = require('fs').promises;
const readline = require('readline');
const { db, admin } = require('./config-json');

const DEFAULT_COLLECTION = 'genets';
const DEFAULT_TARGET_FIELD = 'provenanceId';
const DEFAULT_FALLBACK_FIELD = 'localId';
const DEFAULT_PADDING = 4;
const MIGRATION_FIELD = 'provenanceIdNormalization';
const DEFAULT_BATCH_SIZE = 400;

const args = process.argv.slice(2);
const options = {
  collection: DEFAULT_COLLECTION,
  targetField: DEFAULT_TARGET_FIELD,
  fallbackField: DEFAULT_FALLBACK_FIELD,
  padLength: DEFAULT_PADDING,
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
    case '--collection':
      options.collection = args[++i] || DEFAULT_COLLECTION;
      break;
    case '--target-field':
      options.targetField = args[++i] || DEFAULT_TARGET_FIELD;
      break;
    case '--fallback-field':
      options.fallbackField = args[++i] || DEFAULT_FALLBACK_FIELD;
      break;
    case '--pad':
      options.padLength = Math.max(1, parseInt(args[++i], 10) || DEFAULT_PADDING);
      break;
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
      const value = parseInt(args[++i], 10);
      if (Number.isNaN(value) || value <= 0) {
        console.error('❌ Invalid --limit value. Must be a positive integer.');
        process.exit(1);
      }
      options.limit = value;
      break;
    }
    case '--batch-size': {
      const value = parseInt(args[++i], 10);
      if (Number.isNaN(value) || value <= 0 || value > 500) {
        console.error('❌ Invalid --batch-size. Must be between 1 and 500.');
        process.exit(1);
      }
      options.batchSize = value;
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

function showHelp() {
  console.log(`
🔧 SeaFoundry Migration: provenanceId normalization

Normalizes genet provenance identifiers into the canonical "PID-{SPECIES}-{SEQUENCE}" format.
Stores previous values in the "${MIGRATION_FIELD}" map for rollback.

Usage:
  node scripts/normalize-provenanceid.js [options]

Options:
  --collection <name>      Firestore collection (default: ${DEFAULT_COLLECTION})
  --target-field <name>    Field to update (default: ${DEFAULT_TARGET_FIELD})
  --fallback-field <name>  Secondary field for deriving sequences (default: ${DEFAULT_FALLBACK_FIELD})
  --pad <digits>           Minimum digits for sequence padding (default: ${DEFAULT_PADDING})
  --dry-run, -d            Preview updates without writing
  --rollback, -r           Restore previous provenanceId values
  --limit, -l <number>     Limit number of documents processed
  --batch-size <number>    Write batch size (default: ${DEFAULT_BATCH_SIZE})
  --backup, -b             Save processed documents to backups/
  --verbose, -v            Print each processed document id
  --force, -f              Skip confirmation prompt
  --help, -h               Show this message
`);
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

function sanitizeSpeciesCode(speciesId) {
  if (!speciesId) return 'UNK';
  const cleaned = speciesId.toString().trim().replace(/[^A-Za-z0-9]/g, '').toUpperCase();
  return cleaned || 'UNK';
}

function extractSequence(data, docId) {
  const candidates = [];
  if (data.provenanceId) candidates.push(data.provenanceId);
  if (data.provenance_id) candidates.push(data.provenance_id);
  if (options.fallbackField && data[options.fallbackField]) {
    candidates.push(data[options.fallbackField]);
  }
  if (data.createdEvent?.provenanceId) {
    candidates.push(data.createdEvent.provenanceId);
  }
  if (docId) candidates.push(docId);
  if (data.slug) candidates.push(data.slug);

  for (const value of candidates) {
    if (!value || typeof value !== 'string') continue;
    const numbers = value.match(/(\d+)/g);
    if (numbers && numbers.length) {
      return numbers[numbers.length - 1];
    }
  }

  if (typeof data.sequenceNumber === 'number') {
    return Math.abs(data.sequenceNumber).toString();
  }

  return '0';
}

function padSequence(sequence, padLength) {
  return sequence.padStart(padLength, '0');
}

function buildNormalizedValue(doc) {
  const data = doc.data();
  const speciesId = data.speciesId || data.createdEvent?.speciesId;
  const speciesCode = sanitizeSpeciesCode(speciesId);
  const rawSequence = extractSequence(data, doc.id);
  const normalizedSequence = padSequence(rawSequence, options.padLength);
  return `PID-${speciesCode}-${normalizedSequence}`;
}

async function fetchDocuments() {
  const results = [];

  if (options.rollback) {
    let query = db.collection(options.collection).where(`${MIGRATION_FIELD}.version`, '==', 1);
    if (options.limit) {
      query = query.limit(options.limit);
    }
    const snapshot = await query.get();
    results.push(...snapshot.docs);
    return results;
  }

  let query = db.collection(options.collection);
  if (options.limit) {
    query = query.limit(options.limit);
  }
  const snapshot = await query.get();
  results.push(...snapshot.docs);
  return results;
}

function buildForwardUpdate(doc) {
  const data = doc.data();
  const normalized = buildNormalizedValue(doc);
  const currentValue = data[options.targetField];

  if (currentValue === normalized) {
    return null;
  }

  const migrationInfo = data[MIGRATION_FIELD];
  const previousValue = migrationInfo?.previousValue ?? (
    Object.prototype.hasOwnProperty.call(data, options.targetField)
      ? currentValue
      : null
  );

  return {
    [options.targetField]: normalized,
    [MIGRATION_FIELD]: {
      previousValue,
      version: migrationInfo?.version ?? 1,
      normalizedAt: new Date().toISOString(),
      padLength: options.padLength,
      targetField: options.targetField,
    },
  };
}

function buildRollbackUpdate(doc) {
  const data = doc.data();
  const migrationInfo = data[MIGRATION_FIELD];
  if (!migrationInfo) return null;

  const update = {
    [MIGRATION_FIELD]: admin.firestore.FieldValue.delete(),
  };

  if (migrationInfo.previousValue === null || typeof migrationInfo.previousValue === 'undefined') {
    update[options.targetField] = admin.firestore.FieldValue.delete();
  } else {
    update[options.targetField] = migrationInfo.previousValue;
  }

  return update;
}

async function createBackup(docs) {
  if (!docs.length) return null;
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.join(process.cwd(), 'backups');
  await fs.mkdir(backupDir, { recursive: true });
  const backupFile = path.join(backupDir, `provenanceid_normalization_${timestamp}.json`);
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
    ? '↩️  Running provenanceId rollback'
    : `➡️  Normalizing provenanceId values in "${options.collection}"`);

  const docs = await fetchDocuments();
  if (!docs.length) {
    console.log('✅ No documents found.');
    return;
  }

  console.log(`📄 Loaded ${docs.length} document(s) from ${options.collection}`);

  const updates = [];
  for (const doc of docs) {
    const payload = options.rollback ? buildRollbackUpdate(doc) : buildForwardUpdate(doc);
    if (!payload) continue;
    updates.push({ ref: doc.ref, data: payload });
    if (options.verbose) {
      console.log(`  • queued update for ${doc.id}`);
    }
    if (options.limit && updates.length >= options.limit) break;
  }

  if (!updates.length) {
    console.log('⚠️  No updates required.');
    return;
  }

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

  if (options.dryRun) {
    console.log(`📝 Dry run complete – ${updates.length} document(s) would be updated.`);
    return;
  }

  await applyUpdates(updates);
  console.log(`✅ Successfully ${options.rollback ? 'restored' : 'normalized'} ${updates.length} document(s).`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ provenanceId normalization failed:', error);
    process.exit(1);
  });
