#!/usr/bin/env node

const { admin, db } = require('./config');

async function checkFirestoreData() {
    try {
        console.log('🔍 Checking Firestore data...');
        
        // Check users collection
        console.log('\n👥 Users Collection:');
        const usersSnapshot = await db.collection('users').get();
        if (usersSnapshot.empty) {
            console.log('❌ No users found');
        } else {
            usersSnapshot.forEach(doc => {
                const data = doc.data();
                console.log(`✅ User: ${data.email || data.name || doc.id} (${doc.id})`);
            });
        }
        
        // Check organizations collection
        console.log('\n🏢 Organizations Collection:');
        const orgsSnapshot = await db.collection('organizations').get();
        if (orgsSnapshot.empty) {
            console.log('❌ No organizations found');
        } else {
            orgsSnapshot.forEach(doc => {
                const data = doc.data();
                console.log(`✅ Organization: ${data.name || doc.id} (${doc.id})`);
            });
        }
        
        // Check sites collection
        console.log('\n🏗️ Sites Collection:');
        const sitesSnapshot = await db.collection('sites').get();
        if (sitesSnapshot.empty) {
            console.log('❌ No sites found');
        } else {
            sitesSnapshot.forEach(doc => {
                const data = doc.data();
                console.log(`✅ Site: ${data.name || doc.id} (${doc.id})`);
            });
        }
        
        // Check all collections
        console.log('\n📚 All Collections:');
        const collections = await db.listCollections();
        collections.forEach(collection => {
            console.log(`📁 ${collection.id}`);
        });
        
    } catch (error) {
        console.error('❌ Error checking Firestore data:', error.message);
        process.exit(1);
    }
}

checkFirestoreData();
