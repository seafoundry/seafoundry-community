#!/usr/bin/env node
/**
 * Seed first Sebastian post for all community channels.
 *
 * Usage:
 *   node scripts/seed-community-channel-intros.js
 *   node scripts/seed-community-channel-intros.js --dry-run
 */

require('dotenv').config();
const { db } = require('./config-json');

const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');

const SEBASTIAN_USER_ID = process.env.SEB_CHANNEL_SENDER_ID || 'sebastian';
const SEBASTIAN_NAME = process.env.SEB_CHANNEL_SENDER_NAME || 'Sebastian';

function buildIntroMessage(channel) {
  const name = channel.name || 'this channel';
  const visibility = channel.visibility === 'public' ? 'public' : 'private';
  return [
    `Hi everyone! I'm ${SEBASTIAN_NAME}, your SeaFoundry assistant.`,
    `Welcome to #${name}. This is a ${visibility} community channel.`,
    'Ask me anything about inventory, husbandry, monitoring, or restoration workflows.',
  ].join(' ');
}

function previewText(content) {
  const trimmed = content.trim().replace(/\s+/g, ' ');
  return trimmed.length > 140 ? `${trimmed.slice(0, 137)}...` : trimmed;
}

async function seedChannel(channelDoc) {
  const channelData = channelDoc.data();
  if (channelData?.isArchived) {
    return { channelId: channelDoc.id, skipped: 'archived' };
  }

  const messagesRef = channelDoc.ref.collection('messages');
  const existingMessages = await messagesRef.limit(1).get();
  if (!existingMessages.empty) {
    return { channelId: channelDoc.id, skipped: 'already has messages' };
  }

  const now = new Date().toISOString();
  const content = buildIntroMessage(channelData);
  const messageId = messagesRef.doc().id;

  const message = {
    id: messageId,
    channelId: channelDoc.id,
    senderId: SEBASTIAN_USER_ID,
    senderName: SEBASTIAN_NAME,
    content,
    createdAt: now,
    mentions: [],
    attachments: [],
    reactions: {},
    readBy: [],
    isPinned: false,
    isEdited: false,
    isDeleted: false,
    metadata: {
      source: 'sebastian',
      type: 'intro',
    },
  };

  if (isDryRun) {
    return { channelId: channelDoc.id, created: false, preview: previewText(content) };
  }

  const batch = db.batch();
  batch.set(messagesRef.doc(messageId), message);
  batch.update(channelDoc.ref, {
    lastMessageAt: now,
    lastMessagePreview: previewText(content),
    lastMessageSenderId: SEBASTIAN_USER_ID,
  });
  await batch.commit();

  return { channelId: channelDoc.id, created: true };
}

async function run() {
  const snapshot = await db.collection('community_channels').get();
  if (snapshot.empty) {
    console.log('No community channels found.');
    return;
  }

  const results = [];
  for (const doc of snapshot.docs) {
    results.push(await seedChannel(doc));
  }

  const created = results.filter((r) => r.created).length;
  const skipped = results.filter((r) => r.skipped).length;
  console.log(
    `${isDryRun ? '[DRY RUN] ' : ''}Processed ${results.length} channels: ` +
      `${created} created, ${skipped} skipped.`,
  );
  if (isDryRun) {
    console.table(results);
  }
}

run().catch((error) => {
  console.error('Failed to seed community channel intros:', error);
  process.exit(1);
});
