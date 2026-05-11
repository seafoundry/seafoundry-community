#!/usr/bin/env node
/**
 * Check specific inconsistent fields in events
 */
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();
const TARGET_ORG_ID = process.env.DEMO_ORG_ID || 'demo_org_community';

async function checkInconsistentFields() {
  console.log('=== Checking Inconsistent Fields ===\n');

  const eventSnap = await db.collection('events')
    .where('organizationId', '==', TARGET_ORG_ID)
    .limit(500)
    .get();

  console.log('Total events:', eventSnap.size);

  const healthIssueExamples = [];
  const husbandryActionExamples = [];

  eventSnap.forEach(doc => {
    const data = doc.data();
    const id = data.id || doc.id;
    const eventType = data.eventTypeId || 'unknown';

    // Check healthIssueTypeId
    if (data.healthIssueTypeId !== undefined && data.healthIssueTypeId !== null) {
      const type = typeof data.healthIssueTypeId;
      if (type === 'object') {
        healthIssueExamples.push({
          id: id.slice(0, 50),
          eventType,
          value: JSON.stringify(data.healthIssueTypeId),
        });
      }
    }

    // Check husbandryActionTypeId
    if (data.husbandryActionTypeId !== undefined && data.husbandryActionTypeId !== null) {
      const type = typeof data.husbandryActionTypeId;
      if (type === 'object') {
        husbandryActionExamples.push({
          id: id.slice(0, 50),
          eventType,
          value: JSON.stringify(data.husbandryActionTypeId),
        });
      }
    }
  });

  console.log('\n=== healthIssueTypeId issues ===');
  if (healthIssueExamples.length === 0) {
    console.log('✅ All healthIssueTypeId values are strings');
  } else {
    console.log('❌ Found', healthIssueExamples.length, 'events with object healthIssueTypeId:');
    healthIssueExamples.slice(0, 5).forEach(e => {
      console.log('  -', e.eventType, ':', e.id);
      console.log('    Value:', e.value);
    });
  }

  console.log('\n=== husbandryActionTypeId issues ===');
  if (husbandryActionExamples.length === 0) {
    console.log('✅ All husbandryActionTypeId values are strings');
  } else {
    console.log('❌ Found', husbandryActionExamples.length, 'events with object husbandryActionTypeId:');
    husbandryActionExamples.slice(0, 5).forEach(e => {
      console.log('  -', e.eventType, ':', e.id);
      console.log('    Value:', e.value);
    });
  }

  process.exit(0);
}

checkInconsistentFields().catch(e => { console.error(e); process.exit(1); });
