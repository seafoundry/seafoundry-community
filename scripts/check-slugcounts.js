const admin = require('firebase-admin');
const fs = require('fs');

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || './firebase-service-account.json';
const creds = JSON.parse(fs.readFileSync(credPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(creds),
});

const db = admin.firestore();

async function check() {
  const orgId = '3c3WxBnZX4aTSObOjqJX';
  
  console.log('Checking slugCounts for org:', orgId);
  
  const slugCountsRef = db.collection('organizations').doc(orgId).collection('slugCounts');
  const snapshot = await slugCountsRef.get();
  
  if (snapshot.empty) {
    console.log('NO slugCounts documents found!');
  } else {
    console.log('slugCounts documents:');
    snapshot.forEach(doc => {
      console.log(' -', doc.id, ':', doc.data());
    });
  }
}

check().then(() => process.exit(0)).catch(console.error);
