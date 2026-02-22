#!/usr/bin/env node
/**
 * Diagnose missing site records referenced by groups and optionally restore from create events.
 *
 * Usage:
 *   node scripts/diagnose-missing-sites.js --email=dev@seafoundry.com
 *   node scripts/diagnose-missing-sites.js --org=ORG_ID
 *   node scripts/diagnose-missing-sites.js --email=dev@seafoundry.com --repair
 */

require('dotenv').config();
const { admin, db } = require('./config-json');

function argValue(prefix) {
  const arg = process.argv.find((entry) => entry.startsWith(`${prefix}=`));
  if (!arg) return null;
  return arg.slice(prefix.length + 1);
}

const emailArg = argValue('--email') || process.env.EMAIL || null;
const orgArg = argValue('--org') || process.env.ORG_ID || null;
const siteArg = argValue('--site') || argValue('--site-id') || null;
const shouldRepair = process.argv.includes('--repair');

async function resolveUserByEmail(email) {
  if (!email) return null;
  const normalizedEmail = email.toLowerCase();

  let authUser = null;
  try {
    authUser = await admin.auth().getUserByEmail(normalizedEmail);
  } catch (_) {
    // Auth user may not exist for emulator-only setups.
  }

  const candidateIds = [];
  if (authUser?.uid) candidateIds.push(authUser.uid);
  candidateIds.push(normalizedEmail);

  for (const id of candidateIds) {
    const doc = await db.collection('users').doc(id).get();
    if (doc.exists) {
      return { id: doc.id, data: doc.data(), authUser };
    }
  }

  const byEmail = await db
    .collection('users')
    .where('email', '==', normalizedEmail)
    .limit(1)
    .get();
  if (!byEmail.empty) {
    const doc = byEmail.docs[0];
    return { id: doc.id, data: doc.data(), authUser };
  }

  return null;
}

function deriveSlug(siteData) {
  if (siteData?.slug) return siteData.slug;
  const urlPath = siteData?.urlPath || '';
  const parts = urlPath.split('/').filter(Boolean);
  if (parts.length > 1) return parts[parts.length - 1];
  const name = siteData?.name || 'site';
  return name
    .toString()
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-_ ]/g, '')
    .replace(/\s+/g, '-');
}

function formatTimestamp(value) {
  if (!value) return 'unknown';
  if (typeof value === 'string') return value;
  if (value.toDate) return value.toDate().toISOString();
  return String(value);
}

