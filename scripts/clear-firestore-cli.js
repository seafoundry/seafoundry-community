#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Firebase CLI-based data clearer
// This script uses Firebase CLI commands to clear data

console.log('🗑️  Firebase CLI Database Clearer');
console.log('=====================================\n');

// Check if we're logged in
try {
    const projects = execSync('firebase projects:list', { encoding: 'utf8' });
    console.log('✅ Firebase CLI authenticated');
    console.log('Current projects:');
    console.log(projects);
} catch (error) {
    console.error('❌ Firebase CLI not authenticated. Please run: firebase login');
    process.exit(1);
}

// Function to execute Firebase CLI commands
function runFirebaseCommand(command, description) {
    console.log(`\n🔄 ${description}...`);
    try {
        const result = execSync(command, { encoding: 'utf8' });
        console.log(`✅ ${description} completed`);
        if (result.trim()) {
            console.log(result);
        }
        return true;
    } catch (error) {
        console.error(`❌ ${description} failed:`, error.message);
        return false;
    }
}

// Main clearing function
async function clearDatabase() {
    console.log('\n📊 Current Firestore indexes:');
    runFirebaseCommand('firebase firestore:indexes', 'Listing current indexes');

    console.log('\n🚀 Deploying Firestore indexes...');
    runFirebaseCommand('firebase deploy --only firestore:indexes', 'Deploying indexes');

    console.log('\n🛡️  Deploying Firestore rules...');
    runFirebaseCommand('firebase deploy --only firestore:rules', 'Deploying rules');

    console.log('\n✅ Database configuration updated!');
    console.log('\n💡 To clear actual data, you\'ll need to:');
    console.log('   1. Use Firebase Console to delete collections manually');
    console.log('   2. Or set up Admin SDK with service account credentials');
    console.log('   3. Or use the existing npm run clear:all script (requires service account)');
}

// Run the clearer
clearDatabase().catch(console.error);
