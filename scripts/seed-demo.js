#!/usr/bin/env node

/**
 * Community-tier demo seeder
 *
 * Seeds a single community demo org with sample users and coral inventory data.
 * Uses Node.js Firebase Admin SDK for seeding (no Dart dependency).
 *
 * Demo user: demo@example.com (password: demo123)
 *
 * Usage:
 *   # Standard community seeding (recommended for fresh setup)
 *   node scripts/seed-demo.js --reset
 *
 *   # Seed with explicit overrides
 *   node scripts/seed-demo.js --reset --user=demo@example.com --org=demo_org_community
 *
 * Optional flags:
 *   --name=ORG_NAME
 *   --domain=ORG_DOMAIN
 *   --seed=SEED (deterministic random seed)
 *   --seed-date=YYYY-MM-DD
 *   --reset (delete existing demo org/user data before seeding)
 *   --skip-inventory (do not run inventory seeding)
 *   --team-size=N (total demo users including admin; max 2 for community)
 */

require('dotenv').config();

// Safety check: prevent running against production projects.
// Demo seeding is destructive — only allow against emulators or demo-* project IDs.
function checkSafeEnvironment() {
  const isEmulator = !!(
    process.env.FIRESTORE_EMULATOR_HOST ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST
  );
  const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || '';
  const isDemoProject = projectId.startsWith('demo-');

  if (!isEmulator && !isDemoProject) {
    console.error('❌ SAFETY: seed-demo.js only runs against emulators or demo projects.');
    console.error('   Detected project:', projectId || '(unknown)');
    console.error('');
    console.error('   To run against emulator:');
    console.error('     FIRESTORE_EMULATOR_HOST=localhost:8080 \\');
    console.error('     FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \\');
    console.error('     node scripts/seed-demo.js');
    console.error('');
    console.error('   Or set FIREBASE_PROJECT_ID to a project starting with "demo-".');
    process.exit(1);
  }

  if (isEmulator) {
    console.log('✓ Running against emulator');
  } else {
    console.log(`✓ Running against demo project: ${projectId}`);
  }
}

checkSafeEnvironment();

const { admin, db } = require('./config-json');
const { spawnSync } = require('child_process');

// Known subcollections under organization documents
const ORG_SUBCOLLECTIONS = [
  'organismRecords',
  'groups',
  'genets',
  'comments',
  'channels',
  'chat_messages',
  'chat_rooms',
  'members',
  'snapshots',
  'notifications',
  'audit_logs',
];

// Known root-level collections that are org-scoped
const ORG_SCOPED_ROOT_COLLECTIONS = [
  'events',
  'sites',
  'snapshots',
  'brand_profiles',
  'public_genets',
];

const DEFAULT_DEMO_PASSWORD = 'demo123';

const COMMUNITY_CONFIG = {
  orgId: 'demo_org_community',
  orgName: 'SeaFoundry Demo Organization',
  primaryEmail: 'demo@example.com',
  teamSizeLimit: 2,
};

const args = process.argv.slice(2);

