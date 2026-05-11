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
    verify: args.includes('--verify'),
    org: null,
    batchSize: 500
};

// Parse org filter if provided
for (let i = 0; i < args.length; i++) {
    if (args[i] === '--org') {
        options.org = args[++i];
    } else if (args[i] === '--batch-size') {
        options.batchSize = parseInt(args[++i]);
    }
}

// Show help
if (options.help) {
    console.log(`
🐠 SeaFoundry Corals to Organism Records Migration

This migration script migrates coral documents from the legacy 'corals' subcollection
to the unified 'organismRecords' subcollection within each organization.

Usage: npm run migrate:corals [options]

Options:
  --dry-run, -d               Preview changes without updating
  --backup, -b                Create backup file of original corals
  --force, -f                 Skip confirmation prompt
  --verbose, -v               Show detailed output
  --verify                    Verify migration after completion
  --org <orgId>               Migrate only a specific organization
  --batch-size <number>       Batch size for updates (default: 500)
  --help, -h                  Show this help message

The script will:
1. Iterate through all organizations (or a single org with --org flag)
2. For each org, read all documents from 'organizations/{orgId}/corals'
3. Transform each coral document to OrganismRecord format:
   - quantity → measurement.value (with unit: 'count')
   - healthStatus → metadata.healthStatus
   - readyForFragging → metadata.readyForFragging
   - readyForOutplant → metadata.readyForOutplant
   - coralTypeId → metadata.coralTypeId
   - actualSizeCm → metadata.actualSizeCm
   - notes → metadata.notes
   - genetId → foreignKeys.genetId
   - lifeStageOverride → lifeStage.stage
   - Add organismKind: 'coral'
4. Write to 'organizations/{orgId}/organismRecords'
5. Mark source coral docs as migrated (adds 'migratedToOrganismRecords: true')

Examples:
  # Dry run to preview changes
  npm run migrate:corals -- --dry-run

  # Run the actual migration
  npm run migrate:corals

  # Migrate a specific organization
  npm run migrate:corals -- --org org123

  # Run with backup and verification
  npm run migrate:corals -- --backup --verify
`);
    process.exit(0);
}

// Stats tracking
const stats = {
    totalOrgs: 0,
    totalCorals: 0,
    migratedCorals: 0,
    alreadyMigrated: 0,
    errors: [],
    orgStats: {}
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
async function createBackup(data) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(process.cwd(), 'backups');
    const backupFile = path.join(backupDir, `corals_migration_${timestamp}.json`);

    try {
        await fs.mkdir(backupDir, { recursive: true });
        await fs.writeFile(backupFile, JSON.stringify(data, null, 2));
        console.log(`📁 Backup saved to: ${backupFile}`);
        return backupFile;
    } catch (error) {
        console.error('❌ Failed to create backup:', error.message);
        throw error;
    }
}

// Transform coral document to organism record format
// Based on CoralOrganismMapper.toOrganismRecordFromJson logic
function transformCoralToOrganismRecord(coralData) {
    const existingMetadata = coralData.metadata || {};

    // Extract and transform fields according to mapper
    const healthStatusId = coralData.healthStatus || 'healthy';
    const readyForFragging = coralData.readyForFragging === true;
    const readyForOutplant = coralData.readyForOutplant === true;
    const notes = coralData.notes;
    const actualSizeCm = coralData.actualSizeCm;
    const coralTypeId = coralData.coralTypeId || '';

    // Build metadata object
    const metadata = {
        ...existingMetadata,
        healthStatus: healthStatusId,
        readyForFragging: readyForFragging,
        readyForOutplant: readyForOutplant,
        coralTypeId: coralTypeId
    };

    if (notes && notes.trim().length > 0) {
        metadata.notes = notes;
    }

    if (actualSizeCm != null) {
        metadata.actualSizeCm = actualSizeCm;
    }

    // Parse quantity and create measurement
    const quantity = coralData.quantity || 0;
    const measurement = coralData.populationMeasurement || {
        value: parseFloat(quantity),
        unit: 'count'
    };

    // Parse life stage
    const lifeStageId = coralData.lifeStageOverride || existingMetadata.lifeStageId || 'juvenile';
    const lifeStage = {
        stage: lifeStageId
    };

    // Build foreignKeys with genet reference
    const foreignKeys = {
        genetId: {
            id: coralData.genetId || '',
            metadata: { kind: 'genet' }
        }
    };

    // Build organism record
    const organismRecord = {
        id: coralData.id,
        createdAt: coralData.createdAt,
        createdById: coralData.createdById,
        updatedAt: coralData.updatedAt,
        updatedById: coralData.updatedById,
        organizationId: coralData.organizationId,
        urlPath: coralData.urlPath,
        internalPath: coralData.internalPath,
        slug: coralData.slug,
        metadata: metadata,
        organismKind: 'coral',
        lifeStage: lifeStage,
        measurement: measurement,
        modelType: 'organism_record',
        foreignKeys: foreignKeys
    };

    // Add optional fields
    if (coralData.speciesId) {
        organismRecord.speciesId = coralData.speciesId;
    }
    if (coralData.name) {
        organismRecord.groupName = coralData.name;
    }
    if (coralData.siteId) {
        organismRecord.siteId = coralData.siteId;
    }
    if (coralData.groupId) {
        organismRecord.groupId = coralData.groupId;
    }

    return organismRecord;
}

