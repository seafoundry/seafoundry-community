#!/usr/bin/env node
/**
 * Migration Script: legacyProvenanceId → provenanceId
 * 
 * This script migrates all genet documents from using the `legacyProvenanceId` field
 * to the new `provenanceId` field, and renames the legacy counter collection
 * to `provenanceIds`.
 * 
 * Usage:
 *   # Dry run (preview changes without applying)
 *   node scripts/migrations/migrate-legacy-id-to-provenanceid.js --dry-run
 * 
 *   # Execute migration on emulator
 *   FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/migrations/migrate-legacy-id-to-provenanceid.js --execute
 * 
 *   # Execute migration on production
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/migrations/migrate-legacy-id-to-provenanceid.js --execute --production
 */

const admin = require('firebase-admin');

// Parse command line arguments
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run') || !args.includes('--execute');
const isProduction = args.includes('--production');

// Initialize Firebase
if (!admin.apps.length) {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } else if (process.env.FIRESTORE_EMULATOR_HOST) {
    admin.initializeApp({ projectId: 'seafoundryapp' });
  } else {
    console.error('❌ No Firebase credentials configured.');
    console.error('   Set GOOGLE_APPLICATION_CREDENTIALS or FIRESTORE_EMULATOR_HOST');
    process.exit(1);
  }
}

const db = admin.firestore();

// Collections to migrate
const GENET_COLLECTIONS = ['genets', 'demo_genets'];
const LEGACY_ID_COLLECTION = 'legacy_provenance_ids';
const PROVENANCE_ID_COLLECTION = 'provenanceIds';

async function migrateGenets() {
  console.log('\n📦 Migrating genet documents: legacyProvenanceId → provenanceId\n');
  
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalErrors = 0;

  for (const collectionName of GENET_COLLECTIONS) {
    console.log(`\n  Processing ${collectionName}...`);
    
    const snapshot = await db.collection(collectionName).get();
    
    if (snapshot.empty) {
      console.log(`    ⏭️  No documents in ${collectionName}`);
      continue;
    }

    let batch = db.batch();
    let batchCount = 0;
    const MAX_BATCH_SIZE = 500;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Check if already migrated
      if (data.provenanceId && !data.legacyProvenanceId) {
        totalSkipped++;
        continue;
      }

      // Check if has legacyProvenanceId to migrate
      if (!data.legacyProvenanceId && !data.provenanceId) {
        console.log(`    ⚠️  ${doc.id}: No legacyProvenanceId or provenanceId found`);
        totalSkipped++;
        continue;
      }

      const legacyIdValue = data.legacyProvenanceId || data.provenanceId;
      
      if (isDryRun) {
        console.log(
          `    [DRY RUN] Would update ${doc.id}: legacyProvenanceId "${legacyIdValue}" → provenanceId`,
        );
        totalUpdated++;
      } else {
        // Update the document
        batch.update(doc.ref, {
          provenanceId: legacyIdValue,
          legacyProvenanceId: admin.firestore.FieldValue.delete(),
        });
        batchCount++;
        totalUpdated++;

        // Commit batch if at limit
        if (batchCount >= MAX_BATCH_SIZE) {
          await batch.commit();
          console.log(`    ✅ Committed batch of ${batchCount} documents`);
          batch = db.batch(); // Create new batch
          batchCount = 0;
        }
      }
    }

    // Commit remaining batch
    if (!isDryRun && batchCount > 0) {
      try {
        await batch.commit();
        console.log(`    ✅ Committed final batch of ${batchCount} documents`);
      } catch (error) {
        console.error(`    ❌ Error committing batch: ${error.message}`);
        totalErrors += batchCount;
        totalUpdated -= batchCount;
      }
    }

    console.log(`    📊 ${collectionName}: ${snapshot.size} total, ${totalUpdated} updated, ${totalSkipped} skipped`);
  }

  return { totalUpdated, totalSkipped, totalErrors };
}

async function migrateCounterCollection() {
  console.log('\n📦 Migrating counter collection: legacy provenance IDs → provenanceIds\n');
  
  let migrated = 0;
  let errors = 0;

  // Get all documents from legacy counter collection
  const legacySnapshot = await db.collection(LEGACY_ID_COLLECTION).get();
  
  if (legacySnapshot.empty) {
    console.log('  ⏭️  No documents in legacy counter collection');
    return { migrated: 0, errors: 0 };
  }

  console.log(`  Found ${legacySnapshot.size} documents in legacy counter collection`);

  for (const doc of legacySnapshot.docs) {
    const data = doc.data();
    
    if (isDryRun) {
      console.log(
        `  [DRY RUN] Would copy ${doc.id} to provenanceIds and delete from legacy counter collection`,
      );
      console.log(`    Data: counter=${data.counter}, updatedAt=${data.updatedAt?.toDate?.() || data.updatedAt}`);
      migrated++;
    } else {
      try {
        // Copy to new collection
        await db.collection(PROVENANCE_ID_COLLECTION).doc(doc.id).set(data);
        
        // Delete from old collection
        await db.collection(LEGACY_ID_COLLECTION).doc(doc.id).delete();
        
        console.log(`  ✅ Migrated ${doc.id}`);
        migrated++;
      } catch (error) {
        console.error(`  ❌ Error migrating ${doc.id}: ${error.message}`);
        errors++;
      }
    }
  }

  return { migrated, errors };
}