function argValue(prefix) {
  const match = args.find((arg) => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

function hasFlag(flag) {
  return args.includes(flag);
}

function normalizeSlug(input) {
  return (input || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-_ ]/g, '')
    .replace(/\s+/g, '-');
}

// Timeout wrapper for async operations
function withTimeout(promise, ms, label = 'Operation') {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms)
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Auth helpers
// ---------------------------------------------------------------------------

async function ensureAuthUser({ email, displayName, password }) {
  const normalizedEmail = (email || '').toLowerCase();
  try {
    const existing = await admin.auth().getUserByEmail(normalizedEmail);
    if (displayName && existing.displayName !== displayName) {
      await admin.auth().updateUser(existing.uid, { displayName });
    }
    return existing;
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  try {
    return await admin.auth().createUser({
      email: normalizedEmail,
      password: password || DEFAULT_DEMO_PASSWORD,
      displayName,
      emailVerified: true,
    });
  } catch (error) {
    if (error?.code === 'auth/email-already-exists') {
      return admin.auth().getUserByEmail(normalizedEmail);
    }
    throw error;
  }
}

// ---------------------------------------------------------------------------
// Firestore cleanup helpers
// ---------------------------------------------------------------------------

async function deleteByQuery(query, label) {
  let deletedCount = 0;
  const batchSize = 500;

  while (true) {
    const snapshot = await query.limit(batchSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deletedCount += snapshot.docs.length;

    if (snapshot.docs.length < batchSize) break;
  }

  if (deletedCount > 0) {
    console.log(`INFO: Deleted ${deletedCount} ${label}.`);
  }

  return deletedCount;
}

async function deleteSubcollection(docRef, subcollectionName) {
  const batchSize = 500;
  let deletedCount = 0;
  const collectionRef = docRef.collection(subcollectionName);

  while (true) {
    const snapshot = await withTimeout(
      collectionRef.limit(batchSize).get(),
      30000,
      `Fetching ${subcollectionName}`
    );
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await withTimeout(batch.commit(), 30000, `Deleting ${subcollectionName} batch`);
    deletedCount += snapshot.docs.length;

    if (snapshot.docs.length < batchSize) break;
  }

  return deletedCount;
}

async function deleteOrganizationChannels(orgId) {
  const orgRef = db.collection('organizations').doc(orgId);
  const channelsRef = orgRef.collection('channels');
  const channelsSnap = await channelsRef.get();
  let deletedCount = 0;

  for (const channelDoc of channelsSnap.docs) {
    const channelRef = channelDoc.ref;
    await deleteSubcollection(channelRef, 'messages');
    await deleteSubcollection(channelRef, 'members');
    await channelRef.delete();
    deletedCount += 1;
  }

  return deletedCount;
}

async function deleteOrgDocument(orgId) {
  const docRef = db.collection('organizations').doc(orgId);
  let deletedCount = 0;

  for (const subcollection of ORG_SUBCOLLECTIONS) {
    try {
      if (subcollection === 'channels') {
        const count = await deleteOrganizationChannels(orgId);
        if (count > 0) {
          console.log(`INFO: Deleted ${count} channel documents.`);
        }
        deletedCount += count;
        continue;
      }
      const count = await deleteSubcollection(docRef, subcollection);
      if (count > 0) {
        console.log(`INFO: Deleted ${count} ${subcollection} documents.`);
      }
      deletedCount += count;
    } catch (error) {
      console.warn(`WARN: Error deleting ${subcollection}: ${error.message}`);
    }
  }

  const docSnap = await docRef.get();
  if (docSnap.exists) {
    await docRef.delete();
    deletedCount += 1;
  }

  return deletedCount;
}

async function deleteOrgScopedRootCollections(orgId) {
  let deletedTotal = 0;

  for (const collectionName of ORG_SCOPED_ROOT_COLLECTIONS) {
    try {
      const count = await deleteByQuery(
        db.collection(collectionName).where('organizationId', '==', orgId),
        `${collectionName} documents`,
      );
      deletedTotal += count;
    } catch (error) {
      console.warn(`WARN: Error deleting ${collectionName}: ${error.message}`);
    }
  }

  return deletedTotal;
}

async function resetDemoData({ orgId, userId }) {
  console.log(`INFO: Resetting demo data for org ${orgId}...`);

  await deleteOrgScopedRootCollections(orgId);
  await deleteOrgDocument(orgId);

  // Delete public org document
  const publicDocRef = db.collection('public_orgs').doc(orgId);
  const publicDocSnap = await publicDocRef.get();
  if (publicDocSnap.exists) {
    await publicDocRef.delete();
  }

  // Delete community post comments (chunked for Firestore 500-op batch limit)
  const postPrefix = `demo_${orgId}_post_`;
  try {
    await deleteByQuery(
      db.collection('post_comments')
        .where('targetId', '>=', postPrefix)
        .where('targetId', '<', postPrefix + '\uf8ff'),
      'community post comments',
    );
  } catch (error) {
    console.warn(`WARN: Error deleting post_comments: ${error.message}`);
  }

  // Delete user documents belonging to this org
  await deleteByQuery(
    db.collection('users').where('organizationId', '==', orgId),
    'user documents',
  );

  if (userId) {
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    if (userSnap.exists) {
      await userRef.delete();
      console.log(`INFO: Deleted user ${userId}.`);
    }
  }

  console.log('INFO: Demo reset complete.');
}

// ---------------------------------------------------------------------------
// Org / User creation
// ---------------------------------------------------------------------------

async function upsertOrganization({ orgId, orgName, orgDomain, userId }) {
  const now = new Date().toISOString();
  const orgRef = db.collection('organizations').doc(orgId);
  const resolvedDomain = normalizeSlug(orgDomain || orgName || orgId);

  await orgRef.set({
    id: orgId,
    name: orgName,
    nameLowercase: orgName.toLowerCase(),
    domain: resolvedDomain,
    slug: resolvedDomain,
    urlPath: resolvedDomain,
    internalPath: orgId,
    organizationId: orgId,
    modelType: 'organization',
    createdAt: now,
    updatedAt: now,
    createdById: userId,
    updatedById: userId,
    activities: ['nes', 'nis', 'op'],
    speciesIds: [],
    supportedOrganismKinds: ['coral'],
    tier: 'community',
    metadata: {
      tier: 'community',
      plan: 'community',
      isDemo: true,
    },
  });
}

async function upsertUser(user, orgId, ownerId) {
  const now = new Date().toISOString();
  const ref = db.collection('users').doc(user.id);

  await ref.set({
    id: user.id,
    name: user.name,
    email: user.email.toLowerCase(),
    role: user.role,
    organizationId: orgId,
    tagline: user.title,
    modelType: 'user',
    createdAt: now,
    createdById: ownerId,
    updatedAt: now,
    updatedById: ownerId,
    onboardingCompletedAt: now,
    metadata: {
      isDemo: true,
      hasCompletedTour: true,
    },
  }, { merge: true });

  // Create membership document
  const membershipRef = db.collection('organizations').doc(orgId)
    .collection('members').doc(user.id);
  await membershipRef.set({
    uid: user.id,
    memberId: user.id,
    email: user.email.toLowerCase(),
    role: user.role,
    organizationId: orgId,
    createdById: user.id,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
  }, { merge: true });
}

// ---------------------------------------------------------------------------
// Community posts
// ---------------------------------------------------------------------------

function buildPostTemplates() {
  return [
    {
      title: 'Nursery maintenance update',
      description:
        'Completed weekly cleaning and frag checks across nursery structures. ' +
        'Survival rates remain strong after last week\'s outplant.',
    },
    {
      title: 'Monitoring highlights',
      description:
        'Ecological surveys show stable growth for ACER fragments at Zone A. ' +
        'Next survey window opens next week.',
    },
    {
      title: 'Community collaboration',
      description:
        'Sharing updated SOPs for microfragmentation and monitoring photo standards. ' +
        'Feedback welcome from partner teams.',
    },
  ];
}

async function seedCommunityPosts({ orgId, orgName, users }) {
  if (hasFlag('--skip-posts')) return [];
  const posts = buildPostTemplates();
  const postIds = [];

  for (let i = 0; i < posts.length; i++) {
    const post = posts[i];
    const author = users[i % users.length];
    const postId = `demo_${orgId}_post_${i + 1}`;
    const now = new Date().toISOString();
    await db.collection('events').doc(postId).set({
      id: postId,
      organizationId: orgId,
      eventTypeId: 'event_update',
      scope: 'community',
      recordId: orgId,
      recordModelType: 'organization',
      title: post.title,
      description: post.description,
      notes: post.description,
      createdAt: now,
      createdById: author.id,
      createdByName: author.name,
      updatedAt: now,
      updatedById: author.id,
      modelType: 'event',
      urlPath: `/${orgId}/events/${postId}`,
      internalPath: `organizations/${orgId}/events/${postId}`,
      slug: postId,
      metadata: {
        isCommunityPost: true,
        title: post.title,
        description: post.description,
        createdByName: author.name,
        createdByOrgName: orgName,
        createdByOrgId: orgId,
      },
    }, { merge: true });
    postIds.push(postId);
  }

  console.log(`INFO: Seeded ${postIds.length} community posts.`);
  return postIds;
}

// ---------------------------------------------------------------------------
// Brand profile
// ---------------------------------------------------------------------------

const BRAND_HERO_IMAGES = [
  'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=1200',
  'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=1200',
  'https://images.unsplash.com/photo-1546026423-cc4642628d2b?w=1200',
];

const BRAND_ACCENT_COLORS = ['#00AEEF', '#00BCD4', '#00897B'];

async function seedBrandProfile({ orgId, orgName, userId }) {
  const brandProfileId = `brand-${orgId}`;

  const existingRoot = await db.collection('brand_profiles')
    .where('organizationId', '==', orgId)
    .limit(1)
    .get();

  if (!existingRoot.empty) {
    console.log(`INFO: Brand profile already exists for ${orgId}; skipping.`);
    return;
  }

  const now = new Date().toISOString();
  const hash = Array.from(orgId).reduce((sum, ch) => sum + ch.charCodeAt(0), 0);
  const heroImageUrl = BRAND_HERO_IMAGES[hash % BRAND_HERO_IMAGES.length];
  const accentColor = BRAND_ACCENT_COLORS[hash % BRAND_ACCENT_COLORS.length];

  const brandProfile = {
    id: brandProfileId,
    organizationId: orgId,
    modelType: 'brandProfile',
    brandName: orgName,
    heroImageUrl,
    logoUrl: null,
    accentColor,
    published: true,
    kioskEnabled: false,
    createdAt: now,
    createdById: userId,
    updatedAt: now,
    updatedById: userId,
  };

  await db.collection('brand_profiles').doc(brandProfileId).set(brandProfile);
  await db.collection('public_orgs').doc(orgId)
    .collection('brand_profiles').doc(brandProfileId).set(brandProfile);

  console.log(`INFO: Created brand profile for ${orgName}.`);
}

// ---------------------------------------------------------------------------
// Organization channels
// ---------------------------------------------------------------------------

async function seedOrganizationChannels({ orgId, users, seed }) {
  if (!users || users.length === 0) return;

  const rng = createSeededRandom(seed ? `${seed}-channels` : 'channels');
  const orgRef = db.collection('organizations').doc(orgId);
  const siteSnapshot = await db.collection('sites')
    .where('organizationId', '==', orgId)
    .get();
  const sites = siteSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const adminUser = users[0];
  const memberIds = users.map((user) => user.id);
  const now = new Date();

  const channelSlug = (input) => {
    const raw = String(input || '');
    const slug = raw.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+/, '').replace(/-+$/, '');
    if (slug) return slug;
    const fallbackId = Array.from(raw).reduce((sum, ch) => sum + ch.charCodeAt(0), 0);
    return `site-${Math.abs(fallbackId) || 0}`;
  };

  const channelTemplates = [
    { name: 'general', description: 'General organization channel' },
    { name: 'operations', description: 'Operations updates and scheduling' },
  ];

  const messagesByChannel = {
    general: [
      'Good morning team, quick sync at 9am.',
      'Water quality checks completed for all nurseries.',
      'Weather looks clear for the outplanting window.',
      'Great job on yesterday\'s maintenance coverage.',
      'Let\'s capture photos during today\'s maintenance.',
    ],
    operations: [
      'Tank cleaning schedule updated for the week.',
      'Please log equipment maintenance by EOD.',
      'Supply inventory is low on epoxy and gloves.',
      'Crew rotation posted for the next field day.',
      'Reminder: pump inspection is due tomorrow.',
    ],
    site: [
      'Site check-in complete; conditions are stable.',
      'Noticed slight sediment buildup near rack 2.',
      'Photo series captured for growth comparison.',
      'Diver notes uploaded to the site record.',
    ],
  };

  const channelsToCreate = [
    ...channelTemplates.map((template) => ({
      name: template.name,
      description: template.description,
      siteId: null,
      isPublic: true,
      messagePool: messagesByChannel[template.name] || messagesByChannel.general,
    })),
    ...sites.map((site) => ({
      name: channelSlug(site.name),
      description: `Site channel for ${site.name}`,
      siteId: site.id,
      isPublic: true,
      messagePool: messagesByChannel.site,
    })),
  ];

  let totalMessages = 0;

  for (const channelData of channelsToCreate) {
    const channelId = orgRef.collection('channels').doc().id;
    const createdAt = now.toISOString();

    const channel = {
      id: channelId,
      name: channelData.name,
      channelType: 'organization',
      visibility: channelData.isPublic ? 'public' : 'invite_only',
      organizationId: orgId,
      description: channelData.description,
      siteId: channelData.siteId || null,
      memberIds,
      memberCount: memberIds.length,
      adminIds: adminUser ? [adminUser.id] : [],
      createdAt,
      createdById: adminUser?.id,
      lastMessageAt: createdAt,
      lastMessagePreview: '',
      lastMessageSenderId: adminUser?.id,
      isArchived: false,
    };

    await orgRef.collection('channels').doc(channelId).set(channel);

    for (const user of users) {
      await orgRef.collection('channels').doc(channelId).collection('members').doc(user.id).set({
        userId: user.id,
        channelId,
        role: user.id === adminUser?.id ? 'owner' : 'member',
        joinedAt: createdAt,
        displayName: user.name,
        notificationPreference: 'all',
        isMuted: false,
        isStarred: user.id === adminUser?.id,
      });
    }

    const messagePool = channelData.messagePool || messagesByChannel.general;
    const messageCount = 4 + Math.floor(rng() * 4);
    let lastMessage = null;
    let lastMessageTime = null;

    for (let i = 0; i < messageCount; i++) {
      const sender = pickRandom(users, rng) || adminUser;
      const content = pickRandom(messagePool, rng) || 'Quick update.';
      const messageDate = new Date(now);
      const hoursBack = (messageCount - i - 1) * (1 + Math.floor(rng() * 4));
      messageDate.setTime(messageDate.getTime() - hoursBack * 60 * 60 * 1000);

      const messageId = orgRef.collection('channels').doc(channelId).collection('messages').doc().id;
      const message = {
        id: messageId,
        channelId,
        senderId: sender.id,
        senderName: sender.name,
        content,
        createdAt: messageDate.toISOString(),
        mentions: [],
        attachments: [],
        reactions: {},
        readBy: [sender.id],
        isPinned: false,
        isEdited: false,
        isDeleted: false,
      };

      await orgRef.collection('channels').doc(channelId).collection('messages').doc(messageId).set(message);
      totalMessages += 1;

      if (!lastMessageTime || messageDate > lastMessageTime) {
        lastMessage = message;
        lastMessageTime = messageDate;
      }
    }

    if (lastMessage) {
      const preview = lastMessage.content.length > 100
        ? `${lastMessage.content.substring(0, 100)}...`
        : lastMessage.content;
      await orgRef.collection('channels').doc(channelId).update({
        lastMessageAt: lastMessage.createdAt,
        lastMessagePreview: preview,
        lastMessageSenderId: lastMessage.senderId,
      });
    }
  }

  console.log(`INFO: Created ${channelsToCreate.length} org channels and ${totalMessages} messages.`);
}

// ---------------------------------------------------------------------------
// User history events
// ---------------------------------------------------------------------------

function createSeededRandom(seedInput) {
  let state = 0;
  const seedString = seedInput != null ? String(seedInput) : '';
  for (let i = 0; i < seedString.length; i++) {
    state = (state * 31 + seedString.charCodeAt(i)) >>> 0;
  }
  if (state === 0) {
    state = Math.floor(Math.random() * 0xffffffff);
  }
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0x100000000;
  };
}

function pickRandom(list, rng) {
  if (!list.length) return null;
  return list[Math.floor(rng() * list.length)];
}

async function seedUserHistoryEvents({ orgId, users, seed }) {
  if (!users || users.length === 0) return;
  const rng = createSeededRandom(seed);
  const now = Date.now();
  const dayMs = 24 * 60 * 60 * 1000;
  const events = [];

  users.forEach((user, index) => {
    const baseDate = new Date(now - (index + 2) * dayMs);
    const eventId = db.collection('events').doc().id;
    const slug = `user-update-${eventId.slice(0, 6)}`;
    events.push({
      eventTypeId: 'event_update',
      updateType: 'profile_update',
      fieldUpdates: { tagline: user.title, role: user.role },
      notes: 'Seeded profile update for audit history.',
      id: eventId,
      modelType: 'event',
      organizationId: orgId,
      createdAt: baseDate.toISOString(),
      updatedAt: baseDate.toISOString(),
      createdById: user.id,
      updatedById: user.id,
      recordId: user.id,
      recordModelType: 'user',
      slug,
      urlPath: `users/${user.id}/events/${slug}`,
      internalPath: `organizations/${orgId}/events/${eventId}`,
      snapshotData: {
        id: user.id,
        modelType: 'user',
        name: user.name,
        email: user.email.toLowerCase(),
        role: user.role,
        tagline: user.title,
        organizationId: orgId,
        createdAt: baseDate.toISOString(),
        updatedAt: baseDate.toISOString(),
        createdById: user.id,
        updatedById: user.id,
        metadata: { isDemo: true },
      },
      metadata: { auditSource: 'seed' },
    });
  });

  if (events.length > 0) {
    const batch = db.batch();
    events.forEach((event) => {
      batch.set(db.collection('events').doc(event.id), event);
    });
    await batch.commit();
    console.log(`INFO: Seeded ${events.length} user history events.`);
  }
}

// ---------------------------------------------------------------------------
// Coral inventory seeding (delegates to seed-coral-inventory.js)
// ---------------------------------------------------------------------------

function seedInventory(orgId, userId) {
  if (hasFlag('--skip-inventory')) return;

  const seed = argValue('--seed');
  const seedDate = argValue('--seed-date') || argValue('--seed_date');
  const nodeArgs = [
    'scripts/seed-coral-inventory.js',
    `--org=${orgId}`,
    `--user=${userId}`,
  ];
  if (seed) nodeArgs.push(`--seed=${seed}`);
  if (seedDate) nodeArgs.push(`--seed-date=${seedDate}`);

  const result = spawnSync(process.execPath, nodeArgs, { stdio: 'inherit' });
  if (result.status !== 0) {
    throw new Error(`Coral inventory seeding failed with exit code ${result.status}`);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const userEmail = (argValue('--user') || COMMUNITY_CONFIG.primaryEmail).toLowerCase();
  const orgId = argValue('--org') || COMMUNITY_CONFIG.orgId;
  const orgName = argValue('--name') || COMMUNITY_CONFIG.orgName;
  const seed = argValue('--seed');
  const shouldReset = hasFlag('--reset');

  console.log('\n' + '='.repeat(60));
  console.log('Seeding COMMUNITY tier demo organization');
  console.log(`  Org ID: ${orgId}`);
  console.log(`  Primary user: ${userEmail}`);
  console.log(`  Team size limit: ${COMMUNITY_CONFIG.teamSizeLimit}`);
  console.log('='.repeat(60) + '\n');

  // Create primary auth user
  const authUser = await ensureAuthUser({
    email: userEmail,
    displayName: 'Demo Admin',
    password: DEFAULT_DEMO_PASSWORD,
  });
  const userId = authUser.uid;

  // Reset if requested
  if (shouldReset) {
    await resetDemoData({ orgId, userId });
  }

  // Create organization
  await upsertOrganization({
    orgId,
    orgName,
    orgDomain: orgName.toLowerCase().replace(/[^a-z0-9]/g, '-'),
    userId,
  });

  // Brand profile
  await seedBrandProfile({ orgId, orgName, userId });

  // Build users array (admin + 1 team member for community tier)
  const [local, domain] = userEmail.split('@');
  const emailPrefix = local.split('+')[0];

  const users = [
    {
      id: userId,
      email: userEmail,
      name: 'Demo Admin',
      role: 'admin',
      title: 'Program Lead',
    },
  ];

  // Add one team member (community tier allows 2 total)
  const teamMemberEmail = `${emailPrefix}1@${domain}`;
  const teamAuthRecord = await ensureAuthUser({
    email: teamMemberEmail,
    displayName: 'Sarah Chen',
    password: DEFAULT_DEMO_PASSWORD,
  });
  users.push({
    id: teamAuthRecord.uid,
    email: teamMemberEmail,
    name: 'Sarah Chen',
    role: 'practitioner_plus',
    title: 'Nursery Manager',
  });

  // Upsert all users
  for (const user of users) {
    await upsertUser(user, orgId, userId);
  }

  // Seed data
  await seedUserHistoryEvents({ orgId, users, seed });
  seedInventory(orgId, userId);

  console.log('\n' + '='.repeat(60));
  console.log('COMMUNITY DEMO SEEDING COMPLETE');
  console.log('='.repeat(60));
  console.log(`\nDemo account: ${userEmail} (password: ${DEFAULT_DEMO_PASSWORD})`);
  console.log(`Team member: ${teamMemberEmail} (password: ${DEFAULT_DEMO_PASSWORD})\n`);
}

main().catch((error) => {
  console.error('ERROR: Demo seeding failed:', error.message || error);
  process.exit(1);
});
