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
    set: [],
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
    } else if (args[i] === '--set' || args[i] === '-s') {
        options.set.push(args[++i]);
    } else if (args[i] === '--limit' || args[i] === '-l') {
        options.limit = parseInt(args[++i]);
    } else if (args[i] === '--batch-size') {
        options.batchSize = parseInt(args[++i]);
    }
}

// Show help
if (options.help || !options.collection || options.where.length === 0 || options.set.length === 0) {
    console.log(`
🔄 SeaFoundry Firestore Record Updater

Updates Firestore records based on query conditions.

Usage: npm run update-records -- --collection <collection> --where <condition> --set <field:value> [options]

Required:
  --collection, -c <name>     Collection to update (e.g., events, corals, sites)
  --where, -w <field:value>   Query condition (can be repeated for multiple conditions)
  --set, -s <field:value>     Field to update (can be repeated for multiple fields)

Options:
  --dry-run, -d               Preview changes without updating
  --backup, -b                Create backup file of original values
  --force, -f                 Skip confirmation prompt
  --verbose, -v               Show detailed output
  --limit, -l <number>        Limit number of records to update
  --batch-size <number>       Batch size for updates (default: 500)
  --help, -h                  Show this help message

Where Clause Formats:
  field:value                 Exact match (e.g., eventTypeId:cr)
  field:>value               Greater than (e.g., createdAt:>2024-01-01)
  field:<value               Less than
  field:>=value              Greater than or equal
  field:<=value              Less than or equal
  field:!=value              Not equal
  field:in:[val1,val2]       In array (e.g., status:in:[active,pending])
  field:contains:value        Array contains (for array fields)

Set Clause Formats:
  field:value                 Set to literal value
  field:now                   Set to current timestamp
  field:delete                Delete the field
  field:increment:n           Increment number field by n
  field:append:value          Append to array field
  field:remove:value          Remove from array field

Examples:
  # Update eventTypeId from 'cr' to 'event_create'
  npm run update-records -- -c events -w "eventTypeId:cr" -s "eventTypeId:event_create"

  # Multiple conditions and updates
  npm run update-records -- -c events -w "eventTypeId:cr" -w "recordId:coral_123" -s "eventTypeId:event_create" -s "updatedAt:now"

  # Dry run with verbose output
  npm run update-records -- -c events -w "eventTypeId:cr" -s "eventTypeId:event_create" --dry-run --verbose

  # Update with backup
  npm run update-records -- -c events -w "eventTypeId:cr" -s "eventTypeId:event_create" --backup

  # Update first 10 matching records
  npm run update-records -- -c events -w "eventTypeId:cr" -s "eventTypeId:event_create" --limit 10
`);
    process.exit(0);
}

// Parse where clause
function parseWhereClause(whereStr) {
    const operators = ['>=', '<=', '!=', '>', '<', ':', 'in:', 'contains:'];
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
    else if (!isNaN(value) && value !== '') value = Number(value);

    return { field, operator, value };
}

// Get nested value from object using dot notation path
function getNestedValue(obj, path) {
    const keys = path.split('.');
    let value = obj;
    
    for (const key of keys) {
        if (value && typeof value === 'object' && key in value) {
            value = value[key];
        } else {
            return undefined;
        }
    }
    
    return value;
}

