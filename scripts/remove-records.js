#!/usr/bin/env node

const { db, config } = require('./config-json');
const readline = require('readline');
const fs = require('fs').promises;
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
    collection: null,
    where: [],
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
    if (args[i] === '--collection' || args[i] === '-c') {
        options.collection = args[++i];
    } else if (args[i] === '--where' || args[i] === '-w') {
        options.where.push(args[++i]);
    } else if (args[i] === '--limit' || args[i] === '-l') {
        options.limit = parseInt(args[++i]);
    } else if (args[i] === '--batch-size') {
        options.batchSize = parseInt(args[++i]);
    }
}

// Show help
if (options.help || !options.collection || options.where.length === 0) {
    console.log(`
🗑️  SeaFoundry Firestore Record Remover

Deletes Firestore records based on query conditions.

Usage: npm run remove-records -- --collection <collection> --where <condition> [options]

Required:
  --collection, -c <name>     Collection to delete from (e.g., events, corals, sites)
  --where, -w <field:value>   Query condition (can be repeated for multiple conditions)

Options:
  --dry-run, -d               Preview deletions without removing (DEFAULT if not specified)
  --backup, -b                Create backup file before deletion
  --force, -f                 Skip confirmation prompt
  --verbose, -v               Show detailed output
  --limit, -l <number>        Limit number of records to delete
  --batch-size <number>       Batch size for deletions (default: 500)
  --help, -h                  Show this help message

Where Clause Formats:
  field:value                 Exact match (e.g., eventTypeId:event_move_in)
  field:>value               Greater than (e.g., createdAt:>2024-01-01)
  field:<value               Less than
  field:>=value              Greater than or equal
  field:<=value              Less than or equal
  field:!=value              Not equal
  field:in:[val1,val2]       In array (e.g., eventTypeId:in:[event_move_in,event_move_out])
  field:contains:value        Array contains (for array fields)

Examples:
  # Delete move events (dry run by default)
  npm run remove-records -- -c events -w "eventTypeId:in:[event_move_in,event_move_out]"

  # Actually delete (requires explicit --force or confirmation)
  npm run remove-records -- -c events -w "eventTypeId:in:[event_move_in,event_move_out]" --force

  # Multiple conditions (AND logic)
  npm run remove-records -- -c events -w "eventTypeId:event_move_in" -w "recordId:coral_123"

  # Delete with backup
  npm run remove-records -- -c events -w "eventTypeId:in:[event_move_in,event_move_out]" --backup

  # Verbose dry run
  npm run remove-records -- -c events -w "eventTypeId:event_move_in" --dry-run --verbose

  # Delete first 10 matching records
  npm run remove-records -- -c events -w "eventTypeId:event_move_in" --limit 10 --force

⚠️  SAFETY: By default, this runs in dry-run mode. To actually delete records, you must:
   1. Remove the --dry-run flag, AND
   2. Either use --force or confirm the prompt
`);
    process.exit(0);
}

// Default to dry run for safety
if (!args.includes('--force') && !args.includes('-f') && 
    !args.includes('--dry-run') && !args.includes('-d')) {
    options.dryRun = true;
    console.log('⚠️  No --force flag detected, defaulting to --dry-run mode for safety');
}

// Parse where clause
function parseWhereClause(whereStr) {
    // Check for special operators first (order matters!)
    const operators = ['in:', 'contains:', '>=', '<=', '!=', '>', '<', ':'];
    let operator = '==';
    let field, value;

    for (const op of operators) {
        if (whereStr.includes(op)) {
            const parts = whereStr.split(op);
            field = parts[0];
            value = parts.slice(1).join(op);
            
            if (op === ':') {
                operator = '==';
            } else if (op === 'in:') {
                operator = 'in';
                // Parse array value
                value = value.replace(/^\[/, '').replace(/\]$/, '').split(',').map(v => v.trim());
            } else if (op === 'contains:') {
                operator = 'array-contains';
            } else {
                operator = op;
            }
            break;
        }
    }

    // Convert value to appropriate type
    if (value === 'true') value = true;
    else if (value === 'false') value = false;
    else if (value === 'null') value = null;
    else if (!Array.isArray(value) && !isNaN(value) && value !== '') value = Number(value);

    return { field, operator, value };
}

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
async function createBackup(collection, records) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(process.cwd(), 'backups');
    const backupFile = path.join(backupDir, `${collection}_deletion_${timestamp}.json`);

    try {
        await fs.mkdir(backupDir, { recursive: true });
        await fs.writeFile(backupFile, JSON.stringify(records, null, 2));
        console.log(`📁 Backup saved to: ${backupFile}`);
        return backupFile;
    } catch (error) {
        console.error('❌ Failed to create backup:', error.message);
        throw error;
    }
}

// Create deletion report
async function createDeletionReport(collection, deletedIds, whereConditions) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const reportDir = path.join(process.cwd(), 'deletion-reports');
    const reportFile = path.join(reportDir, `deletion_${collection}_${timestamp}.json`);

    try {
        await fs.mkdir(reportDir, { recursive: true });
        await fs.writeFile(reportFile, JSON.stringify({
            timestamp: new Date().toISOString(),
            collection: collection,
            conditions: whereConditions,
            deletedCount: deletedIds.length,
            deletedIds: deletedIds,
            dryRun: options.dryRun
        }, null, 2));
        console.log(`📄 Deletion report saved to: ${reportFile}`);
        return reportFile;
    } catch (error) {
        console.error('⚠️  Failed to save deletion report:', error.message);
    }
}