async function migrateAliasIndexEntries() {
  console.log('\n📦 Migrating alias index entries: legacyProvenanceId → provenanceId\n');
  
  const ALIAS_COLLECTIONS = ['genetics_aliases', 'demo_genetics_aliases'];
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalErrors = 0;

  for (const collectionName of ALIAS_COLLECTIONS) {
    console.log(`\n  Processing ${collectionName}...`);
    
    const snapshot = await db.collection(collectionName).get();
    
    if (snapshot.empty) {
      console.log(`    ⏭️  No documents in ${collectionName}`);
      continue;
    }

    let batch = db.batch();
    let batchCount = 0;
    const MAX_BATCH_SIZE = 500;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Check if already migrated
      if (data.provenanceId && !data.legacyProvenanceId) {
        totalSkipped++;
        continue;
      }

      // Check if has legacyProvenanceId to migrate
      if (!data.legacyProvenanceId && !data.provenanceId) {
        totalSkipped++;
        continue;
      }

      const legacyIdValue = data.legacyProvenanceId || data.provenanceId;
      
      if (isDryRun) {
        console.log(
          `    [DRY RUN] Would update ${doc.id}: legacyProvenanceId "${legacyIdValue}" → provenanceId`,
        );
        totalUpdated++;
      } else {
        // Update the document
        batch.update(doc.ref, {
          provenanceId: legacyIdValue,
          legacyProvenanceId: admin.firestore.FieldValue.delete(),
        });
        batchCount++;
        totalUpdated++;

        // Commit batch if at limit
        if (batchCount >= MAX_BATCH_SIZE) {
          await batch.commit();
          console.log(`    ✅ Committed batch of ${batchCount} documents`);
          batch = db.batch(); // Create new batch
          batchCount = 0;
        }
      }
    }

    // Commit remaining batch
    if (!isDryRun && batchCount > 0) {
      try {
        await batch.commit();
        console.log(`    ✅ Committed final batch of ${batchCount} documents`);
      } catch (error) {
        console.error(`    ❌ Error committing batch: ${error.message}`);
        totalErrors += batchCount;
        totalUpdated -= batchCount;
      }
    }
  }

  return { totalUpdated, totalSkipped, totalErrors };
}

async function main() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  legacyProvenanceId → provenanceId Migration Script');
  console.log('════════════════════════════════════════════════════════════');
  console.log(`  Mode: ${isDryRun ? '🔍 DRY RUN (no changes)' : '🚀 EXECUTE'}`);
  console.log(`  Target: ${isProduction ? '🔴 PRODUCTION' : '🟢 Emulator/Development'}`);
  console.log('════════════════════════════════════════════════════════════');

  if (!isDryRun && isProduction) {
    console.log('\n⚠️  WARNING: You are about to modify PRODUCTION data!');
    console.log('    Press Ctrl+C within 5 seconds to abort...\n');
    await new Promise(resolve => setTimeout(resolve, 5000));
  }

  try {
    // 1. Migrate genet documents
    const genetResults = await migrateGenets();
    
    // 2. Migrate counter collection
    const counterResults = await migrateCounterCollection();
    
    // 3. Migrate alias index entries
    const aliasResults = await migrateAliasIndexEntries();

    // Summary
    console.log('\n════════════════════════════════════════════════════════════');
    console.log('  MIGRATION SUMMARY');
    console.log('════════════════════════════════════════════════════════════');
    console.log(`  Genets:`);
    console.log(`    Updated: ${genetResults.totalUpdated}`);
    console.log(`    Skipped: ${genetResults.totalSkipped}`);
    console.log(`    Errors:  ${genetResults.totalErrors}`);
    console.log(`  Counter Collection:`);
    console.log(`    Migrated: ${counterResults.migrated}`);
    console.log(`    Errors:   ${counterResults.errors}`);
    console.log(`  Alias Entries:`);
    console.log(`    Updated: ${aliasResults.totalUpdated}`);
    console.log(`    Skipped: ${aliasResults.totalSkipped}`);
    console.log(`    Errors:  ${aliasResults.totalErrors}`);
    console.log('════════════════════════════════════════════════════════════');

    if (isDryRun) {
      console.log('\n✅ Dry run complete. Run with --execute to apply changes.');
    } else {
      console.log('\n✅ Migration complete!');
    }

  } catch (error) {
    console.error('\n❌ Migration failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

main().then(() => process.exit(0));
