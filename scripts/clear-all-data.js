#!/usr/bin/env node

const { admin, db, config } = require('./config-json');
const readline = require('readline');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
    force: args.includes('--force') || args.includes('-f'),
    firestoreOnly: args.includes('--firestore-only'),
    storageOnly: args.includes('--storage-only'),
    verbose: args.includes('--verbose') || args.includes('-v'),
    help: args.includes('--help') || args.includes('-h'),
    yes: args.includes('--yes') || args.includes('-y'),
    batchSize: 500
};

// Show help
if (options.help) {
    console.log(`
🗑️  SeaFoundry Database & Storage Clearer

Clears ALL data from Firestore and Cloud Storage.

Usage: npm run clear:all [options]

Options:
  --force, -f              Actually perform deletions (required for real deletion)
  --dry-run                Preview what will be deleted (DEFAULT)
  --firestore-only         Only clear Firestore database
  --storage-only           Only clear Cloud Storage
  --verbose, -v            Show detailed progress
  --help, -h               Show this help message

Examples:
  # Preview what will be deleted (dry run)
  npm run clear:all

  # Actually delete everything
  npm run clear:all -- --force

  # Only clear Firestore
  npm run clear:all -- --force --firestore-only

  # Only clear Storage
  npm run clear:all -- --force --storage-only

⚠️  WARNING: This will DELETE ALL DATA from your Firebase project!
⚠️  By default, runs in dry-run mode for safety.
`);
    process.exit(0);
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
            resolve(answer.toLowerCase() === 'yes');
        });
    });
}

// Get all collections in Firestore
async function getAllCollections() {
    const collections = await db.listCollections();
    return collections.map(col => col.id);
}

// Recursively get all subcollections for a document
async function getAllSubcollections(docRef) {
    const subcollections = await docRef.listCollections();
    return subcollections;
}

// Count documents in a collection including subcollections
async function countDocumentsRecursive(collectionRef, path = '') {
    let count = 0;
    const snapshot = await collectionRef.get();
    count += snapshot.size;

    // Count documents in subcollections
    for (const doc of snapshot.docs) {
        const subcollections = await getAllSubcollections(doc.ref);
        for (const subcol of subcollections) {
            const subCount = await countDocumentsRecursive(subcol, `${path}/${doc.id}/${subcol.id}`);
            count += subCount;
        }
    }

    return count;
}

// Count documents in a collection
async function countDocuments(collectionName) {
    const collectionRef = db.collection(collectionName);
    return await countDocumentsRecursive(collectionRef, collectionName);
}

// Recursively delete all documents and subcollections
async function deleteCollectionRecursive(collectionRef, path = '') {
    let totalDeleted = 0;
    let hasMore = true;

    while (hasMore) {
        const snapshot = await collectionRef
            .limit(options.batchSize)
            .get();

        if (snapshot.empty) {
            hasMore = false;
            break;
        }

        const batch = db.batch();

        for (const doc of snapshot.docs) {
            // First, recursively delete all subcollections
            const subcollections = await getAllSubcollections(doc.ref);
            for (const subcol of subcollections) {
                const subDeleted = await deleteCollectionRecursive(subcol, `${path}/${doc.id}/${subcol.id}`);
                totalDeleted += subDeleted;
            }

            // Then delete the document itself
            batch.delete(doc.ref);
        }

        await batch.commit();
        totalDeleted += snapshot.size;

        if (options.verbose) {
            console.log(`    Deleted ${snapshot.size} documents from ${path || collectionRef.path} (${totalDeleted} total)`);
        }

        if (snapshot.size < options.batchSize) {
            hasMore = false;
        }
    }

    return totalDeleted;
}

// Delete all documents from a collection
async function clearCollection(collectionName) {
    console.log(`  📂 Deleting collection: ${collectionName}`);

    const collectionRef = db.collection(collectionName);
    const totalDeleted = await deleteCollectionRecursive(collectionRef, collectionName);

    console.log(`    ✅ Deleted ${totalDeleted} documents (including subcollections)`);
    return totalDeleted;
}

// Count Firestore data
async function countFirestore() {
    const collections = await getAllCollections();

    let totalDocs = 0;
    const collectionCounts = {};

    for (const collectionName of collections) {
        const count = await countDocuments(collectionName);
        collectionCounts[collectionName] = count;
        totalDocs += count;
    }

    return { collections, collectionCounts, totalDocs };
}

// Clear all Firestore data
async function clearFirestore() {
    const { collections, collectionCounts, totalDocs } = await countFirestore();

    if (totalDocs === 0) {
        return { collections: 0, documents: 0 };
    }

    let totalDeleted = 0;
    for (const collectionName of collections) {
        if (collectionCounts[collectionName] > 0) {
            const deleted = await clearCollection(collectionName);
            totalDeleted += deleted;
        }
    }

    return { collections: collections.length, documents: totalDeleted };
}