// Migrate corals for a single organization
async function migrateOrganization(orgId) {
    const orgStats = {
        totalCorals: 0,
        migrated: 0,
        alreadyMigrated: 0,
        errors: []
    };

    try {
        console.log(`\n📂 Processing organization: ${orgId}`);

        // Get all corals in this organization
        const coralsRef = db.collection('organizations').doc(orgId).collection('corals');
        const coralsSnapshot = await coralsRef.get();

        if (coralsSnapshot.empty) {
            console.log('  ℹ️  No corals found in this organization');
            return orgStats;
        }

        orgStats.totalCorals = coralsSnapshot.size;
        console.log(`  📊 Found ${orgStats.totalCorals} coral documents`);

        const organismRecordsRef = db.collection('organizations').doc(orgId).collection('organismRecords');
        const batches = [];
        let currentBatch = db.batch();
        let batchCount = 0;
        let processedCount = 0;

        for (const coralDoc of coralsSnapshot.docs) {
            const coralData = { id: coralDoc.id, ...coralDoc.data() };

            // Skip if already migrated
            if (coralData.migratedToOrganismRecords === true) {
                orgStats.alreadyMigrated++;
                if (options.verbose) {
                    console.log(`  ⏭️  Coral ${coralDoc.id} already migrated`);
                }
                continue;
            }

            try {
                // Transform to organism record
                const organismRecord = transformCoralToOrganismRecord(coralData);

                if (options.verbose && processedCount < 3) {
                    console.log(`  📝 Transforming: ${coralDoc.id} → organism_record`);
                }

                // Add to batch: write organism record
                const organismDocRef = organismRecordsRef.doc(coralDoc.id);
                currentBatch.set(organismDocRef, organismRecord);

                // Mark coral as migrated
                currentBatch.update(coralDoc.ref, { migratedToOrganismRecords: true });

                batchCount += 2; // Two operations per coral
                processedCount++;

                // Commit batch if we've reached the limit (250 operations = 125 corals)
                if (batchCount >= 250) {
                    batches.push(currentBatch);
                    currentBatch = db.batch();
                    batchCount = 0;
                }

                orgStats.migrated++;

                // Progress update every 100 documents
                if (processedCount % 100 === 0) {
                    console.log(`  📍 Progress: ${processedCount}/${orgStats.totalCorals} corals processed`);
                }

            } catch (error) {
                console.error(`  ❌ Error transforming coral ${coralDoc.id}:`, error.message);
                orgStats.errors.push({
                    coralId: coralDoc.id,
                    error: error.message
                });
            }
        }

        // Add the last batch if it has operations
        if (batchCount > 0) {
            batches.push(currentBatch);
        }

        // Execute all batches
        if (!options.dryRun && batches.length > 0) {
            console.log(`  🚀 Committing ${batches.length} batches (${orgStats.migrated} corals)...`);

            for (let i = 0; i < batches.length; i++) {
                await batches[i].commit();
                console.log(`  ✅ Batch ${i + 1}/${batches.length} committed`);
            }
        } else if (options.dryRun) {
            console.log(`  🔬 Dry run: Would migrate ${orgStats.migrated} corals`);
        }

        console.log(`  ✅ Organization ${orgId} complete: ${orgStats.migrated} migrated, ${orgStats.alreadyMigrated} already migrated`);

    } catch (error) {
        console.error(`  ❌ Error processing organization ${orgId}:`, error.message);
        orgStats.errors.push({
            orgId: orgId,
            error: error.message
        });
    }

    return orgStats;
}

// Verify migration
async function verifyMigration(orgId) {
    console.log(`\n🔍 Verifying migration for org: ${orgId}`);

    const coralsRef = db.collection('organizations').doc(orgId).collection('corals');
    const organismRecordsRef = db.collection('organizations').doc(orgId).collection('organismRecords');

    const [coralsSnapshot, organismsSnapshot] = await Promise.all([
        coralsRef.get(),
        organismRecordsRef.where('organismKind', '==', 'coral').get()
    ]);

    const totalCorals = coralsSnapshot.size;
    const migratedCorals = coralsSnapshot.docs.filter(doc =>
        doc.data().migratedToOrganismRecords === true
    ).length;
    const totalOrganisms = organismsSnapshot.size;

    console.log(`  📊 Corals total: ${totalCorals}`);
    console.log(`  📊 Corals marked migrated: ${migratedCorals}`);
    console.log(`  📊 Organism records (coral kind): ${totalOrganisms}`);

    const isValid = migratedCorals === totalOrganisms;

    if (isValid) {
        console.log(`  ✅ Verification passed`);
    } else {
        console.log(`  ⚠️  Verification mismatch: ${migratedCorals} marked migrated but ${totalOrganisms} organism records found`);
    }

    return {
        orgId,
        totalCorals,
        migratedCorals,
        totalOrganisms,
        isValid
    };
}