async function main() {
    try {
        console.log('🗑️  Starting Firestore Record Remover...');
        console.log(`📂 Collection: ${options.collection}`);
        console.log(`🔍 Where clauses: ${options.where.join(' AND ')}`);
        
        if (options.dryRun) {
            console.log('🔬 DRY RUN MODE - No records will be deleted');
        } else {
            console.log('⚠️  DELETION MODE - Records will be permanently removed');
        }
        
        console.log('');

        // Parse clauses
        const whereClauses = options.where.map(parseWhereClause);

        // Build query
        let query = db.collection(options.collection);
        
        for (const where of whereClauses) {
            if (options.verbose) {
                console.log(`  Adding where clause: ${where.field} ${where.operator} ${JSON.stringify(where.value)}`);
            }
            query = query.where(where.field, where.operator, where.value);
        }

        if (options.limit) {
            query = query.limit(options.limit);
        }

        // Get matching documents
        console.log('🔎 Fetching matching records...');
        const snapshot = await query.get();
        
        if (snapshot.empty) {
            console.log('✅ No matching records found - nothing to delete');
            process.exit(0);
        }

        console.log(`📊 Found ${snapshot.size} matching records to delete`);

        // Collect record IDs and data for reporting
        const recordsToDelete = [];
        const idsToDelete = [];
        
        snapshot.docs.forEach(doc => {
            const data = doc.data();
            recordsToDelete.push({
                id: doc.id,
                data: data
            });
            idsToDelete.push(doc.id);
        });

        // Show sample of records to be deleted
        console.log('\n📋 Sample of records to delete (first 10):');
        recordsToDelete.slice(0, 10).forEach(record => {
            console.log(`  - ID: ${record.id}`);
            if (options.verbose) {
                // Show key fields for context
                const keyFields = ['eventTypeId', 'recordId', 'modelType', 'name', 'createdAt'];
                const displayFields = {};
                keyFields.forEach(field => {
                    if (record.data[field] !== undefined) {
                        displayFields[field] = record.data[field];
                    }
                });
                if (Object.keys(displayFields).length > 0) {
                    console.log(`    ${JSON.stringify(displayFields)}`);
                }
            }
        });
        
        if (snapshot.size > 10) {
            console.log(`  ... and ${snapshot.size - 10} more records`);
        }

        // Show deletion summary
        console.log('\n⚠️  DELETION SUMMARY:');
        console.log(`  Collection: ${options.collection}`);
        console.log(`  Total records to delete: ${snapshot.size}`);
        console.log(`  Conditions: ${options.where.join(' AND ')}`);
        
        // Additional safety warning for large deletions
        if (snapshot.size > 100 && !options.dryRun) {
            console.log('\n🚨 WARNING: This is a large deletion operation!');
        }

        // Confirmation
        if (!options.force && !options.dryRun) {
            const confirmed = await promptConfirmation(
                `\n⚠️  This will PERMANENTLY DELETE ${snapshot.size} records. Are you sure? (y/n): `
            );
            
            if (!confirmed) {
                console.log('❌ Deletion cancelled');
                process.exit(0);
            }

            // Double confirmation for large deletions
            if (snapshot.size > 100) {
                const doubleConfirmed = await promptConfirmation(
                    `\n🚨 This is a large deletion (${snapshot.size} records). Type 'yes' to confirm again: `
                );
                
                if (!doubleConfirmed) {
                    console.log('❌ Deletion cancelled');
                    process.exit(0);
                }
            }
        }

        // Create backup if requested
        if (options.backup && !options.dryRun) {
            console.log('\n📦 Creating backup...');
            await createBackup(options.collection, recordsToDelete);
        }

        // Perform deletions
        if (!options.dryRun) {
            console.log('\n🚀 Performing deletions...');
            
            // Process in batches
            const docs = snapshot.docs;
            let totalDeleted = 0;
            
            for (let i = 0; i < docs.length; i += options.batchSize) {
                const batch = db.batch();
                const batchDocs = docs.slice(i, Math.min(i + options.batchSize, docs.length));
                
                batchDocs.forEach(doc => {
                    batch.delete(doc.ref);
                });
                
                await batch.commit();
                totalDeleted += batchDocs.length;
                
                const batchNumber = Math.floor(i / options.batchSize) + 1;
                const totalBatches = Math.ceil(docs.length / options.batchSize);
                console.log(`  ✅ Batch ${batchNumber}/${totalBatches}: Deleted ${batchDocs.length} records (${totalDeleted}/${snapshot.size})`);
            }
            
            console.log(`\n✅ Successfully deleted ${totalDeleted} records`);
            
            // Create deletion report
            await createDeletionReport(options.collection, idsToDelete, whereClauses);
        } else {
            console.log('\n✅ Dry run completed - no records were deleted');
            
            // Create dry run report
            await createDeletionReport(options.collection, idsToDelete, whereClauses);
        }

        // Summary
        console.log('\n📊 Deletion Summary:');
        console.log(`  Collection: ${options.collection}`);
        console.log(`  Records matched: ${snapshot.size}`);
        console.log(`  Records deleted: ${options.dryRun ? 0 : snapshot.size}`);
        console.log(`  Mode: ${options.dryRun ? 'DRY RUN' : 'DELETION COMPLETED'}`);

    } catch (error) {
        console.error('❌ Deletion failed:', error.message);
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

// Run the remover
main();