// List all files in storage
async function listAllFiles(bucket) {
    const [files] = await bucket.getFiles();
    return files;
}

// Count storage data
async function countStorage() {
    try {
        const bucketName = process.env.FIREBASE_STORAGE_BUCKET || 'seafoundryapp.firebasestorage.app';
        const bucket = admin.storage().bucket(bucketName);
        const files = await listAllFiles(bucket);

        return { bucket, files, fileCount: files.length };
    } catch (error) {
        return { files: [], fileCount: 0, error: error.message };
    }
}

// Clear all Cloud Storage data
async function clearStorage(bucket, files) {
    if (files.length === 0) {
        return { files: 0 };
    }

    // Delete in batches
    for (let i = 0; i < files.length; i += options.batchSize) {
        const batch = files.slice(i, i + options.batchSize);
        await Promise.all(batch.map(file => file.delete()));

        if (options.verbose) {
            console.log(`  Deleted ${Math.min(i + options.batchSize, files.length)}/${files.length} files`);
        }
    }

    return { files: files.length };
}

async function main() {
    try {
        console.log('🗑️  Starting Database & Storage Clearer...\n');

        // Step 1: Count what will be deleted
        const counts = {
            firestore: null,
            storage: null
        };

        if (!options.storageOnly) {
            console.log('🗄️  Counting Firestore data...');
            const firestoreData = await countFirestore();
            counts.firestore = firestoreData;
            console.log(`  Found ${firestoreData.collections.length} collections with ${firestoreData.totalDocs} documents`);
        }

        if (!options.firestoreOnly) {
            console.log('\n☁️  Counting Cloud Storage data...');
            const storageData = await countStorage();
            counts.storage = storageData;

            if (storageData.error) {
                console.log(`  ❌ Storage error: ${storageData.error}`);
            } else {
                console.log(`  Found ${storageData.fileCount} files`);

                if (options.verbose && storageData.fileCount > 0) {
                    console.log('\n  Sample files:');
                    storageData.files.slice(0, 10).forEach(file => {
                        console.log(`    - ${file.name}`);
                    });
                    if (storageData.fileCount > 10) {
                        console.log(`    ... and ${storageData.fileCount - 10} more files`);
                    }
                }
            }
        }

        // Check if there's anything to delete
        const hasData = (counts.firestore && counts.firestore.totalDocs > 0) ||
                        (counts.storage && counts.storage.fileCount > 0);

        if (!hasData) {
            console.log('\n✅ No data found - everything is already empty');
            process.exit(0);
        }

        // Step 2: Show summary
        console.log('\n⚠️  DELETION SUMMARY:');
        if (counts.firestore) {
            console.log(`  Firestore: ${counts.firestore.totalDocs} documents from ${counts.firestore.collections.length} collections`);
        }
        if (counts.storage && !counts.storage.error) {
            console.log(`  Storage: ${counts.storage.fileCount} files`);
        }

        // Step 3: Get confirmation if --force is specified
        if (!options.force) {
            console.log('\n💡 This is a DRY RUN. Run with --force to actually delete the data.');
            process.exit(0);
        }

        let confirmed = false;
        if (options.yes) {
            confirmed = true;
            console.log('\n✅ Auto-confirmed deletion (--yes flag provided)');
        } else {
            confirmed = await promptConfirmation(
                '\n🚨 Type "yes" to PERMANENTLY DELETE all this data: '
            );

            if (!confirmed) {
                console.log('\n❌ Deletion cancelled');
                process.exit(0);
            }
        }

        // Step 4: Actually delete the data
        console.log('\n🚀 Performing deletion...\n');

        const results = {
            firestore: null,
            storage: null
        };

        if (!options.storageOnly && counts.firestore && counts.firestore.totalDocs > 0) {
            console.log('🗄️  Deleting Firestore data...');
            results.firestore = await clearFirestore();
        }

        if (!options.firestoreOnly && counts.storage && counts.storage.fileCount > 0) {
            console.log('\n☁️  Deleting Cloud Storage data...');
            results.storage = await clearStorage(counts.storage.bucket, counts.storage.files);
            console.log(`  ✅ Deleted ${results.storage.files} files`);
        }

        // Final summary
        console.log('\n📊 Deletion Complete:');
        if (results.firestore) {
            console.log(`  Firestore: Deleted ${results.firestore.documents} documents`);
        }
        if (results.storage) {
            console.log(`  Storage: Deleted ${results.storage.files} files`);
        }

        console.log('\n✅ All data has been deleted');

    } catch (error) {
        console.error('❌ Operation failed:', error.message);
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

// Run the clearer
main();
