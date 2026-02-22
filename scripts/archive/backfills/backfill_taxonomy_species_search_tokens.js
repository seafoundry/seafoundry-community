#!/usr/bin/env node

/**
 * Backfills `searchTokens` for all taxonomy species documents so the taxonomy
 * admin panel can run efficient server-side searches.
 *
 * Usage:
 *   node scripts/backfill_taxonomy_species_search_tokens.js [--dry-run]
 *        [--force] [--limit <n>] [--batch-size <n>] [--commit-size <n>]
 *        [--start-after <docId>] [--verbose]
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
🔎 Taxonomy Species Search Token Backfill

Adds the \`searchTokens\` array to every document in the \`taxonomy_species\`
collection so Firestore queries can resolve searches without scanning the entire
catalog.

Options:
  --dry-run, -d        Preview changes without writing to Firestore
  --force, -f         Skip confirmation prompt
  --limit, -l <n>     Process only the first <n> documents
  --batch-size <n>    Number of docs to fetch per query (default: 200)
  --commit-size <n>   Number of updates per batch commit (default: 400)
  --start-after <id>  Resume iteration after the provided document ID
  --verbose, -v       Log every document decision
  --help, -h          Show this help text
`);
  process.exit(0);
}

const stats = {
  scanned: 0,
  updated: 0,
  unchanged: 0,
  noTokens: 0,
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

function normalizeList(values) {
  if (!Array.isArray(values) || values.length === 0) {
    return [];
  }
  return values
    .map((value) => (value || '').toString().trim().toLowerCase())
    .filter((value) => value.length > 0);
}

function splitTokens(value) {
  return value
    .split(/[^a-z0-9]+/g)
    .map((token) => token.trim())
    .filter((token) => token.length > 1);
}

function buildSearchTokens(docId, data = {}) {
  const tokens = new Set();

  function addToken(raw) {
    if (!raw && raw !== 0) return;
    const normalized = raw.toString().trim().toLowerCase();
    if (!normalized) return;
    tokens.add(normalized);
    for (const fragment of splitTokens(normalized)) {
      tokens.add(fragment);
    }
  }

  addToken(docId);
  addToken(data.code);
  addToken(data.genus);
  addToken(data.species);
  if (data.genus && data.species) {
    addToken(`${data.genus} ${data.species}`);
    addToken(`${(data.genus[0] || '').toLowerCase()}. ${data.species}`);
  }
  if (Array.isArray(data.commonNames)) {
    data.commonNames.forEach(addToken);
  }
  if (Array.isArray(data.aliases)) {
    data.aliases.forEach(addToken);
  }
  if (data.metadata) {
    addToken(data.metadata.scientificName);
  }

  const limited = Array.from(tokens).slice(0, 120);
  limited.sort();
  return limited;
}

function tokensEqual(existing = [], next = []) {
  const existingSet = new Set(normalizeList(existing));
  const nextSet = new Set(normalizeList(next));
  if (existingSet.size !== nextSet.size) {
    return false;
  }
  for (const value of nextSet) {
    if (!existingSet.has(value)) {
      return false;
    }
  }
  return true;
}

async function run() {
  if (!options.dryRun && !options.force) {
    const confirmed = await prompt(
      '⚠️  This will update taxonomy_species.searchTokens. Continue? (y/N) ',
    );
    if (!confirmed) {
      console.log('Aborting.');
      process.exit(0);
    }
  }

  const fieldPath = admin.firestore.FieldPath.documentId();
  let cursor = options.startAfter;
  let batch = db.batch();
  let pending = 0;

  async function flushBatch() {
    if (pending === 0 || options.dryRun) {
      return;
    }
    await batch.commit();
    batch = db.batch();
    pending = 0;
  }

  while (true) {
    let query = db
      .collection('taxonomy_species')
      .orderBy(fieldPath)
      .limit(options.batchSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }
    for (const doc of snapshot.docs) {
      stats.scanned += 1;
      const tokens = buildSearchTokens(doc.id, doc.data());
      if (tokens.length === 0) {
        stats.noTokens += 1;
        if (options.verbose) {
          console.log(`⚪️ ${doc.id}: No tokens derived (missing genus/species).`);
        }
        continue;
      }
      const existing = doc.data().searchTokens || [];
      if (tokensEqual(existing, tokens)) {
        stats.unchanged += 1;
        if (options.verbose) {
          console.log(`✔️  ${doc.id}: searchTokens already normalized.`);
        }
      } else if (options.dryRun) {
        stats.updated += 1;
        console.log(
          `📝 [DRY-RUN] ${doc.id}: would set searchTokens (${tokens.length} entries).`,
        );
      } else {
        batch.update(doc.ref, { searchTokens: tokens });
        pending += 1;
        stats.updated += 1;
        if (pending >= options.commitSize) {
          await flushBatch();
        }
      }

      if (options.limit && stats.scanned >= options.limit) {
        stats.limitReached = true;
        break;
      }
    }

    cursor = snapshot.docs[snapshot.docs.length - 1].id;
    if (stats.limitReached || snapshot.size < options.batchSize) {
      break;
    }
  }

  await flushBatch();

  console.log('\n✅ Backfill complete:');
  console.table(stats);
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Backfill failed:', error);
    process.exit(1);
  });
