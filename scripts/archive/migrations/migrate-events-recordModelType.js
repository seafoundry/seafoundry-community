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
    limit: null,
    batchSize: 500
};

// Parse limit if provided
for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' || args[i] === '-l') {
        options.limit = parseInt(args[++i]);
    } else if (args[i] === '--batch-size') {
        options.batchSize = parseInt(args[++i]);
    }
}

// Show help
if (options.help) {
    console.log(`
🔄 SeaFoundry Events Migration: Add recordModelType

This migration script adds the recordModelType field to all events by looking up
their corresponding records in the various collections.

Usage: npm run migrate:events [options]

Options:
  --dry-run, -d               Preview changes without updating
  --backup, -b                Create backup file of original events
  --force, -f                 Skip confirmation prompt
  --verbose, -v               Show detailed output
  --limit, -l <number>        Limit number of events to process
  --batch-size <number>       Batch size for updates (default: 500)
  --help, -h                  Show this help message

The script will:
1. Fetch all events from the 'events' collection
2. For each event, look up the record with id = event.recordId in:
   - organizations
   - sites
   - groups
   - corals
   - genets
3. Add recordModelType field with the found record's modelType
4. Update the event in Firestore

Examples:
  # Dry run to preview changes
  npm run migrate:events --dry-run

  # Run the actual migration
  npm run migrate:events

  # Run with backup
  npm run migrate:events --backup

  # Process only first 100 events (useful for testing)
  npm run migrate:events --limit 100 --dry-run
`);
    process.exit(0);
}

// Collections to search for records
const RECORD_COLLECTIONS = [
    'organizations',
    'sites',
    'groups',
    'corals',
    'genets'
];

// Cache for found records to avoid duplicate lookups
const recordCache = new Map();

// Stats tracking
const stats = {
    totalEvents: 0,
    eventsWithRecords: 0,
    eventsWithoutRecords: 0,
    eventsByModelType: {},
    missingRecordIds: [],
    errors: []
};

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

// Create backup file
async function createBackup(events) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(process.cwd(), 'backups');
    const backupFile = path.join(backupDir, `events_migration_${timestamp}.json`);

    try {
        await fs.mkdir(backupDir, { recursive: true });
        await fs.writeFile(backupFile, JSON.stringify(events, null, 2));
        console.log(`📁 Backup saved to: ${backupFile}`);
        return backupFile;
    } catch (error) {
        console.error('❌ Failed to create backup:', error.message);
        throw error;
    }
}

// Look up a record by ID across all collections
async function findRecord(recordId) {
    // Check cache first
    if (recordCache.has(recordId)) {
        return recordCache.get(recordId);
    }

    // Search each collection
    for (const collectionName of RECORD_COLLECTIONS) {
        try {
            const doc = await db.collection(collectionName).doc(recordId).get();
            
            if (doc.exists) {
                const record = {
                    id: doc.id,
                    data: doc.data(),
                    collection: collectionName,
                    modelType: doc.data().modelType || collectionName.slice(0, -1) // Remove 's' from plural
                };
                
                // Cache the result
                recordCache.set(recordId, record);
                
                if (options.verbose) {
                    console.log(`  ✓ Found record ${recordId} in ${collectionName} (modelType: ${record.modelType})`);
                }
                
                return record;
            }
        } catch (error) {
            // Continue to next collection if this one fails
            if (options.verbose) {
                console.log(`  ⚠️  Error checking ${collectionName} for ${recordId}: ${error.message}`);
            }
        }
    }

    // Record not found in any collection
    recordCache.set(recordId, null);
    return null;
}

// Process a batch of events
async function processEventBatch(events) {
    const updates = [];
    
    for (const event of events) {
        const eventData = event.data();
        const recordId = eventData.recordId;
        
        if (!recordId) {
            console.warn(`⚠️  Event ${event.id} has no recordId`);
            stats.errors.push({ eventId: event.id, error: 'No recordId' });
            continue;
        }

        // Skip if already has recordModelType
        if (eventData.recordModelType) {
            if (options.verbose) {
                console.log(`  ⏭️  Event ${event.id} already has recordModelType: ${eventData.recordModelType}`);
            }
            continue;
        }

        // Look up the record
        const record = await findRecord(recordId);
        
        if (record) {
            stats.eventsWithRecords++;
            stats.eventsByModelType[record.modelType] = (stats.eventsByModelType[record.modelType] || 0) + 1;
            
            updates.push({
                ref: event.ref,
                data: { recordModelType: record.modelType },
                eventId: event.id,
                recordId: recordId,
                modelType: record.modelType
            });
        } else {
            stats.eventsWithoutRecords++;
            stats.missingRecordIds.push(recordId);
            
            if (options.verbose) {
                console.log(`  ❌ No record found for event ${event.id} with recordId: ${recordId}`);
            }
        }
    }
    
    return updates;
}

