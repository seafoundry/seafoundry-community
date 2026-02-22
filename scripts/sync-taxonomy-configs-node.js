#!/usr/bin/env node

/**
 * Syncs taxonomy YAML configs (environmental thresholds + husbandry schedules)
 * to Firestore via Firebase Admin SDK so automation/CI can keep overrides
 * aligned with the repo defaults.
 * 
 * This is a Node.js version that uses Firebase Admin SDK instead of Flutter,
 * avoiding the Flutter UI dependency issues.
 * 
 * Usage:
 *   node scripts/sync-taxonomy-configs-node.js [--updatedBy=<userId>]
 *   npm run sync:taxonomy-configs:node -- --updatedBy=<userId>
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
let db;
try {
  if (!admin.apps.length) {
    // Try service account JSON file first
    const serviceAccountPath = path.join(__dirname, '..', 'firebase-service-account.json');
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'seafoundryapp',
      });
      console.log('✅ Using service account from firebase-service-account.json');
    } else {
      // Fall back to config.js (which uses .env)
      const { db: dbFromConfig } = require('./config');
      db = dbFromConfig;
      console.log('✅ Using service account from .env');
    }
  }
  if (!db) {
    db = admin.firestore();
  }
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error.message);
  console.error('Please ensure firebase-service-account.json exists or .env has Firebase credentials');
  process.exit(1);
}

// Document IDs matching TaxonomyAdminService
const DOC_IDS = {
  environmental: 'environmental_thresholds',
  husbandry: 'husbandry_schedules',
  validation: 'validation_rules',
  mortality: 'mortality_causes',
};

const COLLECTION_PATH = 'taxonomy_overrides';

// Parse command line arguments
const args = process.argv.slice(2);
let updatedBy = null;
for (const arg of args) {
  if (arg.startsWith('--updatedBy=')) {
    updatedBy = arg.split('=')[1];
  }
}

if (!updatedBy) {
  updatedBy = process.env.USER || process.env.USERNAME || 'cli_sync';
}

async function yamlToMap(yamlContent) {
  const parsed = yaml.load(yamlContent);
  return parsed || {};
}

async function saveYamlConfig(docId, yamlContent, updatedBy) {
  const overrides = await yamlToMap(yamlContent);
  const payload = {
    yaml: yamlContent,
    overrides: overrides,
    updatedAt: require('firebase-admin').firestore.FieldValue.serverTimestamp(),
  };
  
  if (updatedBy) {
    payload.updatedBy = updatedBy.trim();
  }
  
  const docRef = db.collection(COLLECTION_PATH).doc(docId);
  await docRef.set(payload, { merge: true });
  console.log(`  ✅ Synced ${docId}`);
}

async function syncTaxonomyConfigs() {
  try {
    console.log('🌊 Syncing taxonomy YAML configs as', updatedBy);
    console.log('');
    
    const configDir = path.join(__dirname, '..', 'config');
    
    // Environmental thresholds
    const envPath = path.join(configDir, 'environmental_thresholds.defaults.yaml');
    if (fs.existsSync(envPath)) {
      const envYaml = fs.readFileSync(envPath, 'utf8');
      await saveYamlConfig(DOC_IDS.environmental, envYaml, updatedBy);
    } else {
      console.log(`  ⚠️  File not found: ${envPath}`);
    }
    
    // Husbandry schedules
    const husbandryPath = path.join(configDir, 'husbandry_schedules.defaults.yaml');
    if (fs.existsSync(husbandryPath)) {
      const husbandryYaml = fs.readFileSync(husbandryPath, 'utf8');
      await saveYamlConfig(DOC_IDS.husbandry, husbandryYaml, updatedBy);
    } else {
      console.log(`  ⚠️  File not found: ${husbandryPath}`);
    }
    
    // Validation rules
    const validationPath = path.join(configDir, 'validation_rules.defaults.yaml');
    if (fs.existsSync(validationPath)) {
      const validationYaml = fs.readFileSync(validationPath, 'utf8');
      await saveYamlConfig(DOC_IDS.validation, validationYaml, updatedBy);
    } else {
      console.log(`  ⚠️  File not found: ${validationPath}`);
    }
    
    // Mortality causes
    const mortalityPath = path.join(configDir, 'mortality_causes.defaults.yaml');
    if (fs.existsSync(mortalityPath)) {
      const mortalityYaml = fs.readFileSync(mortalityPath, 'utf8');
      await saveYamlConfig(DOC_IDS.mortality, mortalityYaml, updatedBy);
    } else {
      console.log(`  ⚠️  File not found: ${mortalityPath}`);
    }
    
    console.log('');
    console.log('✨ Done! Firestore overrides now match repository defaults.');
    
  } catch (error) {
    console.error('\n❌ Error syncing taxonomy configs:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the sync
syncTaxonomyConfigs();

