require('dotenv').config();
const admin = require('firebase-admin');

// Firebase Admin SDK configuration
const serviceAccount = {
    type: 'service_account',
    project_id: process.env.FIREBASE_PROJECT_ID || 'seafoundryapp',
    private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
    private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    client_email: process.env.FIREBASE_CLIENT_EMAIL,
    client_id: process.env.FIREBASE_CLIENT_ID,
    auth_uri: process.env.FIREBASE_AUTH_URI || 'https://accounts.google.com/o/oauth2/auth',
    token_uri: process.env.FIREBASE_TOKEN_URI || 'https://oauth2.googleapis.com/token',
    auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL || 'https://www.googleapis.com/oauth2/v1/certs',
    client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL,
};

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: process.env.FIREBASE_PROJECT_ID || 'seafoundryapp',
    });
}

const db = admin.firestore();

// Seeding configuration
const config = {
    environment: process.env.NODE_ENV || 'development',
    seedOptions: {
        organizations: process.env.SEED_ORGANIZATIONS === 'true',
        sites: process.env.SEED_SITES === 'true',
        groups: process.env.SEED_GROUPS === 'true',
        corals: process.env.SEED_CORALS === 'true',
        species: process.env.SEED_SPECIES === 'true',
        users: process.env.SEED_USERS === 'true',
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