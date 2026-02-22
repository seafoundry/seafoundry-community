#!/usr/bin/env node

/**
 * Lightweight demo seeder (post-PR357)
 *
 * IMPORTANT: After the Data Field Unification (SOT) work, the production
 * database must be wiped/reset for all users so new data is consistent
 * with the canonical field structure (genetId at top level,
 * foreignKeys.genetId synced, physicalFormId instead of morphologyId,
 * SizeSpec format instead of sizeClass, no metadata.genetId or
 * metadata.provenanceId).
 *
 * Seeds demo orgs, demo users, and sample data with tier-appropriate gating.
 * Supports three tiers with distinct feature sets:
 *   - Community: Basic inventory only (2 user limit)
 *   - Pro: Husbandry, observations, comments (no tasks)
 *   - Scale: All features including tasks
 *
 * Demo users:
 *   - Community: community@provenance.app, community1@provenance.app
 *   - Pro: pro@provenance.app, pro1@provenance.app through pro9@provenance.app
 *   - Scale: scale@provenance.app, scale1@provenance.app through scale9@provenance.app
 *
 * All demo users share password: demo123
 *
 * Usage:
 *   # Seed all three demo orgs at once (recommended for fresh setup)
 *   node scripts/seed-demo.js --seed-all-tiers --reset
 *
 *   # Seed a single tier
 *   node scripts/seed-demo.js --reset --user=scale@provenance.app --tier=scale
 *   node scripts/seed-demo.js --reset --user=pro@provenance.app --tier=pro
 *   node scripts/seed-demo.js --reset --user=community@provenance.app --tier=community
 *
 *   # Legacy: Seed with explicit org ID
 *   node scripts/seed-demo.js --reset --org=ORG_ID --user=scale@provenance.app --tier=scale
 *
 * Optional flags:
 *   --name=ORG_NAME
 *   --domain=ORG_DOMAIN
 *   --tier=community|pro|scale (default: scale)
 *   --seed=SEED (deterministic random seed)
 *   --seed-date=YYYY-MM-DD
 *   --reset (delete existing demo org/user data before seeding)
 *   --skip-inventory (do not run inventory seeding)
 *   --seed-inventory (legacy flag; inventory seeding runs by default)
 *   --seed-holdings (seed non-coral holdings for the demo org)
 *   --with-team (seed additional demo users, including auth accounts)
 *   --team-size=N (total demo users including admin; capped by tier limit)
 *   --skip-posts (do not seed community posts)
 *   --seed-all-tiers (seed all three demo orgs: community, pro, scale)
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { admin, db } = require('./config-json');
const { spawn, spawnSync } = require('child_process');
const TrainingSeeder = require('./seeders/training-seeder');

// Guard: training content is global (template), only seed once even with --seed-all-tiers
let trainingContentSeeded = false;

// Known subcollections under organization documents
// Using explicit list instead of listCollections() which hangs on production Firestore
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

// Timeout wrapper for async operations
function withTimeout(promise, ms, label = 'Operation') {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms)
    ),
  ]);
}

const args = process.argv.slice(2);
const DEFAULT_DEMO_PASSWORD = 'demo123';
const DEFAULT_TEAM_SIZE = 10;

// Demo organization configurations for each tier
// Each tier has its own org, primary user, and data constraints
const DEMO_TIER_CONFIG = {
  community: {
    orgId: 'demo_org_community',
    orgName: 'DEMO-COMMUNITY',
    primaryEmail: 'community@provenance.app',
    teamSizeLimit: 2, // Community orgs limited to 2 users
    // Community: No gated activities (Firestore rules require Pro+ for comments)
    allowedActivities: [],
    // Community has limited site types (no full monitoring workspace)
    siteRestrictions: true,
  },
  pro: {
    orgId: 'demo_org_pro',
    orgName: 'DEMO-PRO',
    primaryEmail: 'pro@provenance.app',
    teamSizeLimit: DEFAULT_TEAM_SIZE,
    // Pro: Husbandry, observations, comments - NO tasks
    allowedActivities: ['husbandry', 'observation', 'comment'],
    siteRestrictions: false,
  },
  scale: {
    orgId: 'demo_org_scale',
    orgName: 'DEMO-SCALE',
    primaryEmail: 'scale@provenance.app',
    teamSizeLimit: DEFAULT_TEAM_SIZE,
    // Scale: All features including tasks
    allowedActivities: ['task', 'husbandry', 'observation', 'comment'],
    siteRestrictions: false,
  },
};

// Legacy compatibility
const DEFAULT_DEMO_EMAIL = 'scale@provenance.app';

function argValue(prefix) {
  const match = args.find((arg) => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

function hasFlag(flag) {
  return args.includes(flag);
}

function normalizeTier(raw) {
  const normalized = (raw || '').trim().toLowerCase();
  if (['community', 'pro', 'scale'].includes(normalized)) return normalized;
  return 'scale';
}

function normalizeSlug(input) {
  return (input || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-_ ]/g, '')
    .replace(/\s+/g, '-');
}

function resolveTierEnv(key, fallback) {
  return process.env[key] && process.env[key].trim().length > 0
    ? process.env[key].trim()
    : fallback;
}

function resolveUserEmail(tier, override) {
  if (override) return override;
  const tierConfig = DEMO_TIER_CONFIG[tier];
  if (tierConfig) {
    return tierConfig.primaryEmail;
  }
  // Fallback to env vars for legacy compatibility
  const envKey = `DEMO_${tier.toUpperCase()}_USER_EMAIL`;
  return resolveTierEnv(envKey, resolveTierEnv('DEMO_USER_EMAIL', DEFAULT_DEMO_EMAIL));
}

function resolveOrgId(tier, override) {
  if (override) return override;
  const tierConfig = DEMO_TIER_CONFIG[tier];
  if (tierConfig) {
    return tierConfig.orgId;
  }
  // Fallback to env vars for legacy compatibility
  const envKey = `DEMO_${tier.toUpperCase()}_ORG_ID`;
  return resolveTierEnv(envKey, resolveTierEnv('DEMO_ORG_ID', null));
}

function resolveTeamSizeLimit(tier) {
  const tierConfig = DEMO_TIER_CONFIG[tier];
  return tierConfig?.teamSizeLimit ?? DEFAULT_TEAM_SIZE;
}

function getAllowedActivities(tier) {
  const tierConfig = DEMO_TIER_CONFIG[tier];
  return tierConfig?.allowedActivities ?? ['task', 'husbandry', 'observation', 'comment'];
}

function resolveUserPassword(tier) {
  // Always use demo123 for all demo users regardless of tier
  return resolveTierEnv('DEMO_USER_PASSWORD', DEFAULT_DEMO_PASSWORD);
}

function clampTeamSize(value) {
  if (!Number.isFinite(value)) return 1;
  return Math.max(1, Math.min(DEFAULT_TEAM_SIZE, value));
}

async function resolveAuthUser(email) {
  try {
    return await admin.auth().getUserByEmail(email);
  } catch (error) {
    const message = error?.message || error;
    throw new Error(`Auth user not found for ${email}: ${message}`);
  }
}

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
      password: password || 'demo123',
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

async function resolveOrganization(identifier) {
  if (!identifier) return { id: null, doc: null };
  const byId = await db.collection('organizations').doc(identifier).get();
  if (byId.exists) return { id: identifier, doc: byId };

  const normalized = identifier.toLowerCase();
  const byDomain = await db.collection('organizations')
    .where('domain', '==', normalized)
    .limit(1)
    .get();
  if (!byDomain.empty) {
    return { id: byDomain.docs[0].id, doc: byDomain.docs[0] };
  }

  const bySlug = await db.collection('organizations')
    .where('slug', '==', normalized)
    .limit(1)
    .get();
  if (!bySlug.empty) {
    return { id: bySlug.docs[0].id, doc: bySlug.docs[0] };
  }

  return { id: identifier, doc: null };
}

async function findUserDocByEmail(email) {
  if (!email) return null;
  const normalized = email.toLowerCase();
  const byEmail = await db.collection('users')
    .where('email', '==', email)
    .limit(1)
    .get();
  if (!byEmail.empty) {
    return { id: byEmail.docs[0].id, doc: byEmail.docs[0] };
  }

  if (email !== normalized) {
    const byLowerEmail = await db.collection('users')
      .where('email', '==', normalized)
      .limit(1)
      .get();
    if (!byLowerEmail.empty) {
      return { id: byLowerEmail.docs[0].id, doc: byLowerEmail.docs[0] };
    }
  }

  return null;
}

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

async function deleteOrgDocument(orgId) {
  const docRef = db.collection('organizations').doc(orgId);
  let deletedCount = 0;

  // Delete known subcollections explicitly (avoids slow listCollections())
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

  // Delete the org document itself
  const docSnap = await docRef.get();
  if (docSnap.exists) {
    await docRef.delete();
    deletedCount += 1;
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

async function deletePublicOrgDocument(orgId) {
  const docRef = db.collection('public_orgs').doc(orgId);
  const docSnap = await docRef.get();
  if (docSnap.exists) {
    await docRef.delete();
    return 1;
  }
  return 0;
}

// Known root-level collections that are org-scoped
// Using explicit list instead of listCollections() which hangs on production Firestore
const ORG_SCOPED_ROOT_COLLECTIONS = [
  'events',
  'sites',
  'snapshots',
  'brand_profiles',
  'public_genets',
  'missions',
  'vessels',
  // NOTE: 'sops' and 'training_media' are global template content, NOT org-scoped.
  // They are seeded once via TrainingSeeder and should not be deleted on org reset.
  'training_completions',
  'training_progress',
  'sop_completions',
];

const TRAINING_GATES_PATH = path.join(
  __dirname,
  '../config/training_gates.defaults.yaml',
);

const TRAINING_DATA_PATH = path.join(
  __dirname,
  '../config/seed_data/training',
);

function loadTrainingGateModuleIds() {
  if (!fs.existsSync(TRAINING_GATES_PATH)) {
    console.warn('WARN: training gate defaults missing; skipping completions.');
    return [];
  }
  const raw = fs.readFileSync(TRAINING_GATES_PATH, 'utf8');
  const modules = new Set();
  raw.split('\n').forEach((line) => {
    const match = line.match(/^\s*-\s+([^\s#]+)/);
    if (match) {
      modules.add(match[1]);
    }
  });
  return Array.from(modules);
}

function loadTrainingSops() {
  if (!fs.existsSync(TRAINING_DATA_PATH)) {
    return [];
  }
  const sopFiles = fs.readdirSync(TRAINING_DATA_PATH)
    .filter((f) => f.startsWith('sop_') && f.endsWith('.json'));
  const sops = [];
  for (const file of sopFiles) {
    try {
      const content = fs.readFileSync(path.join(TRAINING_DATA_PATH, file), 'utf8');
      const sop = JSON.parse(content);
      if (sop && sop.id) {
        sops.push({
          id: sop.id,
          version: sop.version || '1.0',
          steps: Array.isArray(sop.steps) ? sop.steps : [],
        });
      }
    } catch (e) {
      // Skip invalid files
    }
  }
  return sops;
}

function loadTrainingMediaIds() {
  if (!fs.existsSync(TRAINING_DATA_PATH)) {
    return [];
  }
  const mediaFiles = fs.readdirSync(TRAINING_DATA_PATH)
    .filter((f) => f.startsWith('media_') && f.endsWith('.json'));
  const mediaIds = [];
  for (const file of mediaFiles) {
    try {
      const content = fs.readFileSync(path.join(TRAINING_DATA_PATH, file), 'utf8');
      const mediaLibrary = JSON.parse(content);
      const mediaArrays = [
        mediaLibrary.media,
        mediaLibrary.mediaReferences,
        mediaLibrary.workflowDiagrams,
        mediaLibrary.exampleReports,
      ].filter(Boolean);
      for (const mediaArray of mediaArrays) {
        for (const item of mediaArray) {
          if (item && item.id) {
            mediaIds.push(item.id);
          }
        }
      }
    } catch (e) {
      // Skip invalid files
    }
  }
  return mediaIds;
}

async function seedTrainingCompletions({ userId, orgId }) {
  const moduleIds = loadTrainingGateModuleIds();
  const sops = loadTrainingSops();
  const sopIds = sops.map((sop) => sop.id);
  const mediaIds = loadTrainingMediaIds();

  const now = new Date().toISOString();
  const userRef = db.collection('users').doc(userId);
  let batch = db.batch();
  let count = 0;

  // Seed legacy training completions (users/{userId}/training subcollection)
  if (moduleIds.length > 0) {
    for (const moduleId of moduleIds) {
      const docRef = userRef.collection('training').doc(moduleId);
      batch.set(docRef, {
        id: moduleId,
        moduleId,
        userId,
        organizationId: orgId,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      }, { merge: true });
      count += 1;
      if (count % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    await batch.commit();
    console.log(`INFO: Marked ${moduleIds.length} training gate modules complete (legacy).`);
  }

  // Seed SOP completions (sop_completions collection)
  if (sops.length > 0) {
    batch = db.batch();
    count = 0;
    for (const sop of sops) {
      const completionId = `${orgId}_${userId}_${sop.id}`;
      const completionRef = db.collection('sop_completions').doc(completionId);
      const stepCompletions = (sop.steps || [])
        .map((step) => {
          if (!step || !step.id) return null;
          const checklistItems = Array.isArray(step.checklistItems)
            ? step.checklistItems.map(() => true)
            : null;
          return {
            stepId: step.id,
            isCompleted: true,
            completedAt: now,
            ...(checklistItems ? { checklistItemsCompleted: checklistItems } : {}),
          };
        })
        .filter(Boolean);

      batch.set(completionRef, {
        id: completionId,
        sopId: sop.id,
        sopVersion: sop.version || '1.0',
        userId,
        organizationId: orgId,
        startedAt: now,
        completedAt: now,
        status: 'completed',
        stepCompletions,
      }, { merge: true });
      count += 1;
      if (count % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    await batch.commit();
    console.log(`INFO: Marked ${sops.length} SOPs complete (sop_completions).`);
  }

  // Build TrainingProgress document for training_progress collection
  const sopProgress = {};
  for (const sopId of sopIds) {
    sopProgress[sopId] = {
      sopId,
      completionCount: 1,
      lastCompletedAt: now,
      averageCompletionTime: 300, // 5 minutes average
    };
  }

  const mediaProgress = {};
  for (const mediaId of mediaIds) {
    mediaProgress[mediaId] = {
      mediaId,
      watchedPercentage: 100.0,
      completedAt: now,
      lastViewedAt: now,
    };
  }

  // Create or update TrainingProgress document
  const progressId = `${orgId}_${userId}`;
  const progressRef = db.collection('training_progress').doc(progressId);
  await progressRef.set({
    id: progressId,
    userId,
    organizationId: orgId,
    sopProgress,
    mediaProgress,
    lastActivityAt: now,
    totalSOPsCompleted: sopIds.length,
    totalMediaCompleted: mediaIds.length,
  }, { merge: true });

  console.log(`INFO: Created TrainingProgress with ${sopIds.length} SOPs and ${mediaIds.length} media items completed.`);
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

  // Delete org-scoped root collections (events, sites, etc.)
  await deleteOrgScopedRootCollections(orgId);

  // Delete organization document and its subcollections (uses explicit list, not listCollections)
  await deleteOrgDocument(orgId);

  // Delete public org document
  await deletePublicOrgDocument(orgId);

  // Delete community post comments (post_comments collection)
  // These are not org-scoped but the targetId contains the orgId
  const postPrefix = `demo_${orgId}_post_`;
  try {
    const postCommentsSnap = await db.collection('post_comments')
      .where('targetId', '>=', postPrefix)
      .where('targetId', '<', postPrefix + '\uf8ff')
      .get();
    if (!postCommentsSnap.empty) {
      const batch = db.batch();
      postCommentsSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`INFO: Deleted ${postCommentsSnap.docs.length} community post comments.`);
    }
  } catch (error) {
    console.warn(`WARN: Error deleting post_comments: ${error.message}`);
  }

  // Delete users belonging to this org
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

/**
 * Build team templates with activities filtered by tier.
 * @param {string} tier - 'community', 'pro', or 'scale'
 * @returns {Array} Team member templates with tier-appropriate activities
 */
