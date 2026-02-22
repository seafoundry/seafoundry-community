#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function question(prompt) {
    return new Promise((resolve) => {
        rl.question(prompt, resolve);
    });
}

async function setup() {
    console.log('🌊 SeaFoundry Database Seeder Setup');
    console.log('=====================================\n');

    console.log('This script will help you set up your Firebase credentials for the database seeder.\n');

    // Check if .env file already exists
    const envPath = path.join(process.cwd(), '.env');
    if (fs.existsSync(envPath)) {
        const overwrite = await question('A .env file already exists. Do you want to overwrite it? (y/N): ');
        if (overwrite.toLowerCase() !== 'y' && overwrite.toLowerCase() !== 'yes') {
            console.log('Setup cancelled.');
            rl.close();
            return;
        }
    }

    console.log('\n📋 Firebase Configuration');
    console.log('You can find these values in your Firebase project settings:');
    console.log('1. Go to Firebase Console > Project Settings > Service Accounts');
    console.log('2. Click "Generate new private key" to download a JSON file');
    console.log('3. Use the values from that JSON file\n');

    const projectId = await question('Firebase Project ID (default: seafoundryapp): ') || 'seafoundryapp';
    const privateKeyId = await question('Private Key ID: ');
    const privateKey = await question('Private Key (paste the entire key including BEGIN/END lines): ');
    const clientEmail = await question('Client Email: ');
    const clientId = await question('Client ID: ');

    console.log('\n🔧 Environment Configuration');
    const nodeEnv = await question('Node Environment (default: development): ') || 'development';

    console.log('\n🌱 Seeding Options');
    console.log('Which data types would you like to seed by default? (y/N for each)');

    const seedOrganizations = await question('Seed Organizations? (y/N): ');
    const seedSites = await question('Seed Sites? (y/N): ');
    const seedGroups = await question('Seed Groups? (y/N): ');
    const seedCorals = await question('Seed Corals? (y/N): ');
    const seedSpecies = await question('Seed Species? (y/N): ');
    const seedUsers = await question('Seed Users? (y/N): ');

    // Build .env content
    const envContent = `# Firebase Configuration
FIREBASE_PROJECT_ID=${projectId}
FIREBASE_PRIVATE_KEY_ID=${privateKeyId}
FIREBASE_PRIVATE_KEY="${privateKey.replace(/"/g, '\\"')}"
FIREBASE_CLIENT_EMAIL=${clientEmail}
FIREBASE_CLIENT_ID=${clientId}
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=https://www.googleapis.com/robot/v1/metadata/x509/${clientEmail.replace('@', '%40')}

# Environment
NODE_ENV=${nodeEnv}

# Seeding Options
SEED_ORGANIZATIONS=${seedOrganizations.toLowerCase() === 'y' || seedOrganizations.toLowerCase() === 'yes'}
SEED_SITES=${seedSites.toLowerCase() === 'y' || seedSites.toLowerCase() === 'yes'}
SEED_GROUPS=${seedGroups.toLowerCase() === 'y' || seedGroups.toLowerCase() === 'yes'}
SEED_CORALS=${seedCorals.toLowerCase() === 'y' || seedCorals.toLowerCase() === 'yes'}
SEED_SPECIES=${seedSpecies.toLowerCase() === 'y' || seedSpecies.toLowerCase() === 'yes'}
SEED_USERS=${seedUsers.toLowerCase() === 'y' || seedUsers.toLowerCase() === 'yes'}
`;

    // Write .env file
    try {
        fs.writeFileSync(envPath, envContent);
        console.log('\n✅ .env file created successfully!');
    } catch (error) {
        console.error('❌ Error creating .env file:', error.message);
        rl.close();
        return;
    }

    console.log('\n📦 Installing dependencies...');
    console.log('Run the following command to install dependencies:');
    console.log('npm install');

    console.log('\n🚀 Next steps:');
    console.log('1. Run: npm install');
    console.log('2. Run: npm run seed --help');
    console.log('3. Run: npm run seed --all');

    console.log('\n✨ Setup completed!');
    rl.close();
}

setup().catch(error => {
    console.error('❌ Setup failed:', error.message);
    rl.close();
    process.exit(1);
}); 