async function main() {
    try {
        console.log('🚀 Starting Events Migration: Adding recordModelType...');
        console.log('📂 Collections to search: ' + RECORD_COLLECTIONS.join(', '));
        
        if (options.dryRun) {
            console.log('🔬 DRY RUN MODE - No changes will be made');
        }
        
        console.log('');

        // Build query for events
        let query = db.collection('events');
        
        if (options.limit) {
            query = query.limit(options.limit);
            console.log(`📊 Processing first ${options.limit} events only`);
        }

        // Fetch all events
        console.log('🔎 Fetching events...');
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            console.log('⚠️  No events found in the collection');
            process.exit(0);
        }

        stats.totalEvents = snapshot.size;
        console.log(`📊 Found ${stats.totalEvents} events to process`);
        console.log('');

        // Create backup if requested
        if (options.backup && !options.dryRun) {
            console.log('📦 Creating backup...');
            const backupData = snapshot.docs.map(doc => ({
                id: doc.id,
                data: doc.data()
            }));
            await createBackup(backupData);
            console.log('');
        }

        // Process events in batches
        console.log('🔄 Processing events...');
        const docs = snapshot.docs;
        const allUpdates = [];
        
        for (let i = 0; i < docs.length; i += options.batchSize) {
            const batchDocs = docs.slice(i, Math.min(i + options.batchSize, docs.length));
            const batchNumber = Math.floor(i / options.batchSize) + 1;
            const totalBatches = Math.ceil(docs.length / options.batchSize);
            
            console.log(`\n📦 Processing batch ${batchNumber}/${totalBatches} (${batchDocs.length} events)...`);
            
            const batchUpdates = await processEventBatch(batchDocs);
            allUpdates.push(...batchUpdates);
            
            // Show progress
            console.log(`  ✅ Batch ${batchNumber} complete: ${batchUpdates.length} events to update`);
        }

        console.log('\n');
        
        // Show what will be updated
        if (allUpdates.length > 0) {
            console.log('📋 Migration Summary:');
            console.log(`  Total events: ${stats.totalEvents}`);
            console.log(`  Events to update: ${allUpdates.length}`);
            console.log(`  Events with found records: ${stats.eventsWithRecords}`);
            console.log(`  Events with missing records: ${stats.eventsWithoutRecords}`);
            
            if (Object.keys(stats.eventsByModelType).length > 0) {
                console.log('\n  Records found by type:');
                for (const [modelType, count] of Object.entries(stats.eventsByModelType)) {
                    console.log(`    ${modelType}: ${count}`);
                }
            }
            
            if (options.verbose && allUpdates.length > 0) {
                console.log('\n  Sample of updates (first 5):');
                allUpdates.slice(0, 5).forEach(update => {
                    console.log(`    Event ${update.eventId}: recordModelType → "${update.modelType}"`);
                });
                
                if (allUpdates.length > 5) {
                    console.log(`    ... and ${allUpdates.length - 5} more`);
                }
            }
            
            if (stats.missingRecordIds.length > 0 && options.verbose) {
                console.log(`\n  ⚠️  Missing record IDs (first 10):`);
                stats.missingRecordIds.slice(0, 10).forEach(id => {
                    console.log(`    - ${id}`);
                });
                
                if (stats.missingRecordIds.length > 10) {
                    console.log(`    ... and ${stats.missingRecordIds.length - 10} more`);
                }
            }
        } else {
            console.log('✅ No events need updating - all events already have recordModelType or have no valid records');
            process.exit(0);
        }

        // Confirmation
        if (!options.force && !options.dryRun && allUpdates.length > 0) {
            const confirmed = await promptConfirmation(
                `\n⚠️  This will update ${allUpdates.length} events. Continue? (y/n): `
            );
            
            if (!confirmed) {
                console.log('❌ Migration cancelled');
                process.exit(0);
            }
        }

        // Perform updates
        if (!options.dryRun && allUpdates.length > 0) {
            console.log('\n🚀 Applying updates...');
            
            let totalUpdated = 0;
            
            // Process updates in batches
            for (let i = 0; i < allUpdates.length; i += options.batchSize) {
                const batch = db.batch();
                const batchUpdates = allUpdates.slice(i, Math.min(i + options.batchSize, allUpdates.length));
                
                batchUpdates.forEach(update => {
                    batch.update(update.ref, update.data);
                });
                
                await batch.commit();
                totalUpdated += batchUpdates.length;
                
                const batchNumber = Math.floor(i / options.batchSize) + 1;
                const totalBatches = Math.ceil(allUpdates.length / options.batchSize);
                console.log(`  ✅ Update batch ${batchNumber}/${totalBatches}: ${batchUpdates.length} events (${totalUpdated}/${allUpdates.length})`);
            }
            
            console.log(`\n✅ Successfully updated ${totalUpdated} events`);
        } else if (options.dryRun) {
            console.log('\n✅ Dry run completed - no changes made');
        }

        // Final summary
        console.log('\n📊 Final Statistics:');
        console.log(`  Total events processed: ${stats.totalEvents}`);
        console.log(`  Events updated: ${options.dryRun ? 0 : allUpdates.length}`);
        console.log(`  Events with found records: ${stats.eventsWithRecords}`);
        console.log(`  Events with missing records: ${stats.eventsWithoutRecords}`);
        
        if (stats.errors.length > 0) {
            console.log(`  Errors encountered: ${stats.errors.length}`);
        }

        // Save missing records report if there are any
        if (stats.missingRecordIds.length > 0 && !options.dryRun) {
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const reportDir = path.join(process.cwd(), 'migration-reports');
            const reportFile = path.join(reportDir, `missing_records_${timestamp}.json`);
            
            try {
                await fs.mkdir(reportDir, { recursive: true });
                await fs.writeFile(reportFile, JSON.stringify({
                    timestamp: new Date().toISOString(),
                    missingRecordIds: stats.missingRecordIds,
                    errors: stats.errors,
                    stats: stats
                }, null, 2));
                console.log(`\n📄 Missing records report saved to: ${reportFile}`);
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

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

// Run the migration
main();