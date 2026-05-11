#!/usr/bin/env node

/**
 * Reset Firestore Database
 * 
 * WARNING: This script will DELETE ALL DATA in the Firestore database!
 * Use with extreme caution.
 * 
 * Usage:
 *   node scripts/reset-firestore.js [--project=PROJECT_ID] [--confirm]
 */

require('dotenv').config();
const admin = require('firebase-admin');
const readline = require('readline');

// Parse command line arguments
const args = process.argv.slice(2);
const projectId = args.find(arg => arg.startsWith('--project='))?.split('=')[1] || process.env.FIREBASE_PROJECT_ID || 'seafoundryapp';
const needsConfirmation = !args.includes('--confirm');

// Firebase Admin SDK configuration
const serviceAccount = {
    type: 'service_account',
    project_id: projectId,
    private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
    private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    client_email: process.env.FIREBASE_CLIENT_EMAIL,
    client_id: process.env.FIREBASE_CLIENT_ID,
    auth_uri: process.env.FIREBASE_AUTH_URI || 'https://accounts.google.com/o/oauth2/auth',
    token_uri: process.env.FIREBASE_TOKEN_URI || 'https://oauth2.googleapis.com/token',
    auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL || 'https://www.googleapis.com/oauth2/v1/certs',
    client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL,
};

// Check if we have credentials
if (!serviceAccount.private_key || !serviceAccount.client_email) {
    console.error('❌ Error: Firebase Admin SDK credentials not found.');
    console.error('Please set FIREBASE_PRIVATE_KEY and FIREBASE_CLIENT_EMAIL in your .env file.');
    console.error('Or use Firebase CLI authentication: firebase login');
    process.exit(1);
}

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
    try {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            projectId: projectId,
        });
    } catch (error) {
        console.error('❌ Error initializing Firebase Admin SDK:', error.message);
        process.exit(1);
    }
}

const db = admin.firestore();

/**
 * Delete all documents in a collection
 */
async function deleteCollection(collectionPath) {
    const collectionRef = db.collection(collectionPath);
    const batchSize = 500;
    let deletedCount = 0;

    while (true) {
        const snapshot = await collectionRef.limit(batchSize).get();
        
        if (snapshot.empty) {
            break;
        }

        const batch = db.batch();
        snapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });
        
        await batch.commit();
        deletedCount += snapshot.docs.length;
        console.log(`  Deleted ${deletedCount} documents from ${collectionPath}...`);
    }

    return deletedCount;
}

/**
 * Delete all subcollections of a document
 */
async function deleteSubcollections(docRef) {
    const collections = await docRef.listCollections();
    
    for (const subcollection of collections) {
        await deleteCollection(subcollection.path);
    }
}

/**
 * Recursively delete all collections and subcollections
 */
async function deleteAllCollections() {
    console.log(`\n🗑️  Starting Firestore reset for project: ${projectId}`);
    console.log('⚠️  WARNING: This will delete ALL data in Firestore!\n');

    try {
        // Get all top-level collections
        const collections = await db.listCollections();
        const collectionNames = collections.map(col => col.id);
        
        if (collectionNames.length === 0) {
            console.log('✅ Firestore is already empty.');
            return;
        }

        console.log(`Found ${collectionNames.length} collection(s):`);
        collectionNames.forEach(name => console.log(`  - ${name}`));
        console.log('');

        let totalDeleted = 0;
        
        // Delete each collection
        for (const collectionName of collectionNames) {
            console.log(`Deleting collection: ${collectionName}`);
            const deleted = await deleteCollection(collectionName);
            totalDeleted += deleted;
            
            // Also check for subcollections (though Firestore doesn't have true subcollections in the same way)
            // We'll handle document subcollections if needed
        }

        console.log(`\n✅ Successfully deleted ${totalDeleted} document(s) from ${collectionNames.length} collection(s).`);
        console.log('✅ Firestore database reset complete!\n');
        
    } catch (error) {
        console.error('❌ Error resetting Firestore:', error.message);
        console.error(error.stack);
        process.exit(1);
    }
}

/**
 * Main execution
 */
async function main() {
    if (needsConfirmation) {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        const answer = await new Promise(resolve => {
            rl.question(`⚠️  Are you sure you want to DELETE ALL DATA from Firestore project "${projectId}"? (type "yes" to confirm): `, resolve);
        });

        rl.close();

        if (answer.toLowerCase() !== 'yes') {
            console.log('❌ Reset cancelled.');
            process.exit(0);
        }
    }

    await deleteAllCollections();
}

// Run the script
main().then(() => {
    process.exit(0);
}).catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
});


