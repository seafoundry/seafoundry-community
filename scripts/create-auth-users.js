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
    console.error('     FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 node scripts/create-auth-users.js');
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

async function createAuthUsers() {
    try {
        console.log('🔐 Creating Firebase Authentication users...');
        
        // Create admin user
        const adminUser = await admin.auth().createUser({
            email: 'admin@seafoundry.com',
            password: 'admin123456',
            displayName: 'Admin User',
            emailVerified: true
        });
        
        console.log('✅ Created admin user:', adminUser.uid);
        
        // Create test users from sample data
        const testUsers = [
            {
                email: 'john.smith@example.com',
                password: 'password123',
                displayName: 'John Smith'
            },
            {
                email: 'sarah.johnson@example.com',
                password: 'password123',
                displayName: 'Sarah Johnson'
            },
            {
                email: 'mike.chen@example.com',
                password: 'password123',
                displayName: 'Mike Chen'
            }
        ];
        
        for (const userData of testUsers) {
            try {
                const user = await admin.auth().createUser({
                    email: userData.email,
                    password: userData.password,
                    displayName: userData.displayName,
                    emailVerified: true
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
        console.log('\n📋 Login Credentials:');
        console.log('Admin: admin@seafoundry.com / admin123456');
        console.log('Test Users:');
        console.log('  - john.smith@example.com / password123');
        console.log('  - sarah.johnson@example.com / password123');
        console.log('  - mike.chen@example.com / password123');
        
    } catch (error) {
        console.error('❌ Error creating authentication users:', error.message);
        process.exit(1);
    }
}

createAuthUsers();
