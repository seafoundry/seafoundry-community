require('dotenv').config();
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const { requireEmulatorOrDemo } = require('./lib/require-emulator-or-demo');

// Try to load service account from explicit env path first, then local JSON file
let serviceAccount = null;
const serviceAccountPath = path.join(process.cwd(), 'firebase-service-account.json');
const envServiceAccountPath =
    process.env.FIREBASE_SERVICE_ACCOUNT ||
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (envServiceAccountPath && fs.existsSync(envServiceAccountPath)) {
    console.log(`📁 Loading Firebase credentials from ${envServiceAccountPath}...`);
    serviceAccount = require(path.resolve(envServiceAccountPath));
} else if (fs.existsSync(serviceAccountPath)) {
    console.log('📁 Loading Firebase credentials from JSON file...');
    serviceAccount = require(serviceAccountPath);
} else {
    console.log('📁 Loading Firebase credentials from environment variables...');
    // Fallback to environment variables
    serviceAccount = {
        type: 'service_account',
        project_id: process.env.FIREBASE_PROJECT_ID || 'demo-seafoundry',
        private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
        private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        client_email: process.env.FIREBASE_CLIENT_EMAIL,
        client_id: process.env.FIREBASE_CLIENT_ID,
        auth_uri: process.env.FIREBASE_AUTH_URI || 'https://accounts.google.com/o/oauth2/auth',
        token_uri: process.env.FIREBASE_TOKEN_URI || 'https://oauth2.googleapis.com/token',
        auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL || 'https://www.googleapis.com/oauth2/v1/certs',
        client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL,
    };
}

// Detect emulator mode
const isEmulator = !!(process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST);

// Resolve target project ID with this precedence:
//   1. explicit FIREBASE_PROJECT_ID env var
//   2. GCLOUD_PROJECT env var
//   3. project_id baked into the service-account JSON
//   4. demo-seafoundry default (so the safety check in seed-demo.js fires)
const resolvedProjectId =
    process.env.FIREBASE_PROJECT_ID ||
    process.env.GCLOUD_PROJECT ||
    (serviceAccount && serviceAccount.project_id) ||
    'demo-seafoundry';

// Authoritative safety guard: validate the EXACT project id passed to
// admin.initializeApp() below. Positioned immediately before init so the guarded
// id and the SDK-targeted id are the same variable (resolvedProjectId).
requireEmulatorOrDemo('config-json.js', resolvedProjectId);

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
    try {
        if (isEmulator && (!serviceAccount || !serviceAccount.private_key)) {
            // Emulator mode: no real credentials needed
            console.log('📁 Using emulator mode (no credentials required)...');
            admin.initializeApp({ projectId: resolvedProjectId });
        } else if (serviceAccount && serviceAccount.type === 'authorized_user') {
            // ADC user credentials — use applicationDefault() instead of cert()
            console.log('📁 Using Application Default Credentials (authorized_user)...');
            admin.initializeApp({ projectId: resolvedProjectId });
        } else {
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
                projectId: resolvedProjectId,
            });
        }
        console.log(`✅ Firebase Admin SDK initialized successfully (project: ${resolvedProjectId})`);
    } catch (error) {
        console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
        throw error;
    }
}

const db = admin.firestore();

// Seeding configuration
const config = {
    environment: process.env.NODE_ENV || 'development',
    seedOptions: {
        organizations: process.env.SEED_ORGANIZATIONS !== 'false',
        sites: process.env.SEED_SITES !== 'false',
        groups: process.env.SEED_GROUPS !== 'false',
        corals: process.env.SEED_CORALS !== 'false',
        species: process.env.SEED_SPECIES !== 'false',
        users: process.env.SEED_USERS !== 'false',
        genets: process.env.SEED_GENETS !== 'false',
        events: process.env.SEED_EVENTS !== 'false',
    },
    collections: {
        organizations: 'organizations',
        sites: 'sites',
        groups: 'groups',
        corals: 'corals',
        species: 'species',
        users: 'users',
        events: 'events',
        types: 'types',
    },
};

module.exports = { admin, db, config }; 
