#!/usr/bin/env node

/**
 * Normalizes registry IDs (environmental thresholds, husbandry schedules, mortality causes)
 * so they align with the deterministic fallback rules now used in the Dart models.
 *
 * Usage:
 *   node scripts/migrate_registry_ids.js [--dry-run]
 */

const { db } = require('./config-json');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run') || args.includes('-d');

async function main() {
  const tasks = [
    {
      docId: 'environmental_thresholds',
      label: 'Environmental Thresholds',
      shouldReplace: shouldReplaceEnvironmentalId,
      computeId: computeEnvironmentalId,
    },
    {
      docId: 'husbandry_schedules',
      label: 'Husbandry Schedules',
      shouldReplace: shouldReplaceHusbandryId,
      computeId: computeHusbandryId,
    },
    {
      docId: 'mortality_causes',
      label: 'Mortality Causes',
      shouldReplace: shouldReplaceMortalityId,
      computeId: computeMortalityId,
    },
  ];

  const summary = [];
  for (const task of tasks) {
    const result = await migrateDoc(task);
    summary.push(result);
  }

  console.log('\nMigration summary:');
  summary.forEach(({ label, updated, total }) => {
    console.log(
      `  • ${label}: ${updated} / ${total} entries received deterministic IDs`,
    );
  });

  if (dryRun) {
    console.log(
      '\nDry run complete. Re-run without --dry-run to persist the updates.',
    );
  } else {
    console.log(
      '\nDone. Re-run `npm run sync:taxonomy-configs` (or the dart script) to refresh YAML snapshots after this migration.',
    );
  }
}

async function migrateDoc({ docId, label, shouldReplace, computeId }) {
  const ref = db.collection('taxonomy_overrides').doc(docId);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    console.log(`⚠️  Skipping ${label} — document not found.`);
    return { label, updated: 0, total: 0 };
  }

  const data = snapshot.data() || {};
  const overrides = data.overrides || {};
  let updated = 0;
  let total = 0;

  const nextOverrides = {};

  for (const [kind, entries] of Object.entries(overrides)) {
    if (!Array.isArray(entries)) {
      nextOverrides[kind] = entries;
      continue;
    }

    const duplicateIds = findDuplicateIds(entries);
    const updatedEntries = entries.map((entry) => {
      total += 1;
      const newEntry = { ...entry };
      const needsUpdate = shouldReplace(kind, newEntry, duplicateIds);
      if (needsUpdate) {
        const nextId = computeId(kind, newEntry);
        if (nextId && nextId !== newEntry.id) {
          newEntry.id = nextId;
          updated += 1;
        }
      }
      return newEntry;
    });

    nextOverrides[kind] = updatedEntries;
  }

  if (updated === 0) {
    console.log(`✓ ${label}: no changes required.`);
    return { label, updated, total };
  }

  console.log(
    `${dryRun ? 'ℹ️ ' : '✅ '} ${label}: ${updated} entries will receive deterministic IDs.`,
  );

  if (!dryRun) {
    await ref.set(
      {
        overrides: nextOverrides,
        updatedAt: Date.now(),
        migrationNote: 'Normalized registry IDs via migrate_registry_ids.js',
      },
      { merge: true },
    );
  }

  return { label, updated, total };
}

function findDuplicateIds(entries) {
  const counts = entries.reduce((acc, entry) => {
    const id = entry.id || '__missing__';
    acc[id] = (acc[id] || 0) + 1;
    return acc;
  }, {});
  return new Set(
    Object.entries(counts)
      .filter(([, count]) => count > 1)
      .map(([id]) => (id === '__missing__' ? undefined : id))
      .filter(Boolean),
  );
}

function shouldReplaceEnvironmentalId(kind, entry, duplicateIds) {
  if (!entry.id) return true;
  const legacyId = `${kind}_${entry.metric ?? ''}`;
  if (entry.id === legacyId) return true;
  return duplicateIds.has(entry.id);
}

function shouldReplaceHusbandryId(kind, entry, duplicateIds) {
  if (!entry.id) return true;
  const legacyId = `${kind}_${entry.title ?? ''}`;
  if (entry.id === legacyId) return true;
  return duplicateIds.has(entry.id);
}

function shouldReplaceMortalityId(kind, entry) {
  if (!entry.id) return true;
  const legacyPattern = new RegExp(`^${kind}_[\\-0-9]+$`);
  return legacyPattern.test(entry.id);
}

function computeEnvironmentalId(kind, entry) {
  const metric = sluggify(entry.metric || 'metric');
  const lifeStage = (entry.lifeStage || 'any').toString();
  const severity = (entry.severity || 'warning').toString().toLowerCase();
  const minValue =
      entry.min ?? entry.minValue ?? entry.minimum ?? null;
  const maxValue =
      entry.max ?? entry.maxValue ?? entry.maximum ?? null;

  return [
    kind,
    metric,
    lifeStage,
    severity,
    `min_${minValue ?? 'none'}`,
    `max_${maxValue ?? 'none'}`,
  ].join('_');
}

function computeHusbandryId(kind, entry) {
  const title = sluggify(entry.title || 'task');
  const lifeStage = (entry.lifeStage || 'any').toString();
  const frequency =
      entry.frequencyDays ?? entry.frequency ?? entry.interval ?? 'na';

  return [kind, lifeStage, title, `freq_${frequency}`].join('_');
}

function computeMortalityId(kind, entry) {
  const lifeStage = (entry.lifeStage || 'any').toString();
  const label = sluggify(entry.label || entry.name || 'mortality');
  const severity = (entry.severity || 'unspecified').toString().toLowerCase();
  const tags = Array.isArray(entry.tags) ? entry.tags.map(sluggify).sort() : [];

  const parts = [kind, lifeStage, label, severity];
  if (tags.length) {
    parts.push(`tags_${tags.join('-')}`);
  }
  return parts.join('_');
}

function sluggify(value) {
  if (!value) return 'value';
  return value.toString().trim().toLowerCase().replace(/[^a-z0-9]+/g, '-');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Migration failed', error);
    process.exit(1);
  });
