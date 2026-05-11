#!/usr/bin/env node

const { db, config } = require('./config-json');
const readline = require('readline');
const fs = require('fs').promises;
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
    dryRun: args.includes('--dry-run') || args.includes('-d'),
    backup: args.includes('--backup') || args.includes('-b'),
    force: args.includes('--force') || args.includes('-f'),
    verbose: args.includes('--verbose') || args.includes('-v'),
    help: args.includes('--help') || args.includes('-h'),
    collections: null,
    limit: null,
    batchSize: 500
};

// Parse arguments
for (let i = 0; i < args.length; i++) {
    if (args[i] === '--collections' || args[i] === '-c') {
        options.collections = args[++i].split(',').map(c => c.trim());
    } else if (args[i] === '--limit' || args[i] === '-l') {
        options.limit = parseInt(args[++i]);
    } else if (args[i] === '--batch-size') {
        options.batchSize = parseInt(args[++i]);
    }
}

// Default collections to process
const DEFAULT_COLLECTIONS = [
    'organizations',
    'sites',
    'groups',
    'corals',
    'genets'
];

// Use specified collections or default
const collectionsToProcess = options.collections || DEFAULT_COLLECTIONS;

// Show help
if (options.help) {
    console.log(`
🔄 SeaFoundry CreatedEvent Migration: Add recordModelType

This migration script adds the recordModelType field to createdEvent objects
in documents across multiple collections, setting it to the document's own modelType.

Usage: npm run migrate:createdEvent [options]

Options:
  --dry-run, -d               Preview changes without updating
  --backup, -b                Create backup files of original documents
  --force, -f                 Skip confirmation prompt
  --verbose, -v               Show detailed output
  --collections, -c <list>    Comma-separated list of collections to process
                              Default: ${DEFAULT_COLLECTIONS.join(',')}
  --limit, -l <number>        Limit number of documents per collection
  --batch-size <number>       Batch size for updates (default: 500)
  --help, -h                  Show this help message

The script will:
1. Process each specified collection
2. For documents with createdEvent, set createdEvent.recordModelType = doc.modelType
3. Skip documents without createdEvent or where recordModelType is already set
4. Update documents in batches for efficiency

Examples:
  # Dry run to preview changes
  npm run migrate:createdEvent --dry-run

  # Run the actual migration
  npm run migrate:createdEvent

  # Run with backup
  npm run migrate:createdEvent --backup

  # Process only specific collections
  npm run migrate:createdEvent --collections sites,groups

  # Process with limit for testing
  npm run migrate:createdEvent --limit 100 --dry-run --verbose
`);
    process.exit(0);
}

// Stats tracking per collection
const stats = {
    total: {
        documents: 0,
        withCreatedEvent: 0,
        updated: 0,
        skipped: 0,
        errors: 0
    },
    byCollection: {}
};

// Initialize collection stats
collectionsToProcess.forEach(collection => {
    stats.byCollection[collection] = {
        documents: 0,
        withCreatedEvent: 0,
        updated: 0,
        skipped: 0,
        alreadySet: 0,
        errors: []
    };
});

// Prompt for confirmation
async function promptConfirmation(message) {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });

    return new Promise((resolve) => {
        rl.question(message, (answer) => {
            rl.close();
            resolve(answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes');
        });
    });
}

// Create backup file for a collection
async function createBackup(collectionName, documents) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(process.cwd(), 'backups');
    const backupFile = path.join(backupDir, `${collectionName}_createdEvent_${timestamp}.json`);

    try {
        await fs.mkdir(backupDir, { recursive: true });
        await fs.writeFile(backupFile, JSON.stringify(documents, null, 2));
        console.log(`  📁 Backup saved to: ${backupFile}`);
        return backupFile;
    } catch (error) {
        console.error(`  ❌ Failed to create backup for ${collectionName}:`, error.message);
        throw error;
    }
}