async function main() {
  console.log('='.repeat(80));
  console.log('DIAGNOSE MISSING SITES');
  console.log('='.repeat(80));

  let orgId = orgArg;
  let orgDomain = null;

  if (!orgId && !emailArg) {
    console.error('ERROR: Provide --org=ORG_ID or --email=user@example.com');
    process.exit(1);
  }

  if (!orgId) {
    const userResult = await resolveUserByEmail(emailArg);
    if (!userResult) {
      console.error(`ERROR: No user found for ${emailArg}`);
      process.exit(1);
    }
    const userData = userResult.data || {};
    orgId = userData.organizationId;
    console.log(`User resolved: ${userResult.id}`);
    console.log(`User organizationId: ${orgId}`);
  }

  if (!orgId) {
    console.error('ERROR: Unable to resolve organizationId.');
    process.exit(1);
  }

  const orgDoc = await db.collection('organizations').doc(orgId).get();
  if (orgDoc.exists) {
    const orgData = orgDoc.data() || {};
    orgDomain = orgData.domain || orgData.slug || null;
  }

  console.log(`Organization: ${orgId}${orgDomain ? ` (${orgDomain})` : ''}`);
  console.log(`Repair mode: ${shouldRepair ? 'ON' : 'OFF'}`);

  const sitesSnap = await db
    .collection('sites')
    .where('organizationId', '==', orgId)
    .get();
  const sitesById = new Map();
  for (const doc of sitesSnap.docs) {
    sitesById.set(doc.id, doc.data());
  }

  console.log('\nSites in /sites:');
  if (sitesById.size === 0) {
    console.log('  (none)');
  } else {
    for (const [id, data] of sitesById.entries()) {
      console.log(
        `  - ${id}: name="${data.name}", type="${data.siteTypeId}", urlPath="${data.urlPath}"`,
      );
    }
  }

  const groupsSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('groups')
    .get();

  const siteIdsFromGroups = new Set();
  for (const doc of groupsSnap.docs) {
    const data = doc.data() || {};
    if (data.siteId) {
      siteIdsFromGroups.add(data.siteId);
    }
  }

  const missingSiteIds = [...siteIdsFromGroups].filter(
    (id) => !sitesById.has(id),
  );

  console.log('\nReferenced siteIds (from groups):', siteIdsFromGroups.size);
  if (missingSiteIds.length === 0) {
    console.log('✅ No missing site records detected.');
  }

  if (missingSiteIds.length > 0) {
    console.log('\n❗ Missing site records:');
    for (const siteId of missingSiteIds) {
      console.log(`  - ${siteId}`);
    }
  }

  const inspectSiteIds = siteArg ? [siteArg] : missingSiteIds;
  if (inspectSiteIds.length === 0) {
    return;
  }

  for (const siteId of inspectSiteIds) {
    const siteEventSnap = await db
      .collection('events')
      .where('recordId', '==', siteId)
      .limit(10)
      .get();

    if (!siteEventSnap.empty) {
      const events = siteEventSnap.docs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) => {
          const aTime = a.createdAt?.toDate?.()?.getTime?.() ?? 0;
          const bTime = b.createdAt?.toDate?.()?.getTime?.() ?? 0;
          return bTime - aTime;
        });

      console.log(`\nRecent events for site ${siteId}:`);
      for (const event of events) {
        console.log(
          `  - ${event.eventTypeId || 'event_unknown'} @ ${formatTimestamp(
            event.createdAt,
          )} (id=${event.id})`,
        );
      }
    }

    let deletionSnap = null;
    try {
      deletionSnap = await db
        .collection('events')
        .where('deletedRecordId', '==', siteId)
        .limit(5)
        .get();
    } catch (error) {
      console.log(
        `\nDeletion event lookup failed for ${siteId}: ${error.message ?? error}`,
      );
    }

    if (deletionSnap && !deletionSnap.empty) {
      console.log(`\nDeletion events for site ${siteId}:`);
      for (const doc of deletionSnap.docs) {
        const data = doc.data() || {};
        console.log(
          `  - ${data.eventTypeId || 'event_unknown'} @ ${formatTimestamp(
            data.createdAt,
          )} (id=${doc.id})`,
        );
      }
    } else if (deletionSnap) {
      console.log(`\nNo deletion events found for site ${siteId}.`);
    }

    const eventSnap = await db
      .collection('events')
      .where('recordId', '==', siteId)
      .limit(5)
      .get();

    const eventDoc = eventSnap.docs.find((doc) => {
      const data = doc.data() || {};
      return data.recordModelType === 'site' && data.snapshotData;
    });

    if (!eventDoc) {
      console.log(`\nNo create event snapshot found for site ${siteId}`);
      continue;
    }

    const snapshotData = eventDoc.data().snapshotData || {};
    const restored = {
      ...snapshotData,
      id: snapshotData.id || siteId,
      organizationId: snapshotData.organizationId || orgId,
    };
    restored.slug = deriveSlug(restored);

    console.log(`\nRecovered snapshot for site ${siteId}:`);
    console.log(
      `  name="${restored.name}" type="${restored.siteTypeId}" urlPath="${restored.urlPath}" slug="${restored.slug}"`,
    );

    if (!missingSiteIds.includes(siteId)) {
      console.log('  (info) Site record exists; skip restore.');
      continue;
    }

    if (shouldRepair) {
      await db.collection('sites').doc(siteId).set(restored, { merge: true });
      console.log('  ✅ Restored site document in /sites');
    } else {
      console.log('  (dry-run) Use --repair to restore this site.');
    }
  }
}

main()
  .then(() => {
    console.log('\nDone.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('FATAL:', error);
    process.exit(1);
  });
