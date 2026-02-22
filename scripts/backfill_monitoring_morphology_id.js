#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Backfills morphologyId for monitoring events stored in /events.
 *
 * Moves legacy morphology values stored in physicalFormId into morphologyId
 * and removes the legacy field when it is clearly a morphology value.
 *
 * Usage:
 *  node scripts/backfill_monitoring_morphology_id.js [--dry-run] [--force]
 *    [--limit <n>] [--batch-size <n>] [--commit-size <n>]
 *    [--start-after <docId>] [--verbose]
 */

const { admin, db } = require('./config-json');
const readline = require('readline');

const args = process.argv.slice(2);
const options = {
  dryRun: args.includes('--dry-run') || args.includes('-d'),
  force: args.includes('--force') || args.includes('-f'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  limit: null,
  batchSize: 200,
  commitSize: 400,
  startAfter: null,
  help: args.includes('--help') || args.includes('-h')
};

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--limit' || arg === '-l') {
    options.limit = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--batch-size') {
    options.batchSize = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--commit-size') {
    options.commitSize = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--start-after') {
    options.startAfter = (args[i + 1] || '').trim() || null;
    i += 1;
  }
}

if (options.help) {
  console.log(`
🔧 Monitoring Morphology Backfill

Moves legacy morphology values stored in physicalFormId to morphologyId.

Options:
  --dry-run, -d        Preview changes without writing
  --force, -f          Skip confirmation prompt
  --limit, -l <n>      Process only the first <n> documents
  --batch-size <n>     Number of docs to fetch per query (default: 200)
  --commit-size <n>    Number of updates per batch commit (default: 400)
  --start-after <id>   Resume iteration after the provided document ID
  --verbose, -v        Log every document decision
  --help, -h           Show this help text
`);
  process.exit(0);
}

const morphologyAliases = new Map([
  ['bouldering', 'massive']
]);
const morphologyIds = new Set([
  'branching',
  'plating',
  'massive',
  'columnar',
  'digitate',
  'foliose'
]);

const eventTypeIds = new Set([
  'event_observation',
  'event_observation_correction',
  'event_maintenance_required_observation'
]);

const stats = {
  scanned: 0,
  updated: 0,
  skipped: 0,
  limitReached: false
};

async function prompt(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  return new Promise((resolve) => {
    rl.question(message, (answer) => {
      rl.close();
      resolve(answer.trim().toLowerCase().startsWith('y'));
    });
  });
}

function normalizeMorphology(value) {
  if (!value) return null;
  const normalized = value.toString().trim().toLowerCase().replace(/\s+/g, '_');
  const mapped = morphologyAliases.get(normalized) || normalized;
  return morphologyIds.has(mapped) ? mapped : null;
}

function updateMeasurementMap(measurements) {
  if (!measurements || typeof measurements !== 'object') {
    return { updated: false, next: measurements };
  }
  const next = { ...measurements };
  const rawMorphology =
    next.morphologyId ?? next.morphology_id ?? null;
  const rawPhysical =
    next.physicalFormId ?? next.physical_form_id ?? null;
  const normalizedMorphology =
    normalizeMorphology(rawMorphology) || normalizeMorphology(rawPhysical);
  let updated = false;

  if (normalizedMorphology && normalizedMorphology !== rawMorphology) {
    next.morphologyId = normalizedMorphology;
    updated = true;
  }

  const normalizedPhysical = normalizeMorphology(rawPhysical);
  if (normalizedPhysical) {
    delete next.physicalFormId;
    delete next.physical_form_id;
    updated = true;
  }

  return { updated, next };
}

function updateEntry(entry) {
  if (!entry || typeof entry !== 'object') {
    return { updated: false, next: entry };
  }
  const next = { ...entry };
  const normalized =
    normalizeMorphology(next.morphologyId) ||
    normalizeMorphology(next.physicalFormId) ||
    normalizeMorphology(next.physicalForm);
  let updated = false;

  if (normalized && normalized !== next.morphologyId) {
    next.morphologyId = normalized;
    updated = true;
  }

  const legacyPhysical = normalizeMorphology(next.physicalFormId);
  if (legacyPhysical) {
    delete next.physicalFormId;
    updated = true;
  }

  const measurementResult = updateMeasurementMap(next.measurements);
  if (measurementResult.updated) {
    next.measurements = measurementResult.next;
    updated = true;
  }

  return { updated, next };
}

async function run() {
  if (!options.force && !options.dryRun) {
    const ok = await prompt(
      '⚠️  This will update monitoring events in /events. Continue? (y/N) '
    );
    if (!ok) {
      console.log('Aborted.');
      process.exit(0);
    }
  }

  let query = db
    .collection('events')
    .where('eventTypeId', 'in', Array.from(eventTypeIds))
    .orderBy(admin.firestore.FieldPath.documentId())
    .limit(options.batchSize);

  if (options.startAfter) {
    query = query.startAfter(options.startAfter);
  }

  let lastDocId = options.startAfter;
  let batch = db.batch();
  let pendingWrites = 0;

  while (true) {
    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      stats.scanned += 1;
      lastDocId = doc.id;
      const data = doc.data();
      if (!data || !eventTypeIds.has(data.eventTypeId)) {
        stats.skipped += 1;
        continue;
      }

      let updated = false;
      const nextData = { ...data };

      const measurementResult = updateMeasurementMap(nextData.measurements);
      if (measurementResult.updated) {
        nextData.measurements = measurementResult.next;
        updated = true;
      }

      if (Array.isArray(nextData.entries)) {
        const updatedEntries = [];
        let entriesUpdated = false;
        for (const entry of nextData.entries) {
          const entryResult = updateEntry(entry);
          updatedEntries.push(entryResult.next);
          if (entryResult.updated) entriesUpdated = true;
        }
        if (entriesUpdated) {
          nextData.entries = updatedEntries;
          updated = true;
        }
      }

      if (updated) {
        stats.updated += 1;
        if (options.verbose) {
          console.log(`✅ ${doc.id} updated`);
        }
        if (!options.dryRun) {
          batch.update(doc.ref, nextData);
          pendingWrites += 1;
        }
      } else {
        stats.skipped += 1;
        if (options.verbose) {
          console.log(`⏭️  ${doc.id} no change`);
        }
      }

      if (options.limit && stats.scanned >= options.limit) {
        stats.limitReached = true;
        break;
      }

      if (!options.dryRun && pendingWrites >= options.commitSize) {
        await batch.commit();
        batch = db.batch();
        pendingWrites = 0;
        console.log(`Committed ${options.commitSize} updates...`);
      }
    }

    if (options.limit && stats.limitReached) break;
    query = db
      .collection('events')
      .where('eventTypeId', 'in', Array.from(eventTypeIds))
      .orderBy(admin.firestore.FieldPath.documentId())
      .startAfter(lastDocId)
      .limit(options.batchSize);
  }

  if (!options.dryRun && pendingWrites > 0) {
    await batch.commit();
  }

  console.log('\n🧪 Backfill complete');
  console.log(`Scanned: ${stats.scanned}`);
  console.log(`Updated: ${stats.updated}`);
  console.log(`Skipped: ${stats.skipped}`);
  if (stats.limitReached) {
    console.log('Limit reached; resume with --start-after', lastDocId);
  }
}

run().catch((error) => {
  console.error('Backfill failed:', error);
  process.exit(1);
});