// Process a single collection
async function processCollection(collectionName) {
    console.log(`\n📂 Processing collection: ${collectionName}`);
    const collectionStats = stats.byCollection[collectionName];
    
    try {
        // Build query
        let query = db.collection(collectionName);
        
        if (options.limit) {
            query = query.limit(options.limit);
        }

        // Fetch documents
        console.log(`  🔎 Fetching documents...`);
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            console.log(`  ⚠️  No documents found in ${collectionName}`);
            return;
        }

        collectionStats.documents = snapshot.size;
        stats.total.documents += snapshot.size;
        console.log(`  📊 Found ${snapshot.size} documents`);

        // Filter documents with createdEvent
        const docsWithCreatedEvent = [];
        const docsToUpdate = [];
        
        snapshot.docs.forEach(doc => {
            const data = doc.data();
            
            if (data.createdEvent) {
                collectionStats.withCreatedEvent++;
                stats.total.withCreatedEvent++;
                docsWithCreatedEvent.push({ id: doc.id, data });
                
                // Check if update is needed
                if (!data.createdEvent.recordModelType) {
                    // Get the modelType for this document
                    const modelType = data.modelType || collectionName.slice(0, -1); // Remove 's' from plural
                    
                    docsToUpdate.push({
                        ref: doc.ref,
                        id: doc.id,
                        modelType: modelType,
                        currentCreatedEvent: data.createdEvent
                    });
                    
                    if (options.verbose) {
                        console.log(`    ✓ Document ${doc.id} needs update: recordModelType → "${modelType}"`);
                    }
                } else {
                    collectionStats.alreadySet++;
                    if (options.verbose) {
                        console.log(`    ⏭️  Document ${doc.id} already has createdEvent.recordModelType: ${data.createdEvent.recordModelType}`);
                    }
                }
            } else {
                collectionStats.skipped++;
                if (options.verbose) {
                    console.log(`    ⏭️  Document ${doc.id} has no createdEvent`);
                }
            }
        });

        console.log(`  📋 Documents with createdEvent: ${collectionStats.withCreatedEvent}`);
        console.log(`  🔄 Documents to update: ${docsToUpdate.length}`);
        console.log(`  ✓ Already set: ${collectionStats.alreadySet}`);
        console.log(`  ⏭️  Skipped (no createdEvent): ${collectionStats.skipped}`);

        // Create backup if requested and there are documents to update
        if (options.backup && docsToUpdate.length > 0 && !options.dryRun) {
            console.log(`  📦 Creating backup...`);
            await createBackup(collectionName, docsWithCreatedEvent);
        }

        // Perform updates if needed
        if (docsToUpdate.length > 0 && !options.dryRun) {
            console.log(`  🚀 Applying updates...`);
            
            // Process in batches
            for (let i = 0; i < docsToUpdate.length; i += options.batchSize) {
                const batch = db.batch();
                const batchDocs = docsToUpdate.slice(i, Math.min(i + options.batchSize, docsToUpdate.length));
                
                batchDocs.forEach(doc => {
                    // Use dot notation to update nested field
                    batch.update(doc.ref, {
                        'createdEvent.recordModelType': doc.modelType
                    });
                });
                
                await batch.commit();
                
                const batchNumber = Math.floor(i / options.batchSize) + 1;
                const totalBatches = Math.ceil(docsToUpdate.length / options.batchSize);
                console.log(`    ✅ Batch ${batchNumber}/${totalBatches}: Updated ${batchDocs.length} documents`);
            }
            
            collectionStats.updated = docsToUpdate.length;
            stats.total.updated += docsToUpdate.length;
            console.log(`  ✅ Successfully updated ${docsToUpdate.length} documents in ${collectionName}`);
        } else if (options.dryRun && docsToUpdate.length > 0) {
            console.log(`  🔬 Dry run - would update ${docsToUpdate.length} documents`);
            
            // Show sample updates
            if (options.verbose && docsToUpdate.length > 0) {
                console.log(`\n  Sample updates (first 5):`);
                docsToUpdate.slice(0, 5).forEach(doc => {
                    console.log(`    Document ${doc.id}: createdEvent.recordModelType → "${doc.modelType}"`);
                });
                
                if (docsToUpdate.length > 5) {
                    console.log(`    ... and ${docsToUpdate.length - 5} more`);
                }
            }
        }

    } catch (error) {
        console.error(`  ❌ Error processing ${collectionName}:`, error.message);
        collectionStats.errors.push(error.message);
        stats.total.errors++;
        
        if (options.verbose) {
            console.error(error.stack);
        }
    }
}

