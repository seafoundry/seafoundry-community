#!/usr/bin/env node

/**
 * Syncs taxonomy YAML defaults (environmental thresholds, husbandry schedules,
 * validation rules, mortality causes) into Firestore via Firebase Admin SDK.
 *
 * Usage:
 *   node scripts/sync_taxonomy_configs.js [--updatedBy=<userId>] [--dry-run]
 *   npm run sync:taxonomy-configs -- --updatedBy=<userId>
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const { admin, db } = require('./config-json');

const args = process.argv.slice(2);
let updatedBy = process.env.USER || process.env.USERNAME || 'cli_sync';
let dryRun = false;

for (const arg of args) {
  if (arg.startsWith('--updatedBy=')) {
    updatedBy = arg.split('=').pop() || updatedBy;
  } else if (arg === '--dry-run') {
    dryRun = true;
  }
}

const configs = [
  {
    label: 'Environmental Thresholds',
    docId: 'environmental_thresholds',
    file: 'config/environmental_thresholds.defaults.yaml',
  },
  {
    label: 'Husbandry Schedules',
    docId: 'husbandry_schedules',
    file: 'config/husbandry_schedules.defaults.yaml',
  },
  {
    label: 'Validation Rules',
    docId: 'validation_rules',
    file: 'config/validation_rules.defaults.yaml',
  },
  {
    label: 'Mortality Causes',
    docId: 'mortality_causes',
    file: 'config/mortality_causes.defaults.yaml',
  },
];

async function syncTaxonomyConfigs(options = {}) {
  const runUpdatedBy = options.updatedBy || updatedBy;
  const runDry = options.dryRun ?? dryRun;
  const summaries = [];

  for (const config of configs) {
    const filePath = path.join(process.cwd(), config.file);
    if (!fs.existsSync(filePath)) {
      console.warn(`⚠️  ${config.label}: file not found (${config.file}). Skipping.`);
      continue;
    }

    const yamlContent = fs.readFileSync(filePath, 'utf8');
    const parsed = safeLoadYaml(config.label, yamlContent);
    summaries.push(await persistConfig(config, yamlContent, parsed, runUpdatedBy, runDry));
  }

  return summaries;
}

function safeLoadYaml(label, contents) {
  try {
    const parsed = yaml.load(contents) || {};
    if (typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('YAML root must be a map keyed by organism kind.');
    }
    return parsed;
  } catch (error) {
    throw new Error(`${label}: Failed to parse YAML – ${error.message}`);
  }
}

async function persistConfig(config, yamlContent, overrides, runUpdatedBy, runDry) {
  const payload = {
    yaml: yamlContent,
    overrides,
    updatedBy: runUpdatedBy,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (runDry) {
    console.log(`📝 [dry-run] ${config.label}: would update taxonomy_overrides/${config.docId}`);
    return { label: config.label, dryRun: true };
  }

  await db
      .collection('taxonomy_overrides')
      .doc(config.docId)
      .set(payload, { merge: true });

  console.log(`✅ ${config.label}: synced ${Object.keys(overrides).length} organism entries.`);
  return { label: config.label, dryRun: false };
}

if (require.main === module) {
  syncTaxonomyConfigs()
      .then((summaries) => {
        if (summaries.length === 0) {
          console.log('ℹ️  No taxonomy configs were updated.');
        } else {
          console.log('\n✨ Taxonomy config sync complete.');
        }
        process.exit(0);
      })
      .catch((error) => {
        console.error('❌ Failed to sync taxonomy configs:', error.message);
        process.exit(1);
      });
}

module.exports = { syncTaxonomyConfigs };
