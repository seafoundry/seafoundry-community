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

// Parse arguments
for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' || args[i] === '-l') {
        options.limit = parseInt(args[++i]);
    } else if (args[i] === '--batch-size') {
        options.batchSize = parseInt(args[++i]);
    }
}

// Move event types to process
const MOVE_EVENT_TYPES = ['event_move_in', 'event_move_out'];

// Show help
if (options.help) {
    console.log(`
🔄 SeaFoundry Move Events Migration: Update snapshotData.createdEvent.recordModelType

This migration script updates the recordModelType field in snapshotData.createdEvent
for move events (event_move_in and event_move_out), setting it to snapshotData.modelType.

Usage: npm run migrate:moveEvents [options]

Options:
  --dry-run, -d               Preview changes without updating
  --backup, -b                Create backup file of original events
  --force, -f                 Skip confirmation prompt
  --verbose, -v               Show detailed output
  --limit, -l <number>        Limit number of events to process
  --batch-size <number>       Batch size for updates (default: 500)
  --help, -h                  Show this help message

The script will:
1. Fetch events with eventTypeId in ['event_move_in', 'event_move_out']
2. For each event with snapshotData:
   - Set snapshotData.createdEvent.recordModelType = snapshotData.modelType
3. Skip events without snapshotData or where the field is already set
4. Update events in batches for efficiency

Examples:
  # Dry run to preview changes
  npm run migrate:moveEvents --dry-run

  # Run the actual migration
  npm run migrate:moveEvents

  # Run with backup
  npm run migrate:moveEvents --backup

  # Verbose output with limited events
  npm run migrate:moveEvents --limit 100 --verbose --dry-run
`);
    process.exit(0);
}

