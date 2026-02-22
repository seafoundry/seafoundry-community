#!/usr/bin/env node

/**
 * Identifies and optionally removes duplicate species documents in taxonomy_species.
 * 
 * Duplicates are documents with the same species code but different document IDs.
 * The canonical (shorter) ID format is kept, and legacy longer IDs are removed.
 * 
 * Usage:
 *   # Dry run - just report duplicates
 *   node scripts/cleanup-duplicate-species.js
 *   
 *   # Actually delete duplicates
 *   node scripts/cleanup-duplicate-species.js --delete
 * 
 * Requires GOOGLE_APPLICATION_CREDENTIALS or firebase-service-account.json
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
let db;
try {
  if (!admin.apps.length) {
    const serviceAccountPath = path.join(__dirname, '..', 'firebase-service-account.json');
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'seafoundryapp',
      });
      console.log('✅ Using service account from firebase-service-account.json');
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp();
      console.log('✅ Using GOOGLE_APPLICATION_CREDENTIALS');
    } else {
      console.error('❌ No Firebase credentials found');
      console.error('   Set GOOGLE_APPLICATION_CREDENTIALS or create firebase-service-account.json');
      process.exit(1);
    }
  }
  db = admin.firestore();
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error.message);
  process.exit(1);
}

const COLLECTION_PATH = 'taxonomy_species';

async function findDuplicateSpecies() {
  console.log('\n🔍 Scanning taxonomy_species collection for duplicates...\n');

  const snapshot = await db.collection(COLLECTION_PATH).get();

  // Group by species code
  const byCode = new Map();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const code = (data.code || '').toLowerCase();

    if (!code) {
      console.log(`⚠️  Document ${doc.id} has no code, skipping`);
      continue;
    }

    if (!byCode.has(code)) {
      byCode.set(code, []);
    }
    byCode.get(code).push({
      id: doc.id,
      code: data.code,
      genus: data.genus,
      species: data.species,
      aliases: data.aliases || [],
    });
  }

  // Find codes with multiple documents
  const duplicates = [];
  for (const [code, docs] of byCode) {
    if (docs.length > 1) {
      // Sort by ID length - shortest first (canonical)
      docs.sort((a, b) => a.id.length - b.id.length);
      duplicates.push({
        code: code.toUpperCase(),
        canonical: docs[0],
        toDelete: docs.slice(1),
      });
    }
  }

  return duplicates;
}

async function reportDuplicates(duplicates) {
  if (duplicates.length === 0) {
    console.log('✅ No duplicate species found!\n');
    return;
  }

  console.log(`⚠️  Found ${duplicates.length} species with duplicate documents:\n`);

  for (const dup of duplicates) {
    console.log(`  Species code: ${dup.code}`);
    console.log(`    Canonical (keep): ${dup.canonical.id}`);
    console.log(`    To delete: ${dup.toDelete.map(d => d.id).join(', ')}`);
    console.log('');
  }
}

async function deleteDuplicates(duplicates) {
  if (duplicates.length === 0) {
    console.log('✅ No duplicates to delete.\n');
    return;
  }

  console.log(`🗑️  Deleting ${duplicates.reduce((sum, d) => sum + d.toDelete.length, 0)} duplicate documents...\n`);

  const batch = db.batch();
  let deleteCount = 0;

  for (const dup of duplicates) {
    for (const toDelete of dup.toDelete) {
      console.log(`  Deleting ${toDelete.id} (duplicate of ${dup.canonical.id})`);
      batch.delete(db.collection(COLLECTION_PATH).doc(toDelete.id));
      deleteCount++;
    }
  }

  await batch.commit();
  console.log(`\n✅ Deleted ${deleteCount} duplicate documents.\n`);
}

async function main() {
  const shouldDelete = process.argv.includes('--delete');

  if (shouldDelete) {
    console.log('⚠️  DELETE MODE - Duplicates will be removed\n');
  } else {
    console.log('ℹ️  DRY RUN - Use --delete flag to actually remove duplicates\n');
  }

  const duplicates = await findDuplicateSpecies();
  await reportDuplicates(duplicates);

  if (shouldDelete && duplicates.length > 0) {
    await deleteDuplicates(duplicates);
  } else if (duplicates.length > 0) {
    console.log('💡 Run with --delete flag to remove duplicates:\n');
    console.log('   node scripts/cleanup-duplicate-species.js --delete\n');
  }
}

main().catch((error) => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});
