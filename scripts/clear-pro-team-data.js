#!/usr/bin/env node

/**
 * Clear events and comments for pro team members (pro1@provenance.app through pro9@provenance.app)
 * while preserving pro@provenance.app's data.
 * 
 * Note: Inventory (organismRecords) is org-level and cannot be separated by user.
 * This script deletes:
 *   - Events created by pro1-pro9 users
 *   - Events assigned to pro1-pro9 users  
 *   - Comments authored by pro1-pro9 users
 * 
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json node scripts/clear-pro-team-data.js
 *   
 *   # Dry run (show what would be deleted without actually deleting):
 *   node scripts/clear-pro-team-data.js --dry-run
 */

require('dotenv').config();
const { admin, db } = require('./config-json');

const ORG_ID = 'demo_org_pro';
const BATCH_SIZE = 500;

// Get team member emails (pro1 through pro9)
function getTeamMemberEmails() {
  const emails = [];
  for (let i = 1; i <= 9; i++) {
    emails.push(`pro${i}@provenance.app`);
  }
  return emails;
}

async function getUserIdsByEmails(emails) {
  const userIds = [];
  for (const email of emails) {
    try {
      const authUser = await admin.auth().getUserByEmail(email);
      userIds.push(authUser.uid);
      console.log(`Found user ${email} -> ${authUser.uid}`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log(`User ${email} not found, skipping.`);
      } else {
        console.warn(`Error looking up ${email}: ${error.message}`);
      }
    }
  }
  return userIds;
}

async function deleteByQuery(query, label, dryRun = false) {
  let deletedCount = 0;

  while (true) {
    const snapshot = await query.limit(BATCH_SIZE).get();
    if (snapshot.empty) break;

    if (dryRun) {
      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        console.log(`  [DRY RUN] Would delete ${label}: ${doc.id} (${data.eventTypeId || data.content?.substring(0, 30) || 'N/A'})`);
      });
      deletedCount += snapshot.docs.length;
      // In dry run, we need to break after first batch to avoid infinite loop
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deletedCount += snapshot.docs.length;
    console.log(`  Deleted ${deletedCount} ${label} so far...`);

    if (snapshot.docs.length < BATCH_SIZE) break;
  }

  return deletedCount;
}

async function clearEventsCreatedBy(userIds, dryRun = false) {
  console.log('\nClearing events created by team members...');
  let totalDeleted = 0;

  for (const userId of userIds) {
    const query = db.collection('events')
      .where('organizationId', '==', ORG_ID)
      .where('createdById', '==', userId);

    const count = await deleteByQuery(query, `events created by ${userId}`, dryRun);
    totalDeleted += count;
  }

  console.log(`Total events deleted by createdById: ${totalDeleted}`);
  return totalDeleted;
}

async function clearEventsAssignedTo(userIds, dryRun = false) {
  console.log('\nClearing events assigned to team members...');
  let totalDeleted = 0;

  for (const userId of userIds) {
    const query = db.collection('events')
      .where('organizationId', '==', ORG_ID)
      .where('assignedUserId', '==', userId);

    const count = await deleteByQuery(query, `events assigned to ${userId}`, dryRun);
    totalDeleted += count;
  }

  console.log(`Total events deleted by assignedUserId: ${totalDeleted}`);
  return totalDeleted;
}

async function clearOrgComments(userIds, dryRun = false) {
  console.log('\nClearing org comments by team members...');
  let totalDeleted = 0;

  const orgRef = db.collection('organizations').doc(ORG_ID);

  for (const userId of userIds) {
    const query = orgRef.collection('comments')
      .where('authorUid', '==', userId);

    const count = await deleteByQuery(query, `comments by ${userId}`, dryRun);
    totalDeleted += count;
  }

  console.log(`Total org comments deleted: ${totalDeleted}`);
  return totalDeleted;
}

async function clearPostComments(userIds, dryRun = false) {
  console.log('\nClearing post comments by team members...');
  let totalDeleted = 0;

  for (const userId of userIds) {
    const query = db.collection('post_comments')
      .where('authorUid', '==', userId);

    const count = await deleteByQuery(query, `post comments by ${userId}`, dryRun);
    totalDeleted += count;
  }

  console.log(`Total post comments deleted: ${totalDeleted}`);
  return totalDeleted;
}

