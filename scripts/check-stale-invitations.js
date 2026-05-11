#!/usr/bin/env node
/**
 * Check for stale invitations for a given email
 * Usage: EMAIL=user@example.com GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/check-stale-invitations.js
 */
const admin = require('firebase-admin');
const fs = require('fs');

const EMAIL = process.env.EMAIL;
if (!EMAIL) {
  console.error('ERROR: EMAIL environment variable is required');
  console.error('Usage: EMAIL=user@example.com GOOGLE_APPLICATION_CREDENTIALS=./path/to/creds.json node scripts/check-stale-invitations.js');
  process.exit(1);
}

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
if (!fs.existsSync(credPath)) {
  console.error('ERROR: Credentials file not found:', credPath);
  process.exit(1);
}

const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(creds) });
const db = admin.firestore();

async function checkStaleInvitations() {
  console.log('='.repeat(60));
  console.log('CHECKING INVITATIONS FOR:', EMAIL);
  console.log('='.repeat(60));

  // Check pending invitations
  const invitationsSnap = await db.collection('invitations')
    .where('email', '==', EMAIL.toLowerCase())
    .where('status', '==', 'pending')
    .get();

  if (invitationsSnap.empty) {
    console.log('\n✅ No pending invitations found for', EMAIL);
    return;
  }

  console.log(`\n⚠️  Found ${invitationsSnap.size} pending invitation(s):\n`);
  
  for (const doc of invitationsSnap.docs) {
    const data = doc.data();
    console.log(`   ID: ${doc.id}`);
    console.log(`   Organization: ${data.organizationId}`);
    console.log(`   Role: ${data.role || 'user'}`);
    console.log(`   Created: ${data.createdAt}`);
    console.log(`   Status: ${data.status}`);
    
    // Check if the organization still exists
    const orgDoc = await db.collection('organizations').doc(data.organizationId).get();
    if (!orgDoc.exists) {
      console.log(`   ❌ STALE: Organization no longer exists!`);
    } else {
      console.log(`   ✓ Organization exists: ${orgDoc.data().name}`);
    }
    console.log('');
  }

  console.log('To delete these invitations, run with --delete flag');
}

checkStaleInvitations()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
