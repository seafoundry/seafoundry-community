#!/usr/bin/env node

/**
 * Creates demo/test Firebase Authentication users.
 * SAFETY: Only runs against emulators or demo projects to prevent
 * accidental creation of test users in production.
 */

const { admin } = require('./config');

// Safety check: prevent running against production
function checkSafeEnvironment() {
  const isEmulator = !!(
    process.env.FIRESTORE_EMULATOR_HOST ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST
  );
  const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || '';
  const isDemoProject = projectId.startsWith('demo-');

  if (!isEmulator && !isDemoProject) {
    console.error('❌ SAFETY: This script only runs against emulators or demo projects.');
    console.error('   Detected project:', projectId || '(unknown)');
    console.error('');
    console.error('   To run against emulator:');
    console.error('     FIREBASE_AUTH_EMULATOR_HOST=localhost:9555 node scripts/create-auth-users.js');
    console.error('');
    console.error('   Or use a demo project ID starting with "demo-"');
    process.exit(1);
  }

  if (isEmulator) {
    console.log('✓ Running against emulator');
  } else {
    console.log(`✓ Running against demo project: ${projectId}`);
  }
}

checkSafeEnvironment();

const DEMO_ADMIN_EMAIL = process.env.DEMO_ADMIN_EMAIL || 'admin@example.com';
const DEMO_ADMIN_PASSWORD = process.env.DEMO_ADMIN_PASSWORD;
const DEMO_USER_PASSWORD = process.env.DEMO_USER_PASSWORD;

if (!DEMO_ADMIN_PASSWORD || !DEMO_USER_PASSWORD) {
    console.error('❌ Set DEMO_ADMIN_PASSWORD and DEMO_USER_PASSWORD env vars before running.');
    console.error('   Example: DEMO_ADMIN_PASSWORD=$(openssl rand -base64 24) DEMO_USER_PASSWORD=$(openssl rand -base64 24) node scripts/create-auth-users.js');
    process.exit(1);
}

async function createAuthUsers() {
    try {
        console.log('🔐 Creating Firebase Authentication users...');

        const adminUser = await admin.auth().createUser({
            email: DEMO_ADMIN_EMAIL,
            password: DEMO_ADMIN_PASSWORD,
            displayName: 'Admin User',
            emailVerified: true
        });

        console.log('✅ Created admin user:', adminUser.uid);

        const testUsers = [
            { email: 'user1@example.com', displayName: 'Demo User 1' },
            { email: 'user2@example.com', displayName: 'Demo User 2' },
            { email: 'user3@example.com', displayName: 'Demo User 3' },
        ];

        for (const userData of testUsers) {
            try {
                const user = await admin.auth().createUser({
                    email: userData.email,
                    password: DEMO_USER_PASSWORD,
                    displayName: userData.displayName,
                    emailVerified: true,
                });
                console.log('✅ Created user:', userData.email, user.uid);
            } catch (error) {
                if (error.code === 'auth/email-already-exists') {
                    console.log('⚠️  User already exists:', userData.email);
                } else {
                    console.error('❌ Error creating user:', userData.email, error.message);
                }
            }
        }

        console.log('\n🎉 Firebase Authentication users created successfully!');
        console.log(`Admin: ${DEMO_ADMIN_EMAIL}`);
        console.log('Test users: user1@example.com, user2@example.com, user3@example.com');
        console.log('(Passwords set from DEMO_ADMIN_PASSWORD / DEMO_USER_PASSWORD env vars — not logged.)');
    } catch (error) {
        console.error('❌ Error creating authentication users:', error.message);
        process.exit(1);
    }
}

createAuthUsers();