async function clearChannelMessages(userIds, dryRun = false) {
  console.log('\nClearing channel messages by team members...');
  let totalDeleted = 0;

  // Get all channels in the org
  const channelsSnap = await db.collection('organizations').doc(ORG_ID)
    .collection('channels').get();

  for (const channelDoc of channelsSnap.docs) {
    for (const userId of userIds) {
      const query = channelDoc.ref.collection('messages')
        .where('senderId', '==', userId);

      const count = await deleteByQuery(query, `messages by ${userId} in channel ${channelDoc.id}`, dryRun);
      totalDeleted += count;
    }
  }

  console.log(`Total channel messages deleted: ${totalDeleted}`);
  return totalDeleted;
}

async function clearTrainingProgress(userIds, dryRun = false) {
  console.log('\nClearing training progress for team members...');
  let totalDeleted = 0;

  for (const userId of userIds) {
    // Training progress documents
    const progressId = `${ORG_ID}_${userId}`;
    const progressRef = db.collection('training_progress').doc(progressId);
    const progressSnap = await progressRef.get();

    if (progressSnap.exists) {
      if (dryRun) {
        console.log(`  [DRY RUN] Would delete training_progress: ${progressId}`);
      } else {
        await progressRef.delete();
        console.log(`  Deleted training_progress: ${progressId}`);
      }
      totalDeleted++;
    }

    // SOP completions
    const sopCompletionsQuery = db.collection('sop_completions')
      .where('userId', '==', userId)
      .where('organizationId', '==', ORG_ID);
    const sopCount = await deleteByQuery(sopCompletionsQuery, `sop_completions for ${userId}`, dryRun);
    totalDeleted += sopCount;

    // User training subcollection
    const userTrainingRef = db.collection('users').doc(userId).collection('training');
    const trainingSnap = await userTrainingRef.get();

    if (!trainingSnap.empty) {
      if (dryRun) {
        console.log(`  [DRY RUN] Would delete ${trainingSnap.docs.length} training docs for ${userId}`);
        totalDeleted += trainingSnap.docs.length;
      } else {
        const batch = db.batch();
        trainingSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        console.log(`  Deleted ${trainingSnap.docs.length} training docs for ${userId}`);
        totalDeleted += trainingSnap.docs.length;
      }
    }
  }

  console.log(`Total training data deleted: ${totalDeleted}`);
  return totalDeleted;
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');

  if (dryRun) {
    console.log('='.repeat(60));
    console.log('DRY RUN MODE - No data will be deleted');
    console.log('='.repeat(60));
  }

  console.log('Looking up team member user IDs...');
  const teamEmails = getTeamMemberEmails();
  const teamUserIds = await getUserIdsByEmails(teamEmails);

  if (teamUserIds.length === 0) {
    console.log('No team members found. Nothing to delete.');
    return;
  }

  console.log(`\nFound ${teamUserIds.length} team member(s) to clear data for.`);

  // Clear all user-specific data
  const results = {
    eventsCreated: await clearEventsCreatedBy(teamUserIds, dryRun),
    eventsAssigned: await clearEventsAssignedTo(teamUserIds, dryRun),
    orgComments: await clearOrgComments(teamUserIds, dryRun),
    postComments: await clearPostComments(teamUserIds, dryRun),
    channelMessages: await clearChannelMessages(teamUserIds, dryRun),
    trainingData: await clearTrainingProgress(teamUserIds, dryRun),
  };

  console.log('\n' + '='.repeat(60));
  console.log('SUMMARY');
  console.log('='.repeat(60));
  console.log(`Events created by team: ${results.eventsCreated}`);
  console.log(`Events assigned to team: ${results.eventsAssigned}`);
  console.log(`Org comments: ${results.orgComments}`);
  console.log(`Post comments: ${results.postComments}`);
  console.log(`Channel messages: ${results.channelMessages}`);
  console.log(`Training data: ${results.trainingData}`);
  console.log('='.repeat(60));

  const total = Object.values(results).reduce((a, b) => a + b, 0);
  if (dryRun) {
    console.log(`\nDRY RUN: Would have deleted ${total} documents total.`);
    console.log('Run without --dry-run to actually delete.');
  } else {
    console.log(`\nDeleted ${total} documents total.`);
  }

  console.log('\nNote: Inventory (organismRecords) is org-level and was not modified.');
  console.log('The pro@provenance.app admin user data was preserved.');
}

main().catch((error) => {
  console.error('ERROR:', error.message || error);
  process.exit(1);
});
