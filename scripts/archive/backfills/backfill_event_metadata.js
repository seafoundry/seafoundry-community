#!/usr/bin/env node

/**
 * Backfills `metadata.organismKind` onto existing Firestore event documents.
 *
 * Usage:
 *   node scripts/backfill_event_metadata.js [--dry-run] [--force]
 *        [--limit <n>] [--batch-size <n>] [--verbose]
 *
 * The script scans the `events` collection ordered by document ID so it can
 * resume/re-run without rewriting the entire collection, infers the organism
 * kind from the referenced record (or sensible fallbacks), and updates events
 * that are missing the new metadata.
 */

const { db } = require('./config-json');
const admin = require('firebase-admin');
const readline = require('readline');

const SUPPORTED_KINDS = new Set([
  'coral',
  'oyster',
  'seagrass',
  'kelp',
  'mangrove',
  'echinoid',
  'crab',
  'finfish',
  'seaCucumber'
]);
const DEFAULT_KIND = 'coral';

const MODEL_TO_COLLECTION = {
  organization: 'organizations',
  site: 'sites',
  group: 'groups',
  coral: 'corals',
  genet: 'genets',
  event: 'events'
};

const FALLBACK_BY_MODEL = {
  coral: 'coral',
  genet: 'coral'
};

const args = process.argv.slice(2);
const options = {
  dryRun: args.includes('--dry-run') || args.includes('-d'),
  force: args.includes('--force') || args.includes('-f'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  help: args.includes('--help') || args.includes('-h'),
  limit: null,
  batchSize: 400,
  organizationId: null,
  startAfter: null
};

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--limit' || arg === '-l') {
    options.limit = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--batch-size') {
    options.batchSize = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--organization' || arg === '--org') {
    const value = (args[i + 1] || '').trim();
    options.organizationId = value.length > 0 ? value : null;
    i += 1;
  } else if (arg === '--start-after') {
    const value = (args[i + 1] || '').trim();
    options.startAfter = value.length > 0 ? value : null;
    i += 1;
  }
}

if (options.help) {
  console.log(`
🔧 Backfill Event Metadata

Adds metadata.organismKind to existing events so downstream services can
reason about organism context.

Options:
  --dry-run, -d        Preview changes without writing to Firestore
  --force, -f         Skip confirmation prompt
  --limit, -l <n>     Process only the first <n> events (useful for testing)
  --batch-size <n>    Number of updates per commit (default: 400)
  --organization, --org <id>
                      Limit processing to events for the provided organizationId
  --start-after <doc> Resume iteration after the provided document ID
  --verbose, -v       Log reasoning for each update
  --help, -h          Show this help text
`);
  process.exit(0);
}

if (options.organizationId) {
  console.log(
    `📍 Limiting to organizationId=${options.organizationId}`,
  );
}
if (options.startAfter) {
  console.log(`⏩ Resuming after document ${options.startAfter}`);
}

const stats = {
  scanned: 0,
  alreadyTagged: 0,
  updated: 0,
  skippedMissingRecord: 0,
  skippedNoInference: 0,
  limitReached: false
};

const recordCache = new Map();

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

function normalizeKind(value) {
  if (!value) return null;
  const normalized = value.toString().trim();
  if (!normalized) return null;
  const key = normalized
    .replace(/([A-Z])/g, (match) => `_${match.toLowerCase()}`)
    .toLowerCase()
    .replace(/[^a-z]/g, '');
  const camel = normalized
    .replace(/[\s_-]+(.)/g, (_, c) => c.toUpperCase())
    .replace(/^[A-Z]/, (c) => c.toLowerCase());

  if (SUPPORTED_KINDS.has(normalized)) return normalized;
  if (SUPPORTED_KINDS.has(key)) return key;
  if (SUPPORTED_KINDS.has(camel)) return camel;
  return null;
}

