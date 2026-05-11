#!/usr/bin/env node

/**
 * Migration helper that rewrites legacy eventTypeId values:
 * - event_death / death → event_population_loss (mortality reason)
 * - event_transfer      → event_loan
 */

const { db } = require('./config-json');

const args = process.argv.slice(2);
const options = {
  dryRun: args.includes('--dry-run') || args.includes('-d'),
  limit: null,
  help: args.includes('--help') || args.includes('-h'),
  verbose: args.includes('--verbose') || args.includes('-v'),
};

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--limit' || args[i] === '-l') {
    options.limit = parseInt(args[i + 1], 10);
  }
}

if (options.help) {
  console.log(`
🛠  Event Type Alias Migration

This script normalizes legacy eventTypeId values so that the app can rely on the new enums:
  • event_death / death → event_population_loss (mortality reason enforced)
  • event_transfer      → event_loan

Usage:
  node scripts/migrate_event_type_aliases.js [--dry-run] [--limit N] [--verbose]

Options:
  --dry-run | -d   Preview updates without writing to Firestore
  --limit  | -l    Maximum number of documents to update (across all aliases)
  --verbose | -v   Print each document id as it is processed
  --help | -h      Show this help text
`);
  process.exit(0);
}

const aliasMappings = [
  {
    fromIds: ['event_death', 'death'],
    toId: 'event_population_loss',
    mutateData: (data) => {
      if (!data.lossReasonId) {
        data.lossReasonId = 'population_loss_reason_mortality';
      }
      return data;
    },
  },
  {
    fromIds: ['event_transfer'],
    toId: 'event_loan',
  },
];

async function migrateAlias(alias, limitRemaining) {
  let updated = 0;
  for (const fromId of alias.fromIds) {
    if (limitRemaining !== null && limitRemaining <= 0) break;

    const query = db.collection('events').where('eventTypeId', '==', fromId);
    const snapshot = await query.get();

    for (const doc of snapshot.docs) {
      if (limitRemaining !== null && limitRemaining <= 0) break;

      const data = doc.data();
      const update = { eventTypeId: alias.toId };
      const mutated = alias.mutateData ? alias.mutateData({ ...data }) : data;
      if (alias.mutateData) {
        Object.assign(update, {
          lossReasonId: mutated.lossReasonId,
        });
      }

      if (options.verbose) {
        console.log(`${options.dryRun ? '[dry-run] ' : ''}Updating ${doc.id}: ${fromId} → ${alias.toId}`);
      }

      if (!options.dryRun) {
        await doc.ref.update(update);
      }

      updated++;
      if (limitRemaining !== null) {
        limitRemaining--;
      }
    }
  }
  return { updated, limitRemaining };
}

(async () => {
  let totalUpdated = 0;
  let remaining = options.limit;

  for (const alias of aliasMappings) {
    if (remaining !== null && remaining <= 0) break;
    const result = await migrateAlias(alias, remaining);
    totalUpdated += result.updated;
    remaining = result.limitRemaining;
  }

  console.log(
    options.dryRun
      ? `✅ Dry run complete. ${totalUpdated} events would be updated.`
      : `✅ Migration complete. ${totalUpdated} events updated.`,
  );
  process.exit(0);
})().catch((error) => {
  console.error('❌ Migration failed:', error);
  process.exit(1);
});
