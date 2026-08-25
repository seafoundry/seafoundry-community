#!/usr/bin/env node

/**
 * Generate dart_defines.json from .env file
 * This file is used by VS Code launch configurations and run.sh
 */

const fs = require('fs');
const path = require('path');

// Read .env file (allow override for staging or other environments)
const envFileOverride = process.env.ENV_FILE;
const envPath = envFileOverride
    ? path.resolve(process.cwd(), envFileOverride)
    : path.join(__dirname, '..', '.env');
const outputOverride = process.env.DART_DEFINES_OUTPUT;
const outputPath = outputOverride
    ? path.resolve(process.cwd(), outputOverride)
    : path.join(__dirname, '..', 'dart_defines.json');

if (!fs.existsSync(envPath)) {
    console.error('Error: .env file not found');
    console.log('Please create a .env file from .env.example');
    if (envFileOverride) {
        console.log(`Requested ENV_FILE: ${envPath}`);
    }
    process.exit(1);
}

// Environment variables to exclude from Flutter
// These are typically Node.js/backend specific
const EXCLUDE_VARS = [
    'NODE_ENV',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_PRIVATE_KEY_ID', 
    'FIREBASE_PRIVATE_KEY',
    'FIREBASE_CLIENT_EMAIL',
    'FIREBASE_CLIENT_ID',
    'FIREBASE_AUTH_URI',
    'FIREBASE_TOKEN_URI',
    'FIREBASE_AUTH_PROVIDER_X509_CERT_URL',
    'FIREBASE_CLIENT_X509_CERT_URL'
    // Note: FIREBASE_API_KEY is now included for Flutter
];

// Parse .env file
const envContent = fs.readFileSync(envPath, 'utf8');
const envVars = {};

envContent.split('\n').forEach(line => {
    // Skip comments and empty lines
    if (line.startsWith('#') || !line.trim()) return;
    
    const [key, ...valueParts] = line.split('=');
    if (key && valueParts.length > 0) {
        const trimmedKey = key.trim();
        const value = valueParts.join('=').trim();
        
        // Include all vars except those in the exclude list
        // This way new Flutter env vars are automatically included
        if (!EXCLUDE_VARS.includes(trimmedKey)) {
            envVars[trimmedKey] = value;
        }
    }
});

// Write to dart_defines.json
fs.writeFileSync(outputPath, JSON.stringify(envVars, null, 2));
console.log(`✅ Generated ${path.relative(process.cwd(), outputPath)} with ${Object.keys(envVars).length} variables`);