async function fetchRecord(modelType, recordId) {
  if (!modelType || !recordId) return null;
  const collection = MODEL_TO_COLLECTION[modelType];
  if (!collection) return null;
  const cacheKey = `${collection}:${recordId}`;
  if (recordCache.has(cacheKey)) {
    return recordCache.get(cacheKey);
  }
  try {
    const doc = await db.collection(collection).doc(recordId).get();
    if (!doc.exists) {
      stats.skippedMissingRecord += 1;
      return null;
    }
    const data = doc.data();
    recordCache.set(cacheKey, data);
    return data;
  } catch (error) {
    console.error(`⚠️  Failed to fetch ${collection}/${recordId}:`, error);
    stats.skippedMissingRecord += 1;
    return null;
  }
}

async function inferOrganismKind(eventDoc) {
  const data = eventDoc.data();
  if (!data) return null;

  if (data.metadata && data.metadata.organismKind) {
    return data.metadata.organismKind;
  }

  const recordId = data.recordId;
  const recordModelType = data.recordModelType;
  const record = await fetchRecord(recordModelType, recordId);
  const candidates = [
    record?.organismKind,
    Array.isArray(record?.organismKinds) ? record.organismKinds[0] : null,
    Array.isArray(record?.supportedOrganismKinds)
      ? record.supportedOrganismKinds[0]
      : null,
    record?.metadata?.organismKind,
    FALLBACK_BY_MODEL[recordModelType],
    DEFAULT_KIND
  ];

  for (const candidate of candidates) {
    const normalized = normalizeKind(candidate);
    if (normalized) {
      return normalized;
    }
  }

  return null;
}

async function flushUpdates(updates) {
  if (updates.length === 0) {
    return;
  }
  if (options.dryRun) {
    stats.updated += updates.length;
    return;
  }
  const batch = db.batch();
  updates.forEach(({ ref, metadata }) => {
    batch.update(ref, { metadata });
  });
  await batch.commit();
  stats.updated += updates.length;
}

async function processEvents() {
  if (!options.dryRun && !options.force) {
    const confirmed = await prompt(
      'This will update event documents in Firestore. Continue? (y/N): '
    );
    if (!confirmed) {
      console.log('Aborted.');
      process.exit(0);
    }
  }

  let lastDoc = null;
  let startedAfterInitialCursor = !options.startAfter;
  const updates = [];

  while (true) {
    if (options.limit && stats.scanned >= options.limit) {
      stats.limitReached = true;
      break;
    }

    let query = db.collection('events');

    if (options.organizationId) {
      query = query.where('organizationId', '==', options.organizationId);
    }

    query = query
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(options.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    } else if (!startedAfterInitialCursor && options.startAfter) {
      query = query.startAfter(options.startAfter);
      startedAfterInitialCursor = true;
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    for (const doc of snapshot.docs) {
      if (options.limit && stats.scanned >= options.limit) {
        stats.limitReached = true;
        break;
      }

      stats.scanned += 1;
      const data = doc.data() || {};
      const metadata = data.metadata || {};

      if (metadata.organismKind) {
        stats.alreadyTagged += 1;
        continue;
      }

      const kind = await inferOrganismKind(doc);
      if (!kind) {
        stats.skippedNoInference += 1;
        if (options.verbose) {
          console.warn(`⚠️  Unable to infer organism kind for event ${doc.id}`);
        }
        continue;
      }

      const newMetadata = { ...metadata, organismKind: kind };
      if (options.verbose || options.dryRun) {
        console.log(
          `${options.dryRun ? '[DRY RUN] ' : ''}Updating event ${
            doc.id
          } → organismKind=${kind}`
        );
      }

      updates.push({ ref: doc.ref, metadata: newMetadata });

      if (!options.dryRun && updates.length >= options.batchSize) {
        await flushUpdates(updates.splice(0, updates.length));
      }
    }

    if (stats.limitReached) {
      break;
    }
  }

  await flushUpdates(updates);
}

processEvents()
  .then(() => {
    console.log('\n✅ Backfill complete');
    console.table({
      scanned: stats.scanned,
      alreadyTagged: stats.alreadyTagged,
      updated: stats.updated,
      skippedMissingRecord: stats.skippedMissingRecord,
      skippedNoInference: stats.skippedNoInference,
      limitReached: stats.limitReached
    });
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Backfill failed:', error);
    process.exit(1);
  });
