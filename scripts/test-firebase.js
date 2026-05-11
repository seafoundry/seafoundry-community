#!/usr/bin/env node

const { admin, db, config } = require('./config-json');

async function testFirebase() {
    try {
        console.log('🔍 Testing Firebase connection...');
        console.log(`Project ID: ${config.collections.projectId || 'seafoundryapp'}`);
        console.log(`Environment: ${config.environment}`);
        console.log('');

        // Test basic connection
        console.log('📡 Testing Firestore connection...');
        const testDoc = db.collection('test').doc('connection-test');
        await testDoc.set({
            timestamp: new Date(),
            message: 'Connection test successful'
        });
        console.log('✅ Successfully wrote test document');

        // Read it back
        const doc = await testDoc.get();
        if (doc.exists) {
            console.log('✅ Successfully read test document');
            console.log('Document data:', doc.data());
        } else {
            console.log('❌ Could not read test document');
        }

        // Clean up test document
        await testDoc.delete();
        console.log('✅ Cleaned up test document');

        // Check existing collections
        console.log('\n📊 Checking existing collections...');
        const collections = await db.listCollections();
        console.log('Available collections:', collections.map(col => col.id));

        // Check if species collection exists and has data
        console.log('\n🔍 Checking species collection...');
        const speciesSnapshot = await db.collection('species').limit(1).get();
        console.log(`Species collection exists: ${!speciesSnapshot.empty}`);
        console.log(`Species count: ${speciesSnapshot.size}`);

        if (!speciesSnapshot.empty) {
            const firstSpecies = speciesSnapshot.docs[0];
            console.log('First species document:', firstSpecies.data());
        }

        // Check if users collection exists and has data
        console.log('\n🔍 Checking users collection...');
        const usersSnapshot = await db.collection('users').limit(1).get();
        console.log(`Users collection exists: ${!usersSnapshot.empty}`);
        console.log(`Users count: ${usersSnapshot.size}`);

        if (!usersSnapshot.empty) {
            const firstUser = usersSnapshot.docs[0];
            console.log('First user document:', firstUser.data());
        }

        console.log('\n✨ Firebase test completed successfully!');

    } catch (error) {
        console.error('❌ Firebase test failed:', error.message);
        console.error(error.stack);
    }
}

testFirebase(); 