// Parse set clause
function parseSetClause(setStr) {
    const colonIndex = setStr.indexOf(':');
    if (colonIndex === -1) {
        throw new Error(`Invalid set clause: ${setStr}`);
    }

    const field = setStr.substring(0, colonIndex);
    const valueStr = setStr.substring(colonIndex + 1);

    let value;
    let operation = 'set';

    if (valueStr === 'now') {
        value = new Date();
    } else if (valueStr === 'delete') {
        operation = 'delete';
        value = null;
    } else if (valueStr.startsWith('increment:')) {
        operation = 'increment';
        value = Number(valueStr.substring(10));
    } else if (valueStr.startsWith('append:')) {
        operation = 'append';
        value = valueStr.substring(7);
    } else if (valueStr.startsWith('remove:')) {
        operation = 'remove';
        value = valueStr.substring(7);
    } else {
        // Convert value to appropriate type
        if (valueStr === 'true') value = true;
        else if (valueStr === 'false') value = false;
        else if (valueStr === 'null') value = null;
        else if (!isNaN(valueStr) && valueStr !== '') value = Number(valueStr);
        else value = valueStr;
    }

    return { field, value, operation };
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
    const backupFile = path.join(backupDir, `${collection}_${timestamp}.json`);

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

// Apply updates to a document
function applyUpdates(doc, setClauses) {
    const updates = {};
    const deleteFields = [];

    for (const clause of setClauses) {
        if (clause.operation === 'delete') {
            deleteFields.push(clause.field);
        } else if (clause.operation === 'increment') {
            const currentValue = getNestedValue(doc, clause.field) || 0;
            updates[clause.field] = currentValue + clause.value;
        } else if (clause.operation === 'append') {
            const currentValue = getNestedValue(doc, clause.field) || [];
            if (Array.isArray(currentValue)) {
                updates[clause.field] = [...currentValue, clause.value];
            } else {
                console.warn(`⚠️  Field ${clause.field} is not an array, cannot append`);
            }
        } else if (clause.operation === 'remove') {
            const currentValue = getNestedValue(doc, clause.field) || [];
            if (Array.isArray(currentValue)) {
                updates[clause.field] = currentValue.filter(v => v !== clause.value);
            } else {
                console.warn(`⚠️  Field ${clause.field} is not an array, cannot remove`);
            }
        } else {
            updates[clause.field] = clause.value;
        }
    }

    // For Firestore, we need to use FieldValue.delete() for field deletion
    const admin = require('firebase-admin');
    deleteFields.forEach(field => {
        updates[field] = admin.firestore.FieldValue.delete();
    });

    return updates;
}

async function main() {
    try {
        console.log('🔄 Starting Firestore Record Updater...');
        console.log(`📂 Collection: ${options.collection}`);
        console.log(`🔍 Where clauses: ${options.where.join(' AND ')}`);
        console.log(`✏️  Set clauses: ${options.set.join(', ')}`);
        
        if (options.dryRun) {
            console.log('🔬 DRY RUN MODE - No changes will be made');
        }
        
        console.log('');

        // Parse clauses
        const whereClauses = options.where.map(parseWhereClause);
        const setClauses = options.set.map(parseSetClause);

        // Build query
        let query = db.collection(options.collection);
        
        for (const where of whereClauses) {
            if (options.verbose) {
                console.log(`  Adding where clause: ${where.field} ${where.operator} ${where.value}`);
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
            console.log('⚠️  No matching records found');
            process.exit(0);
        }

        console.log(`📊 Found ${snapshot.size} matching records`);

        // Show sample of changes
        if (options.verbose || options.dryRun) {
            console.log('\n📋 Sample of changes (first 5 records):');
            let sampleCount = 0;
            snapshot.docs.slice(0, 5).forEach(doc => {
                const data = doc.data();
                console.log(`\n  Document ID: ${doc.id}`);
                
                for (const clause of setClauses) {
                    const oldValue = getNestedValue(data, clause.field);
                    console.log(`    ${clause.field}: ${JSON.stringify(oldValue)} → ${JSON.stringify(clause.value)}`);
                }
                sampleCount++;
            });
            
            if (snapshot.size > 5) {
                console.log(`\n  ... and ${snapshot.size - 5} more records`);
            }
        }

        // Confirmation
        if (!options.force && !options.dryRun) {
            const confirmed = await promptConfirmation(
                `\n⚠️  This will update ${snapshot.size} records. Continue? (y/n): `
            );
            
            if (!confirmed) {
                console.log('❌ Update cancelled');
                process.exit(0);
            }
        }

        // Create backup if requested
        if (options.backup && !options.dryRun) {
            console.log('\n📦 Creating backup...');
            const backupData = snapshot.docs.map(doc => ({
                id: doc.id,
                data: doc.data()
            }));
            await createBackup(options.collection, backupData);
        }

        // Perform updates
        if (!options.dryRun) {
            console.log('\n🚀 Performing updates...');
            
            // Process in batches
            const docs = snapshot.docs;
            let totalUpdated = 0;
            
            for (let i = 0; i < docs.length; i += options.batchSize) {
                const batch = db.batch();
                const batchDocs = docs.slice(i, Math.min(i + options.batchSize, docs.length));
                
                batchDocs.forEach(doc => {
                    const updates = applyUpdates(doc.data(), setClauses);
                    batch.update(doc.ref, updates);
                });
                
                await batch.commit();
                totalUpdated += batchDocs.length;
                
                console.log(`  ✅ Batch ${Math.floor(i / options.batchSize) + 1}: Updated ${batchDocs.length} records (${totalUpdated}/${snapshot.size})`);
            }
            
            console.log(`\n✅ Successfully updated ${totalUpdated} records`);
        } else {
            console.log('\n✅ Dry run completed - no changes made');
        }

        // Summary
        console.log('\n📊 Update Summary:');
        console.log(`  Collection: ${options.collection}`);
        console.log(`  Records matched: ${snapshot.size}`);
        console.log(`  Records updated: ${options.dryRun ? 0 : snapshot.size}`);
        console.log(`  Fields modified: ${setClauses.map(c => c.field).join(', ')}`);

    } catch (error) {
        console.error('❌ Update failed:', error.message);
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

// Run the updater
main();