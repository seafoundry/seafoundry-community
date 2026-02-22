#!/usr/bin/env node
/**
 * Check for null/undefined fields that might be causing issues
 */
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function checkNullFields() {
  console.log('=== Checking All Field Types ===\n');

  const eventSnap = await db.collection('events')
    .where('organizationId', '==', 'demo_org_pro')
    .limit(500)
    .get();

  console.log('Total events:', eventSnap.size);

  const fieldStats = {};

  eventSnap.forEach(doc => {
    const data = doc.data();

    for (const [key, value] of Object.entries(data)) {
      if (!fieldStats[key]) {
        fieldStats[key] = { types: {}, nullCount: 0, total: 0 };
      }
      fieldStats[key].total++;

      if (value === null) {
        fieldStats[key].nullCount++;
        fieldStats[key].types['null'] = (fieldStats[key].types['null'] || 0) + 1;
      } else if (value === undefined) {
        fieldStats[key].types['undefined'] = (fieldStats[key].types['undefined'] || 0) + 1;
      } else if (Array.isArray(value)) {
        fieldStats[key].types['array'] = (fieldStats[key].types['array'] || 0) + 1;
      } else {
        const type = typeof value;
        fieldStats[key].types[type] = (fieldStats[key].types[type] || 0) + 1;
      }
    }
  });

  console.log('\n=== Fields with multiple types ===');
  for (const [field, stats] of Object.entries(fieldStats).sort()) {
    const typeCount = Object.keys(stats.types).length;
    if (typeCount > 1) {
      const typeStr = Object.entries(stats.types)
        .map(([t, c]) => `${t}(${c})`)
        .join(', ');
      console.log(`⚠️  ${field}: ${typeStr}`);
    }
  }

  console.log('\n=== Fields with null values ===');
  for (const [field, stats] of Object.entries(fieldStats).sort()) {
    if (stats.nullCount > 0) {
      console.log(`  ${field}: ${stats.nullCount} nulls out of ${stats.total}`);
    }
  }

  process.exit(0);
}

checkNullFields().catch(e => { console.error(e); process.exit(1); });