// Stats tracking
const stats = {
    totalEvents: 0,
    eventsWithSnapshotData: 0,
    eventsUpdated: 0,
    eventsSkipped: 0,
    eventsByType: {
        'event_move_in': { total: 0, updated: 0, skipped: 0, alreadySet: 0 },
        'event_move_out': { total: 0, updated: 0, skipped: 0, alreadySet: 0 }
    },
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
    const backupFile = path.join(backupDir, `moveEvents_migration_${timestamp}.json`);

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

// Process a batch of events
async function processEventBatch(events) {
    const updates = [];
    
    for (const event of events) {
        const eventData = event.data();
        const eventType = eventData.eventTypeId;
        
        // Update type-specific stats
        if (stats.eventsByType[eventType]) {
            stats.eventsByType[eventType].total++;
        }
        
        // Check if event has snapshotData
        if (!eventData.snapshotData) {
            stats.eventsSkipped++;
            if (stats.eventsByType[eventType]) {
                stats.eventsByType[eventType].skipped++;
            }
            
            if (options.verbose) {
                console.log(`  ⏭️  Event ${event.id} (${eventType}) has no snapshotData`);
            }
            continue;
        }
        
        stats.eventsWithSnapshotData++;
        
        // Check if snapshotData has createdEvent
        if (!eventData.snapshotData.createdEvent) {
            stats.eventsSkipped++;
            if (stats.eventsByType[eventType]) {
                stats.eventsByType[eventType].skipped++;
            }
            
            if (options.verbose) {
                console.log(`  ⏭️  Event ${event.id} (${eventType}) snapshotData has no createdEvent`);
            }
            continue;
        }
        
        // Check if already has recordModelType
        if (eventData.snapshotData.createdEvent.recordModelType) {
            if (stats.eventsByType[eventType]) {
                stats.eventsByType[eventType].alreadySet++;
            }
            
            if (options.verbose) {
                console.log(`  ⏭️  Event ${event.id} (${eventType}) already has snapshotData.createdEvent.recordModelType: ${eventData.snapshotData.createdEvent.recordModelType}`);
            }
            continue;
        }
        
        // Get modelType from snapshotData
        const modelType = eventData.snapshotData.modelType;
        
        if (!modelType) {
            stats.errors.push({
                eventId: event.id,
                error: 'snapshotData.modelType is missing'
            });
            
            if (options.verbose) {
                console.log(`  ⚠️  Event ${event.id} (${eventType}) snapshotData has no modelType`);
            }
            continue;
        }
        
        // Add to updates list
        updates.push({
            ref: event.ref,
            id: event.id,
            eventType: eventType,
            modelType: modelType,
            currentSnapshotData: eventData.snapshotData
        });
        
        if (stats.eventsByType[eventType]) {
            stats.eventsByType[eventType].updated++;
        }
        
        if (options.verbose) {
            console.log(`  ✓ Event ${event.id} (${eventType}) needs update: snapshotData.createdEvent.recordModelType → "${modelType}"`);
        }
    }
    
    return updates;
}

async function main() {
    try {
        console.log('🚀 Starting Move Events Migration: Updating snapshotData.createdEvent.recordModelType...');
        console.log(`📂 Event types to process: ${MOVE_EVENT_TYPES.join(', ')}`);
        
        if (options.dryRun) {
            console.log('🔬 DRY RUN MODE - No changes will be made');
        }
        
        if (options.limit) {
            console.log(`📊 Processing first ${options.limit} events only`);
        }
        
        console.log('');

        // Build query for move events
        let query = db.collection('events')
            .where('eventTypeId', 'in', MOVE_EVENT_TYPES);
        
        if (options.limit) {
            query = query.limit(options.limit);
        }

        // Fetch move events
        console.log('🔎 Fetching move events...');
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            console.log('⚠️  No move events found');
            process.exit(0);
        }

        stats.totalEvents = snapshot.size;
        console.log(`📊 Found ${stats.totalEvents} move events to process`);
        
        // Show breakdown by type
        const typeBreakdown = {};
        snapshot.docs.forEach(doc => {
            const eventType = doc.data().eventTypeId;
            typeBreakdown[eventType] = (typeBreakdown[eventType] || 0) + 1;
        });
        
        console.log('  Event type breakdown:');
        Object.entries(typeBreakdown).forEach(([type, count]) => {
            console.log(`    ${type}: ${count}`);
        });
        
        console.log('');

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
            
            console.log(`  ✅ Batch ${batchNumber} complete: ${batchUpdates.length} events to update`);
        }

        stats.eventsUpdated = allUpdates.length;
        console.log('\n');
        
        // Show migration summary
        if (allUpdates.length > 0) {
            console.log('📋 Migration Summary:');
            console.log(`  Total move events: ${stats.totalEvents}`);
            console.log(`  Events with snapshotData: ${stats.eventsWithSnapshotData}`);
            console.log(`  Events to update: ${allUpdates.length}`);
            console.log(`  Events skipped: ${stats.eventsSkipped}`);
            
            console.log('\n  Breakdown by event type:');
            Object.entries(stats.eventsByType).forEach(([type, typeStats]) => {
                if (typeStats.total > 0) {
                    console.log(`    ${type}:`);
                    console.log(`      Total: ${typeStats.total}`);
                    console.log(`      To update: ${typeStats.updated}`);
                    console.log(`      Already set: ${typeStats.alreadySet}`);
                    console.log(`      Skipped: ${typeStats.skipped}`);
                }
            });
            
            if (options.verbose && allUpdates.length > 0) {
                console.log('\n  Sample of updates (first 5):');
                allUpdates.slice(0, 5).forEach(update => {
                    console.log(`    Event ${update.id} (${update.eventType}): snapshotData.createdEvent.recordModelType → "${update.modelType}"`);
                });
                
                if (allUpdates.length > 5) {
                    console.log(`    ... and ${allUpdates.length - 5} more`);
                }
            }
            
            if (stats.errors.length > 0) {
                console.log(`\n  ⚠️  Errors encountered: ${stats.errors.length}`);
                if (options.verbose) {
                    stats.errors.slice(0, 5).forEach(err => {
                        console.log(`    Event ${err.eventId}: ${err.error}`);
                    });
                    
                    if (stats.errors.length > 5) {
                        console.log(`    ... and ${stats.errors.length - 5} more`);
                    }
                }
            }
        } else {
            console.log('✅ No move events need updating - all already have snapshotData.createdEvent.recordModelType set or lack required data');
            process.exit(0);
        }

        // Create backup if requested
        if (options.backup && !options.dryRun && allUpdates.length > 0) {
            console.log('\n📦 Creating backup...');
            const backupData = allUpdates.map(update => ({
                id: update.id,
                eventType: update.eventType,
                snapshotData: update.currentSnapshotData
            }));
            await createBackup(backupData);
        }

        // Confirmation
        if (!options.force && !options.dryRun && allUpdates.length > 0) {
            const confirmed = await promptConfirmation(
                `\n⚠️  This will update ${allUpdates.length} move events. Continue? (y/n): `
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
                    // Use dot notation to update deeply nested field
                    batch.update(update.ref, {
                        'snapshotData.createdEvent.recordModelType': update.modelType
                    });
                });
                
                await batch.commit();
                totalUpdated += batchUpdates.length;
                
                const batchNumber = Math.floor(i / options.batchSize) + 1;
                const totalBatches = Math.ceil(allUpdates.length / options.batchSize);
                console.log(`  ✅ Update batch ${batchNumber}/${totalBatches}: ${batchUpdates.length} events (${totalUpdated}/${allUpdates.length})`);
            }
            
            console.log(`\n✅ Successfully updated ${totalUpdated} move events`);
        } else if (options.dryRun) {
            console.log('\n✅ Dry run completed - no changes made');
        }

        // Final summary
        console.log('\n📊 Final Statistics:');
        console.log(`  Total move events processed: ${stats.totalEvents}`);
        console.log(`  Events with snapshotData: ${stats.eventsWithSnapshotData}`);
        console.log(`  Events updated: ${options.dryRun ? 0 : stats.eventsUpdated}`);
        console.log(`  Events skipped: ${stats.eventsSkipped}`);
        
        if (stats.errors.length > 0) {
            console.log(`  Errors encountered: ${stats.errors.length}`);
        }

        // Save detailed report if there were updates or errors
        if ((stats.eventsUpdated > 0 || stats.errors.length > 0) && !options.dryRun) {
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const reportDir = path.join(process.cwd(), 'migration-reports');
            const reportFile = path.join(reportDir, `moveEvents_migration_${timestamp}.json`);
            
            try {
                await fs.mkdir(reportDir, { recursive: true });
                await fs.writeFile(reportFile, JSON.stringify({
                    timestamp: new Date().toISOString(),
                    eventTypes: MOVE_EVENT_TYPES,
                    stats: stats,
                    errors: stats.errors
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

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

// Run the migration
main();