function buildTeamTemplates(tier = 'scale') {
  const allowedActivities = getAllowedActivities(tier);
  
  // Base team templates with full activity sets
  const baseTemplates = [
    {
      name: 'Sarah Chen',
      role: 'practitioner_plus',
      title: 'Nursery Manager',
      activity: ['task', 'husbandry', 'comment', 'observation'],
    },
    {
      name: 'James Wilson',
      role: 'practitioner_plus',
      title: 'Field Technician',
      activity: ['task', 'husbandry', 'observation'],
    },
    {
      name: 'Emily Santos',
      role: 'practitioner',
      title: 'Research Assistant',
      activity: ['task', 'comment', 'observation'],
    },
    {
      name: 'Lisa Thompson',
      role: 'practitioner',
      title: 'Data Analyst',
      activity: ['task'],
    },
    {
      name: 'Carlos Martinez',
      role: 'view_only',
      title: 'Outplanting Lead',
      activity: ['comment'],
    },
    {
      name: 'Priya Nair',
      role: 'practitioner_plus',
      title: 'Operations Specialist',
      activity: ['husbandry', 'comment', 'observation'],
    },
    {
      name: 'Miguel Alvarez',
      role: 'practitioner',
      title: 'Nursery Technician',
      activity: ['task', 'husbandry', 'observation'],
    },
    {
      name: 'Hannah Brooks',
      role: 'view_only',
      title: 'Program Coordinator',
      activity: ['comment'],
    },
    {
      name: 'Aiden Park',
      role: 'practitioner_plus',
      title: 'Genetics Specialist',
      activity: ['task', 'comment', 'observation'],
    },
  ];
  
  // Filter activities based on tier and remove users with no remaining activities
  return baseTemplates
    .map((template) => ({
      ...template,
      activity: template.activity.filter((act) => allowedActivities.includes(act)),
    }))
    .filter((template) => template.activity.length > 0);
}

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

