#!/usr/bin/env node

/**
 * Normalizes `updatedAt` values inside the observation override history
 * collection and the `timestamp` field inside `taxonomy_audit` so legacy string
 * values no longer break ordered queries.
 *
 * Usage:
 *   node scripts/backfill_override_history_timestamps.js [--dry-run]
 *        [--force] [--org <id>] [--skip-history] [--skip-audit]
 *        [--history-limit <n>] [--audit-limit <n>]
 *        [--history-page-size <n>] [--audit-page-size <n>]
 *        [--commit-size <n>] [--verbose]
 */

const { admin, db } = require('./config-json');
const readline = require('readline');

const args = process.argv.slice(2);
const options = {
  dryRun: args.includes('--dry-run') || args.includes('-d'),
  force: args.includes('--force') || args.includes('-f'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  skipHistory: args.includes('--skip-history'),
  skipAudit: args.includes('--skip-audit'),
  historyLimit: null,
  auditLimit: null,
  historyPageSize: 200,
  auditPageSize: 500,
  commitSize: 400,
  organizationId: null,
  help: args.includes('--help') || args.includes('-h')
};

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--org' || arg === '--organization') {
    options.organizationId = (args[i + 1] || '').trim() || null;
    i += 1;
  } else if (arg === '--history-limit') {
    options.historyLimit = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--audit-limit') {
    options.auditLimit = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--history-page-size') {
    options.historyPageSize = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--audit-page-size') {
    options.auditPageSize = parseInt(args[i + 1], 10);
    i += 1;
  } else if (arg === '--commit-size') {
    options.commitSize = parseInt(args[i + 1], 10);
    i += 1;
  }
}

if (options.help) {
  console.log(`
🕒 Override History & Taxonomy Audit Timestamp Backfill

Converts legacy string/Date values in:
  • observation_field_overrides/<org>/history/<entry>.updatedAt
  • taxonomy_audit/<entry>.timestamp
into Firestore Timestamps so ordered queries behave consistently.

Options:
  --dry-run, -d             Preview changes without writing to Firestore
  --force, -f              Skip confirmation prompt
  --org, --organization    Limit override history processing to one org
  --skip-history           Skip the override history portion
  --skip-audit             Skip the taxonomy audit portion
  --history-limit <n>      Process only the first <n> history entries
  --audit-limit <n>        Process only the first <n> audit entries
  --history-page-size <n>  Docs to fetch per history query (default: 200)
  --audit-page-size <n>    Docs to fetch per audit query (default: 500)
  --commit-size <n>        Number of updates per batch commit (default: 400)
  --verbose, -v            Log each mutation
  --help, -h               Show this help text
`);
  process.exit(0);
}

const stats = {
  history: {
    orgs: 0,
    scanned: 0,
    updated: 0,
    skipped: 0,
    missing: 0,
    limitReached: false
  },
  audit: {
    scanned: 0,
    updated: 0,
    skipped: 0,
    missing: 0,
    limitReached: false
  }
};

async function prompt(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  return new Promise((resolve) => {
    rl.question(message, (answer) => {
      rl.close();
      resolve(answer.trim().toLowerCase().startsWith('y'));
    });
  });
}

function parseDate(value) {
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === 'number') {
    if (value > 1e12) {
      return new Date(value);
    }
    return new Date(value * 1000);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  if (
    value &&
    typeof value === 'object' &&
    typeof value.seconds === 'number' &&
    typeof value.nanoseconds === 'number'
  ) {
    return new Date(value.seconds * 1000 + value.nanoseconds / 1e6);
  }
  return null;
}

function normalizeTimestampValue(rawValue, fallbackLabel) {
  if (rawValue instanceof admin.firestore.Timestamp) {
    return { needsUpdate: false };
  }
  const parsed = parseDate(rawValue);
  if (parsed) {
    return {
      needsUpdate: true,
      value: admin.firestore.Timestamp.fromDate(parsed),
      reason: 'parsed'
    };
  }
  return {
    needsUpdate: true,
    value: admin.firestore.FieldValue.serverTimestamp(),
    reason: fallbackLabel || 'serverTimestamp'
  };
}

