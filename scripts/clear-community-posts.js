#!/usr/bin/env node

/**
 * Clear all community posts and optional community comments.
 *
 * Usage:
 *   node scripts/clear-community-posts.js --dry-run
 *   node scripts/clear-community-posts.js --execute
 *   node scripts/clear-community-posts.js --execute --skip-comments
 *
 * Options:
 *   --dry-run        Preview deletions (DEFAULT)
 *   --execute        Perform deletions
 *   --force          Alias for --execute
 *   --skip-comments  Do not delete post_comments
 *   --limit=NUM      Limit number of posts deleted
 *   --batch-size=NUM Batch size for deletions (default: 500)
 */

require('dotenv').config();
const readline = require('readline');
const { db } = require('./config-json');
const { FieldPath } = require('firebase-admin/firestore');

const args = process.argv.slice(2);
const hasExecute = args.includes('--execute') || args.includes('--force');
const dryRun = !hasExecute || args.includes('--dry-run');
const skipComments = args.includes('--skip-comments');

const limitArg = args.find((arg) => arg.startsWith('--limit='));
const limit = limitArg ? Number(limitArg.split('=')[1]) : null;

const batchArg = args.find((arg) => arg.startsWith('--batch-size='));
const batchSize = batchArg ? Number(batchArg.split('=')[1]) : 500;

if (Number.isNaN(batchSize) || batchSize <= 0) {
  console.error('Invalid --batch-size value.');
  process.exit(1);
}

if (limit != null && (Number.isNaN(limit) || limit <= 0)) {
  console.error('Invalid --limit value.');
  process.exit(1);
}

async function promptConfirmation(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(message, (answer) => {
      rl.close();
      resolve(answer.toLowerCase() === 'yes');
    });
  });
}

async function deleteCommunityPosts() {
  console.log('🧹 Clearing community posts...');
  let deleted = 0;
  let scanned = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection('events')
      .where('metadata.isCommunityPost', '==', true)
      .orderBy(FieldPath.documentId())
      .limit(batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    const matches = snapshot.docs.filter((doc) => {
      const data = doc.data() || {};
      return data.scope === 'community';
    });

    scanned += snapshot.docs.length;

    const targets = limit != null
      ? matches.slice(0, Math.max(limit - deleted, 0))
      : matches;

    if (targets.length === 0) {
      if (limit != null && deleted >= limit) break;
      continue;
    }

    if (!dryRun) {
      const batch = db.batch();
      targets.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    deleted += targets.length;
    console.log(
      `  ${dryRun ? 'Would delete' : 'Deleted'} ${targets.length} posts ` +
        `(total ${deleted})`
    );

    if (limit != null && deleted >= limit) {
      break;
    }
  }

  return { deleted, scanned };
}

async function deleteCommunityComments() {
  console.log('🧹 Clearing post_comments...');
  let deleted = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection('post_comments')
      .orderBy(FieldPath.documentId())
      .limit(batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    if (!dryRun) {
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    deleted += snapshot.docs.length;
    console.log(
      `  ${dryRun ? 'Would delete' : 'Deleted'} ${snapshot.docs.length} comments ` +
        `(total ${deleted})`
    );
  }

  return deleted;
}

async function main() {
  console.log('='.repeat(60));
  console.log('Community post cleanup');
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'EXECUTE'}`);
  console.log(`Skip comments: ${skipComments ? 'Yes' : 'No'}`);
  if (limit != null) console.log(`Limit: ${limit}`);
  console.log('='.repeat(60));

  if (dryRun) {
    console.log('⚠️  Dry run mode - no deletions will be performed.');
  } else {
    const ok = await promptConfirmation(
      'This will permanently delete community posts. Type "yes" to continue: '
    );
    if (!ok) {
      console.log('Aborted.');
      process.exit(0);
    }
  }

  const postStats = await deleteCommunityPosts();
  let commentStats = null;
  if (!skipComments) {
    commentStats = await deleteCommunityComments();
  }

  console.log('\n✅ Done');
  console.log(`Posts scanned: ${postStats.scanned}`);
  console.log(`Posts ${dryRun ? 'matched' : 'deleted'}: ${postStats.deleted}`);
  if (!skipComments) {
    console.log(`Comments ${dryRun ? 'matched' : 'deleted'}: ${commentStats}`);
  }
}

main().catch((error) => {
  console.error('❌ Error clearing community posts:', error);
  process.exit(1);
});