function createSeededRandom(seedInput) {
  let state = 0;
  const seedString = seedInput != null ? String(seedInput) : '';
  for (let i = 0; i < seedString.length; i += 1) {
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
  const idx = Math.floor(rng() * list.length);
  return list[idx];
}

function stripTrailingSegment(path) {
  if (!path || typeof path !== 'string') return null;
  const index = path.lastIndexOf('/');
  if (index <= 0) return null;
  return path.substring(0, index);
}

function defaultOrgName(tier) {
  switch (tier) {
    case 'community':
      return 'SeaFoundry Demo Organization';
    case 'scale':
      return 'SeaFoundry Scale Demo';
    case 'pro':
    default:
      return 'SeaFoundry Pro Demo';
  }
}

async function upsertOrganization({
  orgId,
  orgName,
  orgDomain,
  tier,
  userId,
  existingDoc,
}) {
  const now = new Date().toISOString();
  const orgRef = db.collection('organizations').doc(orgId);
  const existingData = existingDoc ? existingDoc.data() : null;
  const baseMetadata = existingData && existingData.metadata ? existingData.metadata : {};
  const metadata = {
    ...baseMetadata,
    tier,
    plan: tier,
    isDemo: true,
  };
  const resolvedDomain = normalizeSlug(
    orgDomain ||
      existingData?.domain ||
      existingData?.slug ||
      orgName ||
      orgId,
  );

  if (existingDoc) {
    const updates = {
      tier,
      metadata,
      updatedAt: now,
      updatedById: userId,
      // Preserve existing createdById/createdAt or set if missing
      createdById: existingData?.createdById || userId,
      createdAt: existingData?.createdAt || now,
    };
    if (orgName) {
      updates.name = orgName;
      updates.nameLowercase = orgName.toLowerCase();
    }
    const missingDomain = !existingData?.domain || existingData.domain.trim().length === 0;
    const missingSlug = !existingData?.slug || existingData.slug.trim().length === 0;
    const missingUrlPath = !existingData?.urlPath || existingData.urlPath.trim().length === 0;
    if (orgDomain || missingDomain || missingSlug || missingUrlPath) {
      updates.domain = resolvedDomain;
      updates.slug = resolvedDomain;
      updates.urlPath = resolvedDomain;
    }
    await orgRef.set(updates, { merge: true });
    return;
  }

  const normalizedDomain = resolvedDomain;
  // Pro and Scale tiers support multiple organism kinds
  const supportedOrganismKinds = tier === 'community'
    ? ['coral']
    : ['coral', 'oyster', 'kelp', 'seagrass'];

  await orgRef.set({
    id: orgId,
    name: orgName || defaultOrgName(tier),
    nameLowercase: (orgName || defaultOrgName(tier)).toLowerCase(),
    domain: normalizedDomain,
    slug: normalizedDomain,
    urlPath: normalizedDomain,
    internalPath: orgId,
    organizationId: orgId,
    modelType: 'organization',
    createdAt: now,
    updatedAt: now,
    createdById: userId,
    updatedById: userId,
    activities: ['nes', 'nis', 'op', 'gb', 'bl', 'ref'],
    speciesIds: [],
    supportedOrganismKinds,
    tier,
    metadata,
  });
}

async function upsertUser(user, orgId, ownerId) {
  const now = new Date().toISOString();
  const ref = db.collection('users').doc(user.id);
  const existing = await ref.get();
  const existingOrg = existing.exists ? existing.data().organizationId : null;
  if (existingOrg && existingOrg !== orgId) {
    console.warn(
      `WARN: User ${user.email} belongs to ${existingOrg}; updating to ${orgId}`,
    );
  }

  await ref.set({
    id: user.id,
    name: user.name,
    email: user.email.toLowerCase(),
    role: user.role,
    organizationId: orgId,
    tagline: user.title,
    modelType: 'user',
    createdAt: existing.exists && existing.data().createdAt
      ? existing.data().createdAt
      : now,
    createdById: existing.exists && existing.data().createdById
      ? existing.data().createdById
      : ownerId,
    updatedAt: now,
    updatedById: ownerId,
    // Set onboardingCompletedAt so demo users skip the onboarding flow
    onboardingCompletedAt: now,
    metadata: {
      ...(existing.exists ? (existing.data().metadata || {}) : {}),
      isDemo: true,
      hasCompletedTour: true,
    },
  }, { merge: true });

  // Create membership document for the user in the organization
  // Path: /organizations/{orgId}/members/{uid}
  // IMPORTANT: The document ID must be the Firebase Auth UID for isMemberByUid() to work
  // Include both 'uid' and 'memberId' for compatibility with different app code paths
  const membershipRef = db.collection('organizations').doc(orgId)
    .collection('members').doc(user.id);
  await membershipRef.set({
    uid: user.id,               // Firebase Auth UID - required for membership lookups
    memberId: user.id,          // Legacy field for backward compatibility
    email: user.email.toLowerCase(),
    role: user.role,
    organizationId: orgId,      // Organization ID for reference
    createdById: user.id,       // Required by some Firebase rules for audit trail
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
  }, { merge: true });
}

async function seedCommunityPosts({
  orgId,
  orgName,
  users,
  skipPosts,
}) {
  if (skipPosts) return;
  const posts = buildPostTemplates();
  const postIds = [];
  for (let i = 0; i < posts.length; i += 1) {
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
  return postIds;
}

/**
 * Seed comments on community posts.
 *
 * Creates comments with replies in the post_comments collection.
 * Only seeds for Pro and Scale tiers (community tier doesn't have comment feature).
 */
async function seedCommunityPostComments({
  orgId,
  postIds,
  users,
  tier,
  seed,
}) {
  // Community tier doesn't have comment feature
  if (tier === 'community') return;
  if (!postIds || postIds.length === 0) return;
  if (!users || users.length < 2) return;

  const rng = createSeededRandom(seed ? `${seed}-post-comments` : 'post-comments');
  const now = Date.now();
  const dayMs = 24 * 60 * 60 * 1000;
  const hourMs = 60 * 60 * 1000;

  const commentTemplates = [
    'Great update! Looking forward to seeing more progress.',
    'Thanks for sharing this with the community.',
    'This is really helpful information.',
    'Excellent work on this project!',
    'How can we help with the next steps?',
    'Really appreciate the transparency here.',
    'This aligns well with our conservation goals.',
    'Would love to learn more about the methods used.',
  ];

  const replyTemplates = [
    'Agreed! This is exciting progress.',
    'Thanks for the additional context.',
    'Happy to help with this initiative.',
    'Great point!',
    "We're seeing similar results at our site.",
    'Looking forward to collaborating on this.',
  ];

  const isScaleTier = tier === 'scale';
  const commentsPerPost = isScaleTier ? 4 : 2;
  const repliesPerComment = isScaleTier ? 2 : 1;

  let totalComments = 0;
  let totalReplies = 0;

  for (const postId of postIds) {
    const commentCount = Math.min(commentsPerPost, users.length);

    for (let i = 0; i < commentCount; i += 1) {
      const author = users[(i + 1) % users.length]; // Skip first user (admin)
      const commentId = db.collection('post_comments').doc().id;
      const createdAt = new Date(now - Math.floor(rng() * 7) * dayMs - Math.floor(rng() * 12) * hourMs);
      const content = pickRandom(commentTemplates, rng) || 'Great update!';

      await db.collection('post_comments').doc(commentId).set({
        id: commentId,
        organizationId: '', // No org scoping for community comments
        targetType: 'post',
        targetId: postId,
        authorUid: author.id,
        authorName: author.name,
        content,
        createdAt: createdAt.toISOString(),
        parentCommentId: null,
        mentions: [],
        reactions: {},
        isEdited: false,
        isDeleted: false,
      });
      totalComments += 1;

      // Add replies to this comment
      const replyCount = Math.min(repliesPerComment, users.length - 1);
      for (let j = 0; j < replyCount; j += 1) {
        const replyAuthor = users[(i + j + 2) % users.length];
        const replyId = db.collection('post_comments').doc().id;
        const replyCreatedAt = new Date(createdAt.getTime() + (j + 1) * hourMs * (1 + Math.floor(rng() * 3)));
        const replyContent = pickRandom(replyTemplates, rng) || 'Great point!';

        await db.collection('post_comments').doc(replyId).set({
          id: replyId,
          organizationId: '',
          targetType: 'post',
          targetId: postId,
          authorUid: replyAuthor.id,
          authorName: replyAuthor.name,
          content: replyContent,
          createdAt: replyCreatedAt.toISOString(),
          parentCommentId: commentId,
          mentions: [],
          reactions: {},
          isEdited: false,
          isDeleted: false,
        });
        totalReplies += 1;
      }
    }
  }

  console.log(`INFO: Seeded ${totalComments} community post comments with ${totalReplies} replies.`);
}

// Ocean/coral themed hero images from Unsplash
const BRAND_HERO_IMAGES = [
  'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=1200', // Coral reef
  'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=1200', // Ocean waves
  'https://images.unsplash.com/photo-1546026423-cc4642628d2b?w=1200', // Underwater coral
];

// Aqua/teal accent colors
const BRAND_ACCENT_COLORS = [
  '#00AEEF', // Aqua blue
  '#00BCD4', // Cyan
  '#00897B', // Teal
];

async function seedBrandProfile({ orgId, orgName, userId }) {
  const brandProfileId = `brand-${orgId}`;

  // Check if brand profile already exists in root collection
  const existingRoot = await db.collection('brand_profiles')
    .where('organizationId', '==', orgId)
    .limit(1)
    .get();

  if (!existingRoot.empty) {
    console.log(`INFO: Brand profile already exists for ${orgId}; skipping.`);
    return;
  }

  const now = new Date().toISOString();
  // Deterministic selection based on orgId hash
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

  // Write to root collection (primary - read by BrandProfileRepository)
  await db.collection('brand_profiles').doc(brandProfileId).set(brandProfile);
  // Write to public_orgs mirror (for public access)
  await db.collection('public_orgs').doc(orgId)
    .collection('brand_profiles').doc(brandProfileId).set(brandProfile);

  console.log(`INFO: Created brand profile for ${orgName} (${orgId}).`);
}

function seedInventory(orgId, userId, authToken, tier = 'scale') {
  if (hasFlag('--skip-inventory')) return;

  // Use Node.js-based seeder by default (faster and more reliable)
  // Set USE_DART_SEEDER=1 to use the original Dart/Flutter seeder
  if (!process.env.USE_DART_SEEDER) {
    const seed = argValue('--seed');
    const seedDate = argValue('--seed-date') || argValue('--seed_date');
    const nodeArgs = [
      'scripts/seed-coral-inventory.js',
      `--org=${orgId}`,
      `--user=${userId}`,
      `--tier=${tier}`,
    ];
    if (seed) nodeArgs.push(`--seed=${seed}`);
    if (seedDate) nodeArgs.push(`--seed-date=${seedDate}`);

    const result = spawnSync(process.execPath, nodeArgs, { stdio: 'inherit' });
    if (result.status !== 0) {
      throw new Error(`Coral inventory seeding failed with exit code ${result.status}`);
    }
    return;
  }

  // Legacy Dart/Flutter seeder (kept for compatibility)
  const flutter = process.env.FLUTTER_EXECUTABLE || process.env.SEEDING_FLUTTER || 'flutter';
  const deviceId = argValue('--device') || process.env.FLUTTER_DEVICE_ID || 'chrome';
  const seed = argValue('--seed');
  const seedDate = argValue('--seed-date') || argValue('--seed_date');
  const flutterArgs = [
    'run',
    '--device-id',
    deviceId,
    '--target',
    'scripts/reset_and_seed_inventory.dart',
  ];
  const defines = [
    `SEED_ORG=${orgId}`,
    `SEED_USER=${userId}`,
  ];
  if (authToken) defines.push(`SEED_AUTH_TOKEN=${authToken}`);
  if (seed) defines.push(`SEED_RNG=${seed}`);
  if (seedDate) defines.push(`SEED_DATE=${seedDate}`);
  defines.forEach((define) => {
    flutterArgs.push('--dart-define', define);
  });
  return new Promise((resolve, reject) => {
    const child = spawn(flutter, flutterArgs, {
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let completed = false;
    let buffer = '';
    const timeoutMs = Number(process.env.SEED_INVENTORY_TIMEOUT_MS || 20 * 60 * 1000);
    const timeout = setTimeout(() => {
      if (!completed) {
        child.kill('SIGINT');
        reject(new Error('Inventory seeding timed out.'));
      }
    }, timeoutMs);

    const handleOutput = (data) => {
      const text = data.toString();
      process.stdout.write(text);
      buffer += text;
      if (buffer.length > 20000) {
        buffer = buffer.slice(-20000);
      }
      if (!completed && buffer.includes('SEEDING_COMPLETE')) {
        completed = true;
        clearTimeout(timeout);
        child.kill('SIGINT');
      }
    };

    child.stdout.on('data', handleOutput);
    child.stderr.on('data', (data) => {
      const text = data.toString();
      process.stderr.write(text);
      buffer += text;
      if (buffer.length > 20000) {
        buffer = buffer.slice(-20000);
      }
    });

    child.on('close', (code) => {
      clearTimeout(timeout);
      if (completed) {
        resolve();
        return;
      }
      if (code !== 0) {
        reject(new Error(`Inventory seeding failed with exit code ${code}`));
        return;
      }
      resolve();
    });
  });
}

function seedHoldings(orgId, userId) {
  // NOTE: We do not seed non-coral organisms in demo data.
  if (!hasFlag('--seed-holdings')) return;
  const seed = argValue('--seed');
  const seedDate = argValue('--seed-date') || argValue('--seed_date');
  const nodeArgs = [
    'scripts/seed-non-coral-holdings.js',
    `--org=${orgId}`,
    `--user=${userId}`,
  ];
  if (seed) {
    nodeArgs.push(`--seed=${seed}`);
  }
  if (seedDate) {
    nodeArgs.push(`--seed-date=${seedDate}`);
  }
  const result = spawnSync(process.execPath, nodeArgs, { stdio: 'inherit' });
  if (result.status !== 0) {
    throw new Error(`Non-coral holdings seeding failed with exit code ${result.status}`);
  }
}

async function seedTeamActivity({ orgId, users, seed, tier = 'scale' }) {
  if (!users || users.length === 0) return;
  
  // Get tier-allowed activities to ensure we don't seed gated content
  const allowedActivities = getAllowedActivities(tier);
  const isScaleTier = tier === 'scale';

  const rng = createSeededRandom(seed);
  const orgRef = db.collection('organizations').doc(orgId);
  const [organismSnap, groupSnap] = await Promise.all([
    orgRef.collection('organismRecords').limit(120).get(),
    orgRef.collection('groups').limit(80).get(),
  ]);
  const organisms = organismSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const groups = groupSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  if (organisms.length === 0 || groups.length === 0) {
    console.log('INFO: Skipping team activity (no organism/group records found).');
    return;
  }

  const husbandryGroupTypes = new Set(['tank', 'tray', 'tree', 'dome', 'tree_branch', 'grid']);
  const husbandryGroups = groups.filter((group) => husbandryGroupTypes.has(group.groupTypeId));
  const taskStatuses = ['not_started'];
  const taskPriorities = ['low', 'medium', 'high'];
  const taskTitleTemplates = [
    'Inspect',
    'Re-check',
    'Photo check',
    'Health review',
    'Verify',
  ];
  const taskDescriptionTemplates = [
    'Routine health check; log observations and update status.',
    'Verify condition notes and capture updated photos.',
    'Confirm recent changes and add a short note.',
    'Review measurements and validate health status.',
  ];
  const diseaseTypes = [
    'disease_type_rtn',
    'disease_type_brown_jelly',
    'disease_type_stony_coral_tl',
    'disease_type_ciliates',
  ];
  const diseaseSeverities = ['mild', 'moderate', 'severe', 'critical'];
  const pestTypes = ['aiptasia', 'hydroids', 'tunicates', 'other'];
  const pestSeverities = ['light', 'moderate', 'heavy', 'severe'];
  const pestLocations = ['base of fragment', 'upper branches', 'underside', 'mounting plug'];
  const createdEvents = [];

  const now = Date.now();
  const dayMs = 24 * 60 * 60 * 1000;

  for (let i = 0; i < users.length; i += 1) {
    const user = users[i];
    const activity = user.activity || ['task', 'comment'];
    const organism = pickRandom(organisms, rng);
    const group = pickRandom(husbandryGroups.length ? husbandryGroups : groups, rng);

    if (activity.includes('task') && organism) {
      const taskCount = isScaleTier ? 3 : 1;
      const recordLabel = organism.localId || organism.recordName || organism.name || 'organism';

      for (let taskIndex = 0; taskIndex < taskCount; taskIndex += 1) {
        const eventId = db.collection('events').doc().id;
        const slug = `evt-${eventId.slice(0, 8)}`;
        const createdAt = new Date(now - Math.floor(rng() * 14) * dayMs).toISOString();
        const isDueSoon = isScaleTier ? taskIndex % 2 === 0 : true;
        const deadlineDays = isDueSoon
          ? 1 + Math.floor(rng() * 4)
          : 7 + Math.floor(rng() * 14);
        const deadline = new Date(now + deadlineDays * dayMs).toISOString();
        const statusId = taskStatuses[0];
        const titlePrefix = pickRandom(taskTitleTemplates, rng) || 'Inspect';
        const descriptionTemplate = pickRandom(taskDescriptionTemplates, rng) || 'Routine check.';
        const priorityId = isDueSoon
          ? taskPriorities[(1 + taskIndex) % taskPriorities.length]
          : taskPriorities[taskIndex % taskPriorities.length];

        const metadata = {
          organismKind: organism.organismKind || 'coral',
          organismRecordId: organism.id,
        };
        if (organism.speciesId) {
          metadata.speciesId = organism.speciesId;
        }

        createdEvents.push({
          id: eventId,
          modelType: 'event',
          eventTypeId: 'event_task',
          title: `${titlePrefix} ${recordLabel}`,
          description: `${descriptionTemplate} (${recordLabel}).`,
          priorityId,
          assignedUserId: user.id,
          // Demo tasks should not require training gates/SOPs.
          requiredTrainingModuleIds: [],
          requireSOPCompletionBeforeStart: false,
          snapshotSOPRequirements: [],
          deadline,
          statusId,
          createdById: user.id,
          createdAt,
          updatedAt: createdAt,
          updatedById: user.id,
          organizationId: orgId,
          recordId: organism.id,
          recordModelType: organism.modelType || 'organismRecord',
          urlPath: `${organism.urlPath}/${slug}`,
          internalPath: `${organism.internalPath || organism.urlPath}/${eventId}`,
          slug,
          metadata,
        });
      }
    }

    if (activity.includes('husbandry') && group) {
      const eventId = db.collection('events').doc().id;
      const slug = `evt-${eventId.slice(0, 8)}`;
      const createdAt = new Date(now - Math.floor(rng() * 20) * dayMs).toISOString();
      const comment = `Completed maintenance checks for ${group.name || 'structure'}.`;

      createdEvents.push({
        id: eventId,
        modelType: 'event',
        eventTypeId: 'event_husbandry_log',
        comment,
        createdById: user.id,
        createdAt,
        updatedAt: createdAt,
        updatedById: user.id,
        organizationId: orgId,
        recordId: group.id || eventId,
        recordModelType: group.modelType || 'group',
        urlPath: `${group.urlPath}/${slug}`,
        internalPath: `${group.internalPath || group.urlPath}/${eventId}`,
        slug,
        metadata: {
          organismKind: 'coral',
        },
      });
    }

    if (activity.includes('observation') && organism) {
      const baseCreatedAt = new Date(now - Math.floor(rng() * 10) * dayMs).toISOString();
      const recordLabel = organism.localId || organism.recordName || organism.name || 'organism';
      const healthRoll = rng();
      if (healthRoll > 0.5) {
        const eventId = db.collection('events').doc().id;
        const slug = `evt-${eventId.slice(0, 8)}`;
        const diseaseTypeId = pickRandom(diseaseTypes, rng) || 'disease_type_other';
        const severity = pickRandom(diseaseSeverities, rng) || 'moderate';
        const affectedPercentage = 5 + Math.floor(rng() * 35);
        const treatmentInitiated = rng() > 0.6;
        createdEvents.push({
          id: eventId,
          modelType: 'event',
          eventTypeId: 'event_disease_observation',
          diseaseTypeId,
          severity,
          affectedPercentage,
          treatmentInitiated,
          comment:
            `Observed ${severity} signs of disease on ${recordLabel}; ` +
            `${affectedPercentage}% of tissue affected.`,
          createdById: user.id,
          createdAt: baseCreatedAt,
          updatedAt: baseCreatedAt,
          updatedById: user.id,
          organizationId: orgId,
          recordId: organism.id,
          recordModelType: organism.modelType || 'organismRecord',
          urlPath: `${organism.urlPath}/events/${slug}`,
          internalPath: `${organism.internalPath || organism.urlPath}/${eventId}`,
          slug,
          metadata: {
            organismKind: organism.organismKind || 'coral',
            organismRecordId: organism.id,
            severity,
            diseaseTypeId,
          },
        });
      } else {
        const eventId = db.collection('events').doc().id;
        const slug = `evt-${eventId.slice(0, 8)}`;
        const pestTypeId = pickRandom(pestTypes, rng) || 'other';
        const severity = pickRandom(pestSeverities, rng) || 'moderate';
        const location = pickRandom(pestLocations, rng) || 'mounting plug';
        const mitigationPerformed = rng() > 0.55;
        createdEvents.push({
          id: eventId,
          modelType: 'event',
          eventTypeId: 'event_pest_observation',
          pestTypeId,
          severity,
          location,
          mitigationPerformed,
          comment:
            `Detected ${severity} ${pestTypeId} presence on ${recordLabel} ` +
            `near the ${location}.`,
          createdById: user.id,
          createdAt: baseCreatedAt,
          updatedAt: baseCreatedAt,
          updatedById: user.id,
          organizationId: orgId,
          recordId: organism.id,
          recordModelType: organism.modelType || 'organismRecord',
          urlPath: `${organism.urlPath}/events/${slug}`,
          internalPath: `${organism.internalPath || organism.urlPath}/${eventId}`,
          slug,
          metadata: {
            organismKind: organism.organismKind || 'coral',
            organismRecordId: organism.id,
            severity,
            pestTypeId,
            location,
          },
        });
      }
    }

    if (organism && rng() > 0.6) {
      const eventId = db.collection('events').doc().id;
      const slug = `gain-${eventId.slice(0, 8)}`;
      const createdAt = new Date(now - Math.floor(rng() * 8) * dayMs).toISOString();
      const currentPopulation = Math.max(
        1,
        Math.round(Number(organism.measurement?.value || 1)),
      );
      const delta = 1 + Math.floor(rng() * 3);
      const oldPopulation = Math.max(1, currentPopulation - delta);
      const newPopulation = oldPopulation + delta;
      const metadata = {
        organismKind: organism.organismKind || 'coral',
        organismRecordId: organism.id,
      };
      if (organism.speciesId) {
        metadata.speciesId = organism.speciesId;
      }

      createdEvents.push({
        id: eventId,
        modelType: 'event',
        eventTypeId: 'event_population_gain',
        oldPopulation,
        newPopulation,
        gainReasonId: 'population_gain_reason_fragmentation',
        comment: `Recorded new fragments for ${organism.name || 'organism'}.`,
        createdById: user.id,
        createdAt,
        updatedAt: createdAt,
        updatedById: user.id,
        organizationId: orgId,
        recordId: organism.id,
        recordModelType: organism.modelType || 'organismRecord',
        urlPath: `${organism.urlPath}/${slug}`,
        internalPath: `${organism.internalPath || organism.urlPath}/${eventId}`,
        slug,
        snapshotData: {
          ...organism,
          modelType: organism.modelType || 'organismRecord',
        },
        metadata,
      });
    }
  }

  if (createdEvents.length > 0) {
    const eventBatch = db.batch();
    createdEvents.forEach((event) => {
      eventBatch.set(db.collection('events').doc(event.id), event);
    });
    await eventBatch.commit();
    console.log(`INFO: Seeded ${createdEvents.length} team activity events.`);
  }

  const commentActors = users.filter((user) =>
    (user.activity || []).includes('comment'),
  );
  if (commentActors.length === 0) return;

  let commentTargets = createdEvents;
  if (commentTargets.length === 0) {
    const eventsSnap = await db.collection('events')
      .where('organizationId', '==', orgId)
      .limit(40)
      .get();
    commentTargets = eventsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  }
  if (commentTargets.length === 0) return;

  const taskObservationTargets = commentTargets.filter((target) => {
    const type = String(target.eventTypeId || '');
    return type === 'event_task' || type.includes('observation');
  });
  const focusedTargets = taskObservationTargets.length > 0
    ? taskObservationTargets
    : commentTargets;
  const baseCommentCount = commentActors.length;
  const commentCount = isScaleTier
    ? Math.min(Math.max(baseCommentCount * 2, focusedTargets.length), 60)
    : baseCommentCount;

  const commentBatch = db.batch();
  const commentSeeds = [];
  for (let index = 0; index < commentCount; index += 1) {
    const user = commentActors[index % commentActors.length];
    const target = focusedTargets[index % focusedTargets.length];
    const commentId = orgRef.collection('comments').doc().id;
    const createdAt = new Date(now - Math.floor(rng() * 12) * dayMs).toISOString();
    const subject = target.title || target.comment || target.eventTypeId || 'the latest update';
    const eventType = String(target.eventTypeId || '');
    const isTask = eventType === 'event_task';
    const isObservation = eventType.includes('observation');
    const prefix = isTask
      ? 'Task update'
      : isObservation
        ? 'Observation note'
        : user.role === 'view_only'
          ? 'Review note'
          : 'Follow-up';
    const content = `${prefix}: ${subject}.`;

    const commentData = {
      id: commentId,
      organizationId: orgId,
      targetType: 'event',
      targetId: target.id,
      authorUid: user.id,
      authorName: user.name,
      content,
      createdAt,
      mentions: [],
      reactions: {},
      isEdited: false,
      isDeleted: false,
    };

    commentBatch.set(orgRef.collection('comments').doc(commentId), commentData);
    commentSeeds.push({ comment: commentData, target });
  }
  await commentBatch.commit();
  console.log(`INFO: Seeded ${commentCount} team comments.`);

  await seedCommentEvents({ orgId, commentSeeds });
}

async function seedCommentEvents({ orgId, commentSeeds }) {
  if (!commentSeeds || commentSeeds.length === 0) return;

  const batch = db.batch();
  let createdCount = 0;

  commentSeeds.forEach(({ comment, target }) => {
    if (!target || !comment) return;
    const recordId = target.recordId;
    const recordModelType = target.recordModelType;
    if (!recordId || !recordModelType) return;

    const parentUrlPath = stripTrailingSegment(target.urlPath) || target.urlPath;
    const parentInternalPath =
      stripTrailingSegment(target.internalPath) ||
      `organizations/${orgId}/events`;
    if (!parentUrlPath || !parentInternalPath) return;

    const eventId = db.collection('events').doc().id;
    const slug = `comment-${eventId.slice(0, 8)}`;
    const createdAt = comment.createdAt || new Date().toISOString();
    const metadata = {
      commentId: comment.id,
      commentText: comment.content,
      commentAuthorName: comment.authorName,
      commentTargetType: comment.targetType,
      commentTargetId: comment.targetId,
      targetEventId: target.id,
    };
    if (target.metadata && target.metadata.organismKind) {
      metadata.organismKind = target.metadata.organismKind;
    }

    batch.set(db.collection('events').doc(eventId), {
      id: eventId,
      modelType: 'event',
      eventTypeId: 'event_comment',
      createdById: comment.authorUid,
      createdAt,
      updatedAt: createdAt,
      updatedById: comment.authorUid,
      organizationId: orgId,
      recordId,
      recordModelType,
      urlPath: `${parentUrlPath}/${slug}`,
      internalPath: `${parentInternalPath}/${eventId}`,
      slug,
      metadata,
    });
    createdCount += 1;
  });

  if (createdCount > 0) {
    await batch.commit();
    console.log(`INFO: Seeded ${createdCount} comment events.`);
  }
}

async function seedOrganizationChannels({ orgId, users, seed, tier = 'scale' }) {
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
  const isScaleTier = tier === 'scale';

  const channelSlug = (input) => {
    const raw = String(input || '');
    const slug = raw
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+/, '')
      .replace(/-+$/, '');
    if (slug) return slug;
    const fallbackId = Array.from(raw).reduce((sum, ch) => sum + ch.charCodeAt(0), 0);
    return `site-${Math.abs(fallbackId) || 0}`;
  };

  const channelTemplates = [
    {
      name: 'general',
      description: 'General organization channel',
    },
    {
      name: 'operations',
      description: 'Operations updates and scheduling',
    },
    {
      name: 'monitoring',
      description: 'Monitoring notes and survey planning',
    },
  ];

  const messagesByChannel = {
    general: [
      'Good morning team, quick sync at 9am.',
      'Water quality checks completed for all nurseries.',
      'Weather looks clear for the outplanting window.',
      'Heads up: vendor delivery scheduled for this afternoon.',
      'Great job on yesterday\'s monitoring coverage.',
      'Sharing updated SOP links in the docs folder.',
      'Let\'s capture photos during today\'s maintenance.',
    ],
    operations: [
      'Tank cleaning schedule updated for the week.',
      'Please log equipment maintenance by EOD.',
      'Supply inventory is low on epoxy and gloves.',
      'Crew rotation posted for the next field day.',
      'Reminder: pump inspection is due tomorrow.',
      'We need extra hands for the nursery walkthrough.',
    ],
    monitoring: [
      'Baseline survey planned for Friday morning.',
      'Reference site visibility was excellent today.',
      'Reminder to log bleaching observations in the form.',
      'Pre-outplant monitoring notes uploaded.',
      'Eco survey data synced to the shared drive.',
    ],
    site: [
      'Site check-in complete; conditions are stable.',
      'Noticed slight sediment buildup near rack 2.',
      'Photo series captured for growth comparison.',
      'Diver notes uploaded to the site record.',
      'Planning to revisit this site after the weekend.',
    ],
  };
  const scaleTaskDiscussion = [
    'Task queue updated — please review assignments.',
    'Flagged a pending inspection that needs coverage.',
    'Added a follow-up task based on today\'s findings.',
    'Reminder: log task outcomes with photos.',
  ];
  const scaleObservationDiscussion = [
    'Observation logs look good; please add notes where needed.',
    'Noted a change in health status — review observation details.',
    'Added an observation follow-up task for the next visit.',
    'Please attach photos to the latest observations.',
  ];

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
      siteName: site.name,
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

    const messagePool = [
      ...(channelData.messagePool || messagesByChannel.general),
    ];
    if (isScaleTier) {
      if (channelData.name === 'monitoring') {
        messagePool.push(...scaleObservationDiscussion);
      } else if (channelData.name === 'operations') {
        messagePool.push(...scaleTaskDiscussion);
      } else {
        messagePool.push(...scaleTaskDiscussion, ...scaleObservationDiscussion);
      }
    }
    const messageCount = 6 + Math.floor(rng() * 7);
    let lastMessage = null;
    let lastMessageTime = null;

    for (let i = 0; i < messageCount; i += 1) {
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

function buildUserSnapshot(user, orgId, createdAt) {
  return {
    id: user.id,
    modelType: 'user',
    name: user.name,
    email: user.email.toLowerCase(),
    role: user.role,
    tagline: user.title,
    organizationId: orgId,
    createdAt,
    updatedAt: createdAt,
    createdById: user.id,
    updatedById: user.id,
    metadata: { isDemo: true },
  };
}

async function seedUserHistoryEvents({ orgId, users, seed }) {
  if (!users || users.length === 0) return;
  const rng = createSeededRandom(seed);
  const now = Date.now();
  const dayMs = 24 * 60 * 60 * 1000;
  const events = [];

  users.forEach((user, index) => {
    const baseDate = new Date(now - (index + 2) * dayMs);
    const snapshotData = buildUserSnapshot(user, orgId, baseDate.toISOString());
    const eventId = db.collection('events').doc().id;
    const slug = `user-update-${eventId.slice(0, 6)}`;
    events.push({
      eventTypeId: 'event_update',
      updateType: 'profile_update',
      fieldUpdates: {
        tagline: user.title,
        role: user.role,
      },
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
      snapshotData,
      metadata: { auditSource: 'seed' },
    });

    const activityDate = new Date(
      baseDate.getTime() + (1 + Math.floor(rng() * 3)) * dayMs,
    );
    const activityEventId = db.collection('events').doc().id;
    const activitySlug = `user-activity-${activityEventId.slice(0, 6)}`;
    events.push({
      eventTypeId: 'event_activity',
      activityType: 'login',
      description: 'User logged in to view dashboard.',
      parameters: {
        device: rng() > 0.5 ? 'mobile' : 'web',
        location: rng() > 0.5 ? 'Field site' : 'Lab',
      },
      id: activityEventId,
      modelType: 'event',
      organizationId: orgId,
      createdAt: activityDate.toISOString(),
      updatedAt: activityDate.toISOString(),
      createdById: user.id,
      updatedById: user.id,
      recordId: user.id,
      recordModelType: 'user',
      slug: activitySlug,
      urlPath: `users/${user.id}/events/${activitySlug}`,
      internalPath: `organizations/${orgId}/events/${activityEventId}`,
      snapshotData,
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

/**
 * Seed a single tier's demo organization and users.
 * @param {string} tier - 'community', 'pro', or 'scale'
 * @param {Object} options - Seeding options
 */
async function seedSingleTier(tier, options = {}) {
  const tierConfig = DEMO_TIER_CONFIG[tier];
  if (!tierConfig) {
    throw new Error(`Unknown tier: ${tier}. Must be one of: community, pro, scale`);
  }

  const userEmail = options.userEmail || tierConfig.primaryEmail;
  const orgId = options.orgId || tierConfig.orgId;
  const orgName = options.orgName || tierConfig.orgName;
  const seed = options.seed;
  const shouldReset = options.reset ?? true;

  console.log(`\n${'='.repeat(60)}`);
  console.log(`Seeding ${tier.toUpperCase()} tier demo organization`);
  console.log(`  Org ID: ${orgId}`);
  console.log(`  Primary user: ${userEmail}`);
  console.log(`  Team size limit: ${tierConfig.teamSizeLimit}`);
  console.log(`  Allowed activities: ${tierConfig.allowedActivities.join(', ')}`);
  console.log(`${'='.repeat(60)}\n`);

  // Create auth user
  const password = resolveUserPassword(tier);
  const authUser = await ensureAuthUser({
    email: userEmail,
    displayName: 'Demo Admin',
    password,
  });
  const userId = authUser.uid;

  // Reset if requested
  if (shouldReset) {
    await resetDemoData({ orgId, userId });
  }

  // Upsert organization
  await upsertOrganization({
    orgId,
    orgName,
    orgDomain: orgName.toLowerCase().replace(/[^a-z0-9]/g, '-'),
    tier,
    userId,
    existingDoc: null,
  });

  // Seed brand profile for this org
  await seedBrandProfile({ orgId, orgName, userId });

  // Build users array
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

  // Build team
  const teamTemplates = buildTeamTemplates(tier);
  const teamSizeLimit = tierConfig.teamSizeLimit;
  const teamCount = Math.min(teamSizeLimit - 1, teamTemplates.length);
  const activityUsers = [];

  if (teamCount > 0) {
    console.log(`INFO: Seeding ${teamCount} demo team users for ${tier} tier.`);
    for (let i = 0; i < teamCount; i += 1) {
      const template = teamTemplates[i];
      const email = `${emailPrefix}${i + 1}@${domain}`;
      const authRecord = await ensureAuthUser({
        email,
        displayName: template.name,
        password,
      });
      const user = {
        id: authRecord.uid,
        email,
        name: template.name,
        role: template.role,
        title: template.title,
        activity: template.activity,
      };
      users.push(user);
      activityUsers.push(user);
    }
  }

  // Upsert users
  for (const user of users) {
    await upsertUser(user, orgId, userId);
  }

  // Seed data
  await seedUserHistoryEvents({ orgId, users, seed });
  await seedTrainingCompletions({ userId, orgId });

  // Seed training content (SOPs and media) - global template data, only once
  if (!trainingContentSeeded) {
    console.log('INFO: Seeding training content (SOPs and media)...');
    const trainingSeeder = new TrainingSeeder();
    await trainingSeeder.seed({ overwrite: false });
    trainingContentSeeded = true;
    console.log('INFO: Training content seeded.');
  }

  const postIds = await seedCommunityPosts({
    orgId,
    orgName,
    users,
    skipPosts: hasFlag('--skip-posts'),
  });

  // Seed comments on community posts (Pro and Scale tiers only)
  await seedCommunityPostComments({
    orgId,
    postIds: postIds || [],
    users,
    tier,
    seed,
  });

  let authToken = null;
  try {
    authToken = await admin.auth().createCustomToken(userId);
  } catch (e) {
    if (process.env.USE_DART_SEEDER) {
      throw new Error(`createCustomToken failed and Dart seeder requires it: ${e.message}`);
    }
    console.warn('WARN: createCustomToken unavailable (user credentials); Node.js seeder does not need it.');
  }
  await seedInventory(orgId, userId, authToken, tier);
  seedHoldings(orgId, userId);
  await seedOrganizationChannels({ orgId, users, seed, tier });
  await seedTeamActivity({ orgId, users: activityUsers, seed, tier });

  console.log(`OK: ${tier.toUpperCase()} tier demo seeding complete.`);
}

async function main() {
  // Check for --seed-all-tiers flag
  if (hasFlag('--seed-all-tiers')) {
    console.log('\n' + '='.repeat(70));
    console.log('SEEDING ALL THREE DEMO TIERS');
    console.log('='.repeat(70));

    const seed = argValue('--seed');
    const shouldReset = hasFlag('--reset');

    // Seed all three tiers in order
    for (const tier of ['community', 'pro', 'scale']) {
      await seedSingleTier(tier, { seed, reset: shouldReset });
    }

    console.log('\n' + '='.repeat(70));
    console.log('ALL DEMO TIERS SEEDED SUCCESSFULLY');
    console.log('='.repeat(70));
    console.log('\nDemo accounts:');
    console.log('  Community: community@provenance.app (password: demo123)');
    console.log('  Pro:       pro@provenance.app (password: demo123)');
    console.log('  Scale:     scale@provenance.app (password: demo123)');
    console.log('\n');
    return;
  }

  // Single-tier mode (original logic)
  const explicitTier = argValue('--tier');
  let tier = normalizeTier(explicitTier || process.env.DEMO_TIER);
  const userEmailRaw = resolveUserEmail(tier, argValue('--user'));
  const userEmail = userEmailRaw ? userEmailRaw.toLowerCase() : null;
  const seed = argValue('--seed');

  if (!userEmail) {
    console.error('Missing --user. Example:');
    console.error('  node scripts/seed-demo.js --reset --user=scale@provenance.app --tier=scale');
    console.error('\nOr seed all tiers at once:');
    console.error('  node scripts/seed-demo.js --seed-all-tiers --reset');
    process.exit(1);
  }

  // Use ensureAuthUser to create the Firebase Auth user if it doesn't exist
  const password = resolveUserPassword(tier);
  const authUser = await ensureAuthUser({
    email: userEmail,
    displayName: 'Demo Admin',
    password,
  });
  const userId = authUser.uid;
  const normalizedEmail = (authUser.email || userEmail).toLowerCase();
  const userDoc = await findUserDocByEmail(normalizedEmail);
  const orgIdentifier = resolveOrgId(tier, argValue('--org')) ||
    (userDoc ? userDoc.doc.data().organizationId : null);

  if (!orgIdentifier) {
    console.error('Missing --org. Provide --org or ensure the user has organizationId set.');
    console.error('  node scripts/seed-demo.js --reset --org=ORG_ID --user=scale@provenance.app --tier=scale');
    process.exit(1);
  }

  const { id: orgId, doc: orgDoc } = await resolveOrganization(orgIdentifier);
  const orgName = argValue('--name') || (orgDoc ? orgDoc.data().name : null);
  const orgDomain = argValue('--domain') || (orgDoc ? orgDoc.data().domain : null);
  const shouldReset = hasFlag('--reset');

  if (shouldReset) {
    await resetDemoData({ orgId, userId });
  }

  console.log(`INFO: Seeding demo org ${orgId} (${tier} tier)...`);

  await upsertOrganization({
    orgId,
    orgName,
    orgDomain,
    tier,
    userId,
    existingDoc: shouldReset ? null : orgDoc,
  });

  // Seed brand profile for this org
  const effectiveBrandName = orgName || defaultOrgName(tier);
  await seedBrandProfile({ orgId, orgName: effectiveBrandName, userId });

  const [local, domain] = normalizedEmail.split('@');
  // Use tier name as email prefix for team members (e.g., pro1@provenance.app)
  const emailPrefix = local.split('+')[0];

  const users = [
    {
      id: userId,
      email: normalizedEmail,
      name: 'Demo Admin',
      role: 'admin',
      title: 'Program Lead',
    },
  ];

  const teamSizeArg = argValue('--team-size') || process.env.DEMO_TEAM_SIZE;
  const rawTeamSize = Number.parseInt(teamSizeArg, 10);
  const isProvenanceDemo = domain === 'provenance.app' && ['community', 'pro', 'scale'].includes(emailPrefix);
  
  // Get tier-specific team size limit
  const tierTeamSizeLimit = resolveTeamSizeLimit(tier);
  
  const shouldSeedTeam = hasFlag('--with-team') || !!teamSizeArg || isProvenanceDemo;
  const requestedTeamSize = Number.isFinite(rawTeamSize)
    ? rawTeamSize
    : (shouldSeedTeam ? tierTeamSizeLimit : 1);
  
  // Clamp to tier limit
  const resolvedTeamSize = Math.max(1, Math.min(tierTeamSizeLimit, requestedTeamSize));
  
  // Build team templates filtered by tier-allowed activities
  const teamTemplates = buildTeamTemplates(tier);
  const teamCount = shouldSeedTeam
    ? Math.min(resolvedTeamSize - 1, teamTemplates.length)
    : 0;
  
  if (shouldSeedTeam && resolvedTeamSize < requestedTeamSize) {
    console.log(`INFO: Team size capped at ${resolvedTeamSize} for ${tier} tier.`);
  }
  const teamPassword = resolveUserPassword(tier);
  const activityUsers = [];

  if (teamCount > 0) {
    console.log(`INFO: Seeding ${teamCount} demo team users.`);
    for (let i = 0; i < teamCount; i += 1) {
      const template = teamTemplates[i];
      const email = `${emailPrefix}${i + 1}@${domain}`;
      const authRecord = await ensureAuthUser({
        email,
        displayName: template.name,
        password: teamPassword,
      });
      const user = {
        id: authRecord.uid,
        email,
        name: template.name,
        role: template.role,
        title: template.title,
        activity: template.activity,
      };
      users.push(user);
      activityUsers.push(user);
    }
  }

  for (const user of users) {
    await upsertUser(user, orgId, userId);
  }
  await seedUserHistoryEvents({ orgId, users, seed });
  await seedTrainingCompletions({ userId, orgId });

  // Seed training content (SOPs and media) - global template data, only once
  if (!trainingContentSeeded) {
    console.log('INFO: Seeding training content (SOPs and media)...');
    const trainingSeeder = new TrainingSeeder();
    await trainingSeeder.seed({ overwrite: false });
    trainingContentSeeded = true;
    console.log('INFO: Training content seeded.');
  }

  const effectiveOrgName = orgName || defaultOrgName(tier);
  const postIds = await seedCommunityPosts({
    orgId,
    orgName: effectiveOrgName,
    users,
    skipPosts: hasFlag('--skip-posts'),
  });

  // Seed comments on community posts (Pro and Scale tiers only)
  await seedCommunityPostComments({
    orgId,
    postIds: postIds || [],
    users,
    tier,
    seed,
  });

  let authToken = null;
  try {
    authToken = await admin.auth().createCustomToken(userId);
  } catch (e) {
    if (process.env.USE_DART_SEEDER) {
      throw new Error(`createCustomToken failed and Dart seeder requires it: ${e.message}`);
    }
    console.warn('WARN: createCustomToken unavailable (user credentials); Node.js seeder does not need it.');
  }
  await seedInventory(orgId, userId, authToken, tier);
  seedHoldings(orgId, userId);
  await seedOrganizationChannels({ orgId, users, seed, tier });
  await seedTeamActivity({ orgId, users: activityUsers, seed, tier });

  console.log(`OK: Demo seeding complete for ${tier} tier.`);
}

main().catch((error) => {
  console.error('ERROR: Demo seeding failed:', error.message || error);
  process.exit(1);
});