async function run() {
  if (!options.dryRun && !options.force) {
    const confirmed = await prompt(
      '⚠️  This will rewrite override history and audit timestamps. Continue? (y/N) ',
    );
    if (!confirmed) {
      console.log('Aborting.');
      process.exit(0);
    }
  }

  let batch = db.batch();
  let pending = 0;

  async function flushBatch() {
    if (pending === 0 || options.dryRun) {
      return;
    }
    await batch.commit();
    batch = db.batch();
    pending = 0;
  }

  async function queueUpdate(ref, payload, label) {
    if (options.dryRun) {
      console.log(`📝 [DRY-RUN] ${label}`);
      return;
    }
    batch.update(ref, payload);
    pending += 1;
    if (pending >= options.commitSize) {
      await flushBatch();
    }
  }

  if (!options.skipHistory) {
    await backfillOverrideHistory(queueUpdate);
  } else {
    console.log('⏭️  Skipping override history backfill.');
  }

  if (!options.skipAudit) {
    await backfillTaxonomyAudit(queueUpdate);
  } else {
    console.log('⏭️  Skipping taxonomy audit backfill.');
  }

  await flushBatch();

  console.log('\n✅ Backfill summary:');
  console.table({
    history_scanned: stats.history.scanned,
    history_updated: stats.history.updated,
    history_skipped: stats.history.skipped,
    history_missing: stats.history.missing,
    audit_scanned: stats.audit.scanned,
    audit_updated: stats.audit.updated,
    audit_skipped: stats.audit.skipped,
    audit_missing: stats.audit.missing
  });
}

async function backfillOverrideHistory(queueUpdate) {
  const fieldPath = admin.firestore.FieldPath.documentId();
  let orgIds = [];
  if (options.organizationId) {
    orgIds = [options.organizationId];
  } else {
    const snapshot = await db.collection('observation_field_overrides').get();
    orgIds = snapshot.docs.map((doc) => doc.id);
  }

  for (const orgId of orgIds) {
    const orgRef = db.collection('observation_field_overrides').doc(orgId);
    const exists = await orgRef.get();
    if (!exists.exists) {
      continue;
    }
    stats.history.orgs += 1;

    let cursor = null;
    while (true) {
      let query = orgRef
        .collection('history')
        .orderBy(fieldPath)
        .limit(options.historyPageSize);
      if (cursor) {
        query = query.startAfter(cursor);
      }
      const snapshot = await query.get();
      if (snapshot.empty) {
        break;
      }

      for (const doc of snapshot.docs) {
        if (options.historyLimit && stats.history.scanned >= options.historyLimit) {
          stats.history.limitReached = true;
          break;
        }
        stats.history.scanned += 1;
        const data = doc.data() || {};
        const value =
            data.updatedAt ??
            data.createdAt ??
            data.timestamp ??
            null;
        const normalized = normalizeTimestampValue(value, 'overrideHistory');
        if (!normalized.needsUpdate) {
          stats.history.skipped += 1;
          if (options.verbose) {
            console.log(`✔️  ${orgId}/history/${doc.id}: already timestamp.`);
          }
          continue;
        }
        if (!normalized.value) {
          stats.history.missing += 1;
          if (options.verbose) {
            console.warn(`⚠️  ${orgId}/history/${doc.id}: unable to determine timestamp.`);
          }
          continue;
        }
        stats.history.updated += 1;
        if (options.verbose) {
          console.log(
            `🕒 ${orgId}/history/${doc.id}: backfilling updatedAt (${normalized.reason}).`,
          );
        }
        await queueUpdate(
          doc.ref,
          { updatedAt: normalized.value },
          `${orgId}/history/${doc.id}`,
        );
      }

      if (stats.history.limitReached || snapshot.size < options.historyPageSize) {
        break;
      }
      cursor = snapshot.docs[snapshot.docs.length - 1];
    }

    if (stats.history.limitReached) {
      break;
    }
  }
}

async function backfillTaxonomyAudit(queueUpdate) {
  const fieldPath = admin.firestore.FieldPath.documentId();
  let cursor = null;

  while (true) {
    let query = db
      .collection(TaxonomyAdminServiceAuditCollection())
      .orderBy(fieldPath)
      .limit(options.auditPageSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    for (const doc of snapshot.docs) {
      if (options.auditLimit && stats.audit.scanned >= options.auditLimit) {
        stats.audit.limitReached = true;
        break;
      }
      stats.audit.scanned += 1;
      const data = doc.data() || {};
      const normalized = normalizeTimestampValue(data.timestamp, 'taxonomyAudit');
      if (!normalized.needsUpdate) {
        stats.audit.skipped += 1;
        continue;
      }
      if (!normalized.value) {
        stats.audit.missing += 1;
        continue;
      }
      stats.audit.updated += 1;
      if (options.verbose) {
        console.log(`🕒 taxonomy_audit/${doc.id}: backfilling timestamp (${normalized.reason}).`);
      }
      await queueUpdate(
        doc.ref,
        { timestamp: normalized.value },
        `taxonomy_audit/${doc.id}`,
      );
    }

    if (stats.audit.limitReached || snapshot.size < options.auditPageSize) {
      break;
    }
    cursor = snapshot.docs[snapshot.docs.length - 1];
  }
}

function TaxonomyAdminServiceAuditCollection() {
  return 'taxonomy_audit';
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Backfill failed:', error);
    process.exit(1);
  });
