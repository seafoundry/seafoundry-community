#!/usr/bin/env node
/**
 * Check event data shapes for potential issues that could cause
 * "e.entries is not a function" errors in compiled Dart code.
 */
const admin = require('firebase-admin');
const { requireEmulatorOrDemo, resolveProjectId } = require('./lib/require-emulator-or-demo');

const projectId = resolveProjectId();
requireEmulatorOrDemo('check-event-shapes.js', projectId);

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});

const db = admin.firestore();
const TARGET_ORG_ID = process.env.DEMO_ORG_ID || 'demo_org_community';

async function checkEventDataShapes() {
  console.log('=== Checking Event Data Shapes ===\n');

  const eventSnap = await db.collection('events')
    .where('organizationId', '==', TARGET_ORG_ID)
    .limit(500)
    .get();

  console.log('Total events:', eventSnap.size);

  const issues = [];
  const fieldTypes = {};

  eventSnap.forEach(doc => {
    const data = doc.data();
    const id = data.id || doc.id;
    const eventType = data.eventTypeId || 'unknown';

    // Track all field types across events
    for (const [key, value] of Object.entries(data)) {
      const type = Array.isArray(value) ? 'array' : typeof value;
      if (!fieldTypes[key]) fieldTypes[key] = new Set();
      fieldTypes[key].add(type);

      // Check for fields that should be Maps but might not be
      if (key === 'data' && value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          issues.push({ id, eventType, field: 'data', issue: 'is Array instead of Map', sample: JSON.stringify(value).slice(0, 100) });
        }
      }
      if (key === 'changes' && value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          issues.push({ id, eventType, field: 'changes', issue: 'is Array instead of Map' });
        }
      }
      if (key === 'snapshotData' && value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          issues.push({ id, eventType, field: 'snapshotData', issue: 'is Array instead of Map' });
        }
      }
      if (key === 'metadata' && value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          issues.push({ id, eventType, field: 'metadata', issue: 'is Array instead of Map' });
        }
      }
      if (key === 'manifest' && value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          issues.push({ id, eventType, field: 'manifest', issue: 'is Array instead of Map' });
        }
      }
      if (key === 'allocations' && value !== null && value !== undefined) {
        // allocations should be an array
        if (!Array.isArray(value)) {
          issues.push({ id, eventType, field: 'allocations', issue: 'is ' + typeof value + ' instead of Array' });
        }
      }
      if (key === 'deductionSummary' && value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          issues.push({ id, eventType, field: 'deductionSummary', issue: 'is Array instead of Map' });
        }
      }
      if (key === 'parameterValues' && value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          issues.push({ id, eventType, field: 'parameterValues', issue: 'is Array instead of Map' });
        }
      }
    }
  });

  console.log('\n=== Field Type Summary (showing inconsistent types) ===');
  for (const [field, types] of Object.entries(fieldTypes).sort()) {
    const typeList = Array.from(types).join(', ');
    if (types.size > 1) {
      console.log('⚠️ ', field + ':', typeList, '(INCONSISTENT)');
    }
  }

  console.log('\n=== Issues Found ===');
  if (issues.length === 0) {
    console.log('✅ No data shape issues found');
  } else {
    console.log('❌ Found', issues.length, 'issues:');
    issues.forEach(i => {
      console.log('  -', i.eventType, i.id.slice(0, 40) + '...', i.field, i.issue);
      if (i.sample) console.log('    Sample:', i.sample);
    });
  }

  process.exit(0);
}

checkEventDataShapes().catch(e => { console.error(e); process.exit(1); });