async function main() {
    try {
        console.log('🚀 Starting Coral to Organism Records Migration...');

        if (options.dryRun) {
            console.log('🔬 DRY RUN MODE - No changes will be made');
        }

        console.log('');

        // Get organizations to process
        let orgIds = [];

        if (options.org) {
            // Single organization mode
            console.log(`📂 Single organization mode: ${options.org}`);
            orgIds = [options.org];
        } else {
            // All organizations mode
            console.log('📂 Fetching all organizations...');
            const orgsSnapshot = await db.collection('organizations').get();

            if (orgsSnapshot.empty) {
                console.log('⚠️  No organizations found');
                process.exit(0);
            }

            orgIds = orgsSnapshot.docs.map(doc => doc.id);
            console.log(`📊 Found ${orgIds.length} organizations`);
        }

        stats.totalOrgs = orgIds.length;

        // Create backup if requested
        if (options.backup && !options.dryRun) {
            console.log('\n📦 Creating backup...');
            const backupData = {
                timestamp: new Date().toISOString(),
                organizations: {}
            };

            for (const orgId of orgIds) {
                const coralsSnapshot = await db.collection('organizations')
                    .doc(orgId)
                    .collection('corals')
                    .get();

                backupData.organizations[orgId] = coralsSnapshot.docs.map(doc => ({
                    id: doc.id,
                    data: doc.data()
                }));
            }

            await createBackup(backupData);
            console.log('');
        }

        // Confirmation
        if (!options.force && !options.dryRun) {
            const confirmed = await promptConfirmation(
                `\n⚠️  This will migrate corals in ${stats.totalOrgs} organization(s). Continue? (y/n): `
            );

            if (!confirmed) {
                console.log('❌ Migration cancelled');
                process.exit(0);
            }
        }

        // Process each organization
        for (const orgId of orgIds) {
            const orgStats = await migrateOrganization(orgId);
            stats.orgStats[orgId] = orgStats;
            stats.totalCorals += orgStats.totalCorals;
            stats.migratedCorals += orgStats.migrated;
            stats.alreadyMigrated += orgStats.alreadyMigrated;
            stats.errors.push(...orgStats.errors);
        }

        // Final summary
        console.log('\n' + '='.repeat(60));
        console.log('📊 Migration Summary');
        console.log('='.repeat(60));
        console.log(`Organizations processed: ${stats.totalOrgs}`);
        console.log(`Total coral documents: ${stats.totalCorals}`);
        console.log(`Migrated: ${stats.migratedCorals}`);
        console.log(`Already migrated: ${stats.alreadyMigrated}`);
        console.log(`Errors: ${stats.errors.length}`);

        if (stats.errors.length > 0 && options.verbose) {
            console.log('\n⚠️  Errors encountered:');
            stats.errors.slice(0, 10).forEach(err => {
                console.log(`  - ${err.coralId || err.orgId}: ${err.error}`);
            });
            if (stats.errors.length > 10) {
                console.log(`  ... and ${stats.errors.length - 10} more`);
            }
        }

        // Verification
        if (options.verify && !options.dryRun) {
            console.log('\n' + '='.repeat(60));
            console.log('🔍 Verification');
            console.log('='.repeat(60));

            const verifications = [];
            for (const orgId of orgIds) {
                const result = await verifyMigration(orgId);
                verifications.push(result);
            }

            const allValid = verifications.every(v => v.isValid);
            console.log(`\n${allValid ? '✅' : '⚠️'} Overall verification: ${allValid ? 'PASSED' : 'FAILED'}`);
        }

        // Save error report if there are errors
        if (stats.errors.length > 0 && !options.dryRun) {
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const reportDir = path.join(process.cwd(), 'migration-reports');
            const reportFile = path.join(reportDir, `coral_migration_errors_${timestamp}.json`);

            try {
                await fs.mkdir(reportDir, { recursive: true });
                await fs.writeFile(reportFile, JSON.stringify({
                    timestamp: new Date().toISOString(),
                    stats: stats
                }, null, 2));
                console.log(`\n📄 Error report saved to: ${reportFile}`);
            } catch (error) {
                console.error('⚠️  Failed to save report:', error.message);
            }
        }

        console.log('\n✅ Migration complete!');

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