async function main() {
    try {
        console.log('🚀 Starting CreatedEvent Migration: Adding recordModelType...');
        console.log(`📂 Collections to process: ${collectionsToProcess.join(', ')}`);
        
        if (options.dryRun) {
            console.log('🔬 DRY RUN MODE - No changes will be made');
        }
        
        if (options.limit) {
            console.log(`📊 Processing first ${options.limit} documents per collection`);
        }

        // Process each collection
        for (const collection of collectionsToProcess) {
            await processCollection(collection);
        }

        // Show final summary
        console.log('\n' + '='.repeat(60));
        console.log('📊 Migration Summary:');
        console.log('='.repeat(60));
        
        console.log('\n🌍 Overall Statistics:');
        console.log(`  Total documents processed: ${stats.total.documents}`);
        console.log(`  Documents with createdEvent: ${stats.total.withCreatedEvent}`);
        console.log(`  Documents updated: ${options.dryRun ? 0 : stats.total.updated}`);
        console.log(`  Documents skipped: ${stats.total.documents - stats.total.withCreatedEvent}`);
        
        if (stats.total.errors > 0) {
            console.log(`  ⚠️  Errors encountered: ${stats.total.errors}`);
        }

        console.log('\n📋 Per-Collection Breakdown:');
        for (const [collection, collStats] of Object.entries(stats.byCollection)) {
            if (collStats.documents > 0) {
                console.log(`\n  ${collection}:`);
                console.log(`    Documents: ${collStats.documents}`);
                console.log(`    With createdEvent: ${collStats.withCreatedEvent}`);
                console.log(`    Updated: ${options.dryRun ? 0 : collStats.updated}`);
                console.log(`    Already set: ${collStats.alreadySet}`);
                console.log(`    Skipped: ${collStats.skipped}`);
                
                if (collStats.errors.length > 0) {
                    console.log(`    ⚠️  Errors: ${collStats.errors.length}`);
                }
            }
        }

        // Confirmation for actual run
        if (!options.dryRun && stats.total.updated === 0) {
            console.log('\n✅ No documents needed updating - all createdEvent.recordModelType fields are already set or no createdEvent exists');
        } else if (options.dryRun && stats.total.updated > 0) {
            console.log(`\n✅ Dry run completed - ${stats.total.updated} documents would be updated`);
            console.log('💡 Run without --dry-run to apply these changes');
        } else if (!options.dryRun) {
            console.log(`\n✅ Migration completed successfully - ${stats.total.updated} documents updated`);
        }

        // Save detailed report if there were any updates or errors
        if ((stats.total.updated > 0 || stats.total.errors > 0) && !options.dryRun) {
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const reportDir = path.join(process.cwd(), 'migration-reports');
            const reportFile = path.join(reportDir, `createdEvent_migration_${timestamp}.json`);
            
            try {
                await fs.mkdir(reportDir, { recursive: true });
                await fs.writeFile(reportFile, JSON.stringify({
                    timestamp: new Date().toISOString(),
                    collections: collectionsToProcess,
                    stats: stats
                }, null, 2));
                console.log(`\n📄 Migration report saved to: ${reportFile}`);
            } catch (error) {
                console.error('⚠️  Failed to save report:', error.message);
            }
        }

    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        if (options.verbose) {
            console.error(error.stack);
        }
        process.exit(1);
    }
}

// Prompt for confirmation before running if not in dry-run or force mode
async function confirmAndRun() {
    if (!options.force && !options.dryRun) {
        console.log('\n⚠️  This migration will update createdEvent.recordModelType in multiple collections.');
        console.log(`Collections to be modified: ${collectionsToProcess.join(', ')}`);
        
        const confirmed = await promptConfirmation('\nDo you want to continue? (y/n): ');
        
        if (!confirmed) {
            console.log('❌ Migration cancelled');
            process.exit(0);
        }
    }
    
    await main();
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

// Run the migration
confirmAndRun();