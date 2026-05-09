#!/usr/bin/env node

/**
 * Node.js-based coral inventory seeder
 *
 * Creates sites, groups, genets, and organism records directly via Firebase Admin SDK.
 * Replaces the Dart-based seeder to avoid web runtime hanging issues.
 *
 * NOTE: Production database must be wiped/reset after Data Field Unification (SOT)
 * so all new data uses canonical fields: genetId (top-level), physicalFormId,
 * SizeSpec format. No legacy fields (morphologyId, sizeClass, metadata.genetId,
 * metadata.provenanceId, foreignKeys.genet) are written by this script.
 *
 * Usage:
 *   node scripts/seed-coral-inventory.js --org=ORG_ID --user=USER_ID [--seed=N] [--seed-date=YYYY-MM-DD]
 */

const { admin, db } = require('./config-json');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);

// Load CRC/HOG crosswalk data for realistic provenance associations
function loadCrosswalkData() {
  const bySpecies = {};
  try {
    const crosswalkPath = path.resolve(__dirname, '..', 'crc_db', 'pid_crosswalk.json');
    if (!fs.existsSync(crosswalkPath)) {
      console.log('INFO: No crosswalk data found at crc_db/pid_crosswalk.json');
      return bySpecies;
    }
    const entries = JSON.parse(fs.readFileSync(crosswalkPath, 'utf8'));
    for (const entry of entries) {
      const code = entry.speciesCode;
      if (!code) continue;
      if (!bySpecies[code]) bySpecies[code] = [];
      bySpecies[code].push(entry);
    }
    const total = Object.values(bySpecies).reduce((sum, arr) => sum + arr.length, 0);
    console.log(`INFO: Loaded ${total} crosswalk entries (${Object.keys(bySpecies).join(', ')})`);
  } catch (err) {
    console.log(`WARN: Could not load crosswalk data: ${err.message}`);
  }
  return bySpecies;
}

const CROSSWALK_DATA = loadCrosswalkData();

function argValue(prefix) {
  const match = args.find((arg) => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

// Seeded random number generator for deterministic output
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

function resolvePhysicalFormForLifeStage(lifeStage, rng) {
  const stageKey = lifeStage === LIFE_STAGES.broodstock
    ? 'broodstock'
    : lifeStage === LIFE_STAGES.adult
      ? 'adult'
      : 'juvenile';
  const options = PHYSICAL_FORM_PROFILES[stageKey] || PHYSICAL_FORM_PROFILES.juvenile;
  return pickRandom(options, rng) || options[0];
}

function formatDate(date) {
  return date.toISOString().split('T')[0];
}

const DAY_MS = 24 * 60 * 60 * 1000;

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function listMonthStarts(start, end) {
  const months = [];
  let cursor = new Date(start.getFullYear(), start.getMonth(), 1);
  const endMonth = new Date(end.getFullYear(), end.getMonth(), 1);
  while (cursor <= endMonth) {
    months.push(new Date(cursor));
    cursor.setMonth(cursor.getMonth() + 1);
  }
  return months;
}

function randomDateBetween(start, end, rng) {
  const startTime = start.getTime();
  const endTime = end.getTime();
  if (endTime <= startTime) return new Date(startTime);
  const offset = Math.floor(rng() * (endTime - startTime + DAY_MS));
  return new Date(startTime + offset);
}

function pickDateInAllowedMonths({ start, end, allowedMonths, rng }) {
  const monthStarts = listMonthStarts(start, end).filter((date) =>
    allowedMonths.includes(date.getMonth())
  );
  if (!monthStarts.length) {
    return randomDateBetween(start, end, rng);
  }
  const monthStart = pickRandom(monthStarts, rng);
  const daysInMonth = new Date(
    monthStart.getFullYear(),
    monthStart.getMonth() + 1,
    0,
  ).getDate();
  const day = 1 + Math.floor(rng() * daysInMonth);
  const candidate = new Date(monthStart.getFullYear(), monthStart.getMonth(), day);
  if (candidate < start) return new Date(start);
  if (candidate > end) return new Date(end);
  return candidate;
}

function seasonalDate({
  anchorDate,
  rng,
  allowedMonths,
  windowDays = 365,
}) {
  const end = startOfDay(anchorDate);
  const start = new Date(end.getTime() - windowDays * DAY_MS);
  return pickDateInAllowedMonths({ start, end, allowedMonths, rng });
}

function slugify(input) {
  return (input || '')
    .toString()
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-_ ]/g, '')
    .replace(/\s+/g, '-');
}

function normalizeUrlPrefix(value) {
  return (value || '')
    .toString()
    .trim()
    .replace(/^\/+/, '')
    .replace(/\/+$/, '');
}

function resolveOrganizationUrlPrefix(orgData, orgId) {
  const candidate =
    orgData?.domain ||
    orgData?.slug ||
    orgData?.urlPath ||
    orgId;
  const normalized = normalizeUrlPrefix(candidate);
  return normalized || orgId;
}

function groupLabel(typeId) {
  return GROUP_TYPE_LABELS[typeId] || typeId;
}

function isEmail(value) {
  return typeof value === 'string' && value.includes('@');
}

async function resolveAuthUser(userId) {
  if (!userId) return null;
  const auth = admin.auth();
  try {
    if (isEmail(userId)) {
      return await auth.getUserByEmail(userId.toLowerCase());
    }
    return await auth.getUser(userId);
  } catch (error) {
    return null;
  }
}

async function ensureUserAndMembership({ orgId, userId }) {
  const now = new Date().toISOString();
  const orgRef = db.collection('organizations').doc(orgId);
  const orgSnap = await orgRef.get();
  if (!orgSnap.exists) {
    throw new Error(`Organization ${orgId} not found. Run seed-demo first.`);
  }
  const orgData = orgSnap.data() || {};
  const orgUrlPrefix = resolveOrganizationUrlPrefix(orgData, orgId);

  const authUser = await resolveAuthUser(userId);
  const resolvedUserId = authUser?.uid || userId;
  const resolvedEmail = authUser?.email?.toLowerCase() || (isEmail(userId) ? userId.toLowerCase() : null);
  const resolvedName = authUser?.displayName || null;

  if (!resolvedUserId) {
    throw new Error('Unable to resolve user id for seeding.');
  }

  if (!authUser && isEmail(userId)) {
    console.warn(`WARN: No Auth user found for ${userId}. Using email as document id.`);
  }

  if (resolvedUserId !== userId) {
    console.log(`INFO: Using resolved UID ${resolvedUserId} for ${userId}.`);
  }

  const userRef = db.collection('users').doc(resolvedUserId);
  const existingUser = await userRef.get();
  const existingData = existingUser.exists ? existingUser.data() : null;
  const role = existingData?.role || 'admin';
  const name = existingData?.name || resolvedName || 'Demo Admin';
  const email = existingData?.email || resolvedEmail;
  const createdAt = existingData?.createdAt || now;
  const createdById = existingData?.createdById || resolvedUserId;
  const onboardingCompletedAt = existingData?.onboardingCompletedAt || now;
  const metadata = {
    ...(existingData?.metadata || {}),
    isDemo: true,
    hasCompletedTour: true,
  };

  const userPayload = {
    id: resolvedUserId,
    name,
    role,
    organizationId: orgId,
    modelType: 'user',
    createdAt,
    createdById,
    updatedAt: now,
    updatedById: resolvedUserId,
    onboardingCompletedAt,
    metadata,
  };
  if (email) userPayload.email = email;
  if (existingData?.tagline) userPayload.tagline = existingData.tagline;
  if (existingData?.imageUrl) userPayload.imageUrl = existingData.imageUrl;
  if (existingData?.legalAcceptances) {
    userPayload.legalAcceptances = existingData.legalAcceptances;
  }

  await userRef.set(userPayload, { merge: true });

  const membershipRef = orgRef.collection('members').doc(resolvedUserId);
  const membershipSnap = await membershipRef.get();
  const existingMembership = membershipSnap.exists ? membershipSnap.data() : null;
  const joinedAt = existingMembership?.joinedAt || createdAt;
  const memberPayload = {
    uid: resolvedUserId,
    memberId: resolvedUserId,
    role,
    joinedAt,
    createdById: existingMembership?.createdById || resolvedUserId,
    organizationId: orgId,
    createdAt: existingMembership?.createdAt || now,
    updatedAt: now,
  };
  if (email) memberPayload.email = email;

  await membershipRef.set(memberPayload, { merge: true });

  return { userId: resolvedUserId, email, orgUrlPrefix };
}

// Species data
// demoCode: 4-letter code used for demo PIDs (PID-DM{XX}-NNNN) to avoid collisions
// with real CRC provenance IDs which use the production species codes.
// Canonical short species IDs (matches taxonomy_species collection)
const SPECIES = {
  apal: { id: 'apal', code: 'APAL', demoCode: 'DMAP', name: 'Acropora palmata', organismKind: 'coral' },
  acer: { id: 'acer', code: 'ACER', demoCode: 'DMAC', name: 'Acropora cervicornis', organismKind: 'coral' },
  past: { id: 'past', code: 'PAST', demoCode: 'DMPA', name: 'Porites astreoides', organismKind: 'coral' },
  pstr: { id: 'pstr', code: 'PSTR', demoCode: 'DMPS', name: 'Pseudodiploria strigosa', organismKind: 'coral' },
  cnat: { id: 'cnat', code: 'CNAT', demoCode: 'DMCN', name: 'Colpophyllia natans', organismKind: 'coral' },
  mcav: { id: 'mcav', code: 'MCAV', demoCode: 'DMMC', name: 'Montastraea cavernosa', organismKind: 'coral' },
  ofav: { id: 'ofav', code: 'OFAV', demoCode: 'DMOF', name: 'Orbicella faveolata', organismKind: 'coral' },
};

// Organism kinds (coral-only community fork)
const ORGANISM_KINDS = {
  coral: 'coral',
};

// Site types (coral-only)
const SITE_TYPES = {
  nurseryExSitu: 'site_type_nursery_ex_situ',
  nurseryInSitu: 'site_type_nursery_in_situ',
  geneBank: 'site_type_gene_bank',
  outplantSite: 'site_type_outplanting',
  baselineSite: 'site_type_baseline',
  referenceSite: 'site_type_reference',
};

// Group types (coral-only)
const GROUP_TYPES = {
  tank: 'group_type_tank',
  tray: 'group_type_tray',
  tree: 'group_type_tree',
  treeBranch: 'group_type_tree_branch',
  dome: 'group_type_dome',
  grid: 'group_type_grid',
  gridCell: 'group_type_grid_cell',
  tag: 'group_type_tag',
};

const GROUP_TYPE_LABELS = {
  [GROUP_TYPES.tank]: 'Tank',
  [GROUP_TYPES.tray]: 'Tray',
  [GROUP_TYPES.tree]: 'Tree',
  [GROUP_TYPES.treeBranch]: 'Tree Branch',
  [GROUP_TYPES.dome]: 'Dome',
  [GROUP_TYPES.grid]: 'Grid',
  [GROUP_TYPES.gridCell]: 'Grid Cell',
  [GROUP_TYPES.tag]: 'Tag',
};

// Life stages
const LIFE_STAGES = {
  gamete: 'life_stage_gamete',
  embryo: 'life_stage_embryo',
  larva: 'life_stage_larva',
  juvenile: 'life_stage_juvenile',
  adult: 'life_stage_adult',
  broodstock: 'life_stage_broodstock',
};

// Physical form profiles for coral
const PHYSICAL_FORM_PROFILES = {
  juvenile: [
    { formId: 'settlement_substrate', sizeBandId: 'small' },
    { formId: 'microfragment', sizeBandId: 'small' },
    { formId: 'mounted_individual', sizeBandId: 'small' },
  ],
  adult: [
    { formId: 'fragment', sizeBandId: 'medium' },
    { formId: 'mounted_individual', sizeBandId: 'medium' },
    { formId: 'colony', sizeBandId: 'small' },
  ],
  broodstock: [
    { formId: 'spawning_colony', sizeBandId: 'medium' },
    { formId: 'spawning_colony', sizeBandId: 'large' },
  ],
  // Cohort stages (larva, embryo)
  larva: [
    { formId: 'larval_container', sizeBandId: 'small' },
    { formId: 'larval_container', sizeBandId: 'medium' },
    { formId: 'settlement_substrate', sizeBandId: 'small' },
  ],
  embryo: [
    { formId: 'larval_container', sizeBandId: 'xs' },
    { formId: 'larval_container', sizeBandId: 'small' },
  ],
};

// Inventory metrics by physical form and size band
// Values based on organism_physical_forms.yaml YAML config
// volume_mm3 values from YAML are converted to cm³ (divide by 1000)
const CORAL_INVENTORY_METRICS = {
  // Coral juvenile forms
  settlement_substrate: {
    xs: { tissueAreaCm2: 4 },
    small: { tissueAreaCm2: 9 },
    medium: { tissueAreaCm2: 15 },
    large: { tissueAreaCm2: 34 },
    xl: { tissueAreaCm2: 61 },
  },
  mounted_individual: {
    // Juvenile mounted_individual has no volume (volume_mm3: 0 in YAML)
    xs: { tissueAreaCm2: 2 },
    small: { tissueAreaCm2: 4 },
    medium: { tissueAreaCm2: 10 },
    large: { tissueAreaCm2: 25 },
    xl: { tissueAreaCm2: 57 },
  },
  microfragment: {
    xs: { tissueAreaCm2: 1 },
    small: { tissueAreaCm2: 1 },
    medium: { tissueAreaCm2: 4 },
    large: { tissueAreaCm2: 14 },
    xl: { tissueAreaCm2: 39 },
  },
  // Coral adult forms (with volume from YAML volume_mm3 / 1000)
  fragment: {
    small: { tissueAreaCm2: 10, volumeCm3: 4.09 },
    medium: { tissueAreaCm2: 88, volumeCm3: 110.45 },
    large: { tissueAreaCm2: 353, volumeCm3: 883.57 },
    xl: { tissueAreaCm2: 982, volumeCm3: 4090.62 },
  },
  // Adult mounted_individual has volume
  mounted_individual_adult: {
    small: { tissueAreaCm2: 14, volumeCm3: 7.07 },
    medium: { tissueAreaCm2: 57, volumeCm3: 56.55 },
    large: { tissueAreaCm2: 157, volumeCm3: 261.80 },
    xl: { tissueAreaCm2: 327, volumeCm3: 718.38 },
  },
  colony: {
    small: { tissueAreaCm2: 353, volumeCm3: 883.57 },
    medium: { tissueAreaCm2: 1414, volumeCm3: 7068.58 },
    large: { tissueAreaCm2: 3927, volumeCm3: 32724.92 },
    xl: { tissueAreaCm2: 7697, volumeCm3: 89797.19 },
  },
  spawning_colony: {
    small: { tissueAreaCm2: 3927, volumeCm3: 32724.92 },
    medium: { tissueAreaCm2: 7697, volumeCm3: 89797.19 },
    large: { tissueAreaCm2: 12723, volumeCm3: 190851.75 },
    xl: { tissueAreaCm2: 15708, volumeCm3: 261799.39 },
  },
  shared_substrate: {
    small: { tissueAreaCm2: 15, volumeCm3: 10 },
    medium: { tissueAreaCm2: 60, volumeCm3: 20 },
    large: { tissueAreaCm2: 167, volumeCm3: 40 },
    xl: { tissueAreaCm2: 327, volumeCm3: 80 },
  },
  // Liquid forms (gametes, larvae)
  liquid_suspension: {
    xs: { volumeCm3: 0.5 },
    small: { volumeCm3: 1 },
    medium: { volumeCm3: 5 },
    large: { volumeCm3: 10 },
    xl: { volumeCm3: 50 },
  },
  larval_container: {
    xs: { volumeCm3: 50 },
    small: { volumeCm3: 100 },
    medium: { volumeCm3: 500 },
    large: { volumeCm3: 1000 },
    xl: { volumeCm3: 5000 },
  },
};

/**
 * Calculate inventory metrics for an organism based on physical form and quantity.
 * Returns { inventoryCount, inventoryVolumeCm3?, inventoryTissueAreaCm2? }
 */
function calculateInventoryMetrics(physicalForm, quantity) {
  const metrics = { inventoryCount: quantity };

  if (!physicalForm || !physicalForm.formId) {
    return metrics;
  }

  const formId = physicalForm.formId;
  const sizeBandId = physicalForm.sizeBandId || 'medium';

  const formMetrics = CORAL_INVENTORY_METRICS[formId];
  if (!formMetrics) {
    return metrics;
  }

  const bandMetrics = formMetrics[sizeBandId] || formMetrics.medium || formMetrics.small;
  if (!bandMetrics) {
    return metrics;
  }

  // Volume is typically per-unit (e.g., per vial), so multiply by quantity
  if (bandMetrics.volumeCm3 != null) {
    metrics.inventoryVolumeCm3 = bandMetrics.volumeCm3 * quantity;
  }

  // Tissue area is typically per-unit (e.g., per fragment), so multiply by quantity
  if (bandMetrics.tissueAreaCm2 != null) {
    metrics.inventoryTissueAreaCm2 = bandMetrics.tissueAreaCm2 * quantity;
  }

  return metrics;
}

const RECORD_NAME_ADJECTIVES = [
  'fluffy',
  'brisk',
  'sunny',
  'mossy',
  'lively',
  'calm',
  'bright',
  'swift',
  'gentle',
  'bold',
  'soft',
  'tidal',
  'salty',
  'sandy',
  'vivid',
  'clear',
  'crisp',
  'mellow',
  'spry',
  'rustic',
  'verdant',
  'spruce',
  'pearl',
  'azure',
];

const recordNameCounters = new Map();

function deriveRecordName(localId, suffixIndex) {
  if (!localId) return null;
  const normalized = localId.trim().toLowerCase().replace(/\s+/g, '-');
  let hash = 0;
  for (let i = 0; i < normalized.length; i++) {
    hash = (hash * 31 + normalized.charCodeAt(i)) & 0x7fffffff;
  }
  const adjective = RECORD_NAME_ADJECTIVES[hash % RECORD_NAME_ADJECTIVES.length];
  const base = adjective.charAt(0).toUpperCase() + adjective.slice(1);
  if (!suffixIndex || suffixIndex <= 1) {
    return base;
  }
  return `${base}${suffixIndex}`;
}

// Provenance types (community tier supports wild and transfer)
const PROVENANCE_TYPES = {
  wild: 'provenance_type_wild',
  transfer: 'provenance_type_transfer',
  unknown: 'provenance_type_unknown',
};

const OUTPLANT_MONTHS = [2, 3, 4, 8, 9, 10]; // Mar-May, Sep-Nov

async function seedInventory({ orgId, userId, seed, seedDate, orgUrlPrefix }) {
  const rng = createSeededRandom(seed || 7);
  const baseDate = seedDate ? new Date(seedDate) : new Date();
  const now = new Date().toISOString();

  const orgRef = db.collection('organizations').doc(orgId);

  console.log('INFO: Clearing existing inventory...');
  await clearInventory(orgId);
  console.log('INFO: Inventory cleared.');

  // Create sites (community tier: 1 nursery + 1 outplant)
  console.log('INFO: Creating sites...');
  const sites = await createSites(
    orgId,
    userId,
    now,
    orgUrlPrefix,
    {
      includeMonitoringSites: false,
      nurserySiteKeys: ['nurseryLand'],
      includeGeneBank: false,
    },
  );
  console.log(`INFO: Created ${Object.keys(sites).length} sites.`);

  // Create genets
  console.log('INFO: Creating genets...');
  const genets = await createGenets(orgId, userId, rng, baseDate, now, orgUrlPrefix);
  console.log(`INFO: Created ${genets.length} genets.`);

  // Create groups and organisms
  console.log('INFO: Creating groups and organisms...');
  const {
    groupCount,
    organismCount,
    organisms,
    organismsBySiteKey,
    groupsBySiteKey,
  } = await createGroupsAndOrganisms(
    orgId, userId, sites, genets, rng, baseDate, now
  );
  console.log(`INFO: Created ${groupCount} groups and ${organismCount} organisms.`);

  console.log('INFO: Creating organism history events...');
  const organismEventCount = await createOrganismHistoryEvents(
    orgId,
    userId,
    organisms,
    rng,
    baseDate,
    now,
  );
  console.log(`INFO: Created ${organismEventCount} organism history events.`);

  // Create events (outplant events only for community tier)
  console.log('INFO: Creating events...');
  const { eventCount, events } = await createEvents(
    orgId,
    userId,
    sites,
    organismsBySiteKey,
    groupsBySiteKey,
    rng,
    baseDate,
    now,
    {},
    {
      includeTasks: false,
      includeHusbandry: false,
    },
  );
  console.log(`INFO: Created ${eventCount} events.`);

  console.log('INFO: Coral inventory seeding complete.');
}

async function clearInventory(orgId) {
  const orgRef = db.collection('organizations').doc(orgId);
  const batchSize = 500;

  // Delete organism records
  let deleted = 0;
  while (true) {
    const snap = await orgRef.collection('organismRecords').limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} organism records.`);

  // Delete groups
  deleted = 0;
  while (true) {
    const snap = await orgRef.collection('groups').limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} groups.`);

  // Delete genets
  deleted = 0;
  while (true) {
    const snap = await orgRef.collection('genets').limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} genets.`);

  // Delete sites
  deleted = 0;
  while (true) {
    const snap = await db.collection('sites').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} sites.`);

  // Delete events
  deleted = 0;
  while (true) {
    const snap = await db.collection('events').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} events.`);

  // Delete deliverables
  deleted = 0;
  while (true) {
    const snap = await db.collection('deliverables').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} deliverables.`);

  // Delete permits
  deleted = 0;
  while (true) {
    const snap = await db.collection('permits').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} permits.`);

  // Delete funders
  deleted = 0;
  while (true) {
    const snap = await db.collection('funders').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} funders.`);

  // Delete ecological surveys (org subcollection)
  deleted = 0;
  while (true) {
    const snap = await orgRef.collection('ecological_surveys').limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} ecological surveys.`);

  // Delete snapshots
  deleted = 0;
  while (true) {
    const snap = await db.collection('snapshots').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} snapshots.`);

  // Delete comments
  deleted = 0;
  while (true) {
    const snap = await orgRef.collection('comments').limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} comments.`);

  // Delete chat messages
  deleted = 0;
  while (true) {
    const snap = await orgRef.collection('chat_messages').limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} chat messages.`);

  // Delete chat rooms
  deleted = 0;
  while (true) {
    const snap = await orgRef.collection('chat_rooms').limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} chat rooms.`);

  // Delete missions
  deleted = 0;
  while (true) {
    const snap = await db.collection('missions').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} missions.`);

  // Delete vessels
  deleted = 0;
  while (true) {
    const snap = await db.collection('vessels').where('organizationId', '==', orgId).limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.docs.length;
  }
  if (deleted > 0) console.log(`  Deleted ${deleted} vessels.`);
}

async function createSites(
  orgId,
  userId,
  now,
  orgUrlPrefix,
  {
    includeMonitoringSites = true,
    nurserySiteKeys = null,
    includeGeneBank = true,
  } = {},
) {
  const sites = {};
  const basePath = normalizeUrlPrefix(orgUrlPrefix || orgId);
  const nurseryKeySet =
    Array.isArray(nurserySiteKeys) && nurserySiteKeys.length > 0
      ? new Set(nurserySiteKeys)
      : null;
  const siteData = [
    { key: 'nurseryLand', name: 'Land Based Nursery', typeId: SITE_TYPES.nurseryExSitu, lat: 25.7617, lng: -80.1918, groupIdHierarchy: [GROUP_TYPES.tank, GROUP_TYPES.tray] },
    { key: 'nurseryField', name: 'In-Water Nursery', typeId: SITE_TYPES.nurseryInSitu, lat: 25.0343, lng: -80.4115, groupIdHierarchy: [GROUP_TYPES.tree, GROUP_TYPES.treeBranch] },
    ...(includeGeneBank
      ? [
        { key: 'geneBank', name: 'Gene Bank', typeId: SITE_TYPES.geneBank, lat: 25.7489, lng: -80.2564, groupIdHierarchy: [GROUP_TYPES.tank, GROUP_TYPES.tray] },
      ]
      : []),
    { key: 'outplant', name: 'Coral Reef Outplant Site', typeId: SITE_TYPES.outplantSite, lat: 25.0865, lng: -80.3728, groupIdHierarchy: [GROUP_TYPES.grid, GROUP_TYPES.gridCell] },
    ...(includeMonitoringSites
      ? [
        { key: 'outplant2', name: 'Secondary Outplant Site', typeId: SITE_TYPES.outplantSite, lat: 25.1012, lng: -80.3825, groupIdHierarchy: [GROUP_TYPES.grid, GROUP_TYPES.gridCell] },
      ]
      : []),
    ...(includeMonitoringSites
      ? [
        {
          key: 'baseline',
          name: 'Baseline Reef Site',
          typeId: SITE_TYPES.baselineSite,
          lat: 25.0911,
          lng: -80.3881,
          groupIdHierarchy: [GROUP_TYPES.grid, GROUP_TYPES.tag],
        },
        {
          key: 'reference',
          name: 'Reference Reef Site',
          typeId: SITE_TYPES.referenceSite,
          lat: 25.0782,
          lng: -80.3564,
          groupIdHierarchy: [GROUP_TYPES.grid, GROUP_TYPES.tag],
        },
      ]
      : []),
  ].filter((site) => {
    if (!nurseryKeySet) return true;
    if (site.key === 'nurseryLand' || site.key === 'nurseryField') {
      return nurseryKeySet.has(site.key);
    }
    return true;
  });

  for (const s of siteData) {
    const siteId = db.collection('sites').doc().id;
    const slug = s.name.toLowerCase().replace(/\s+/g, '-');
    const site = {
      id: siteId,
      name: s.name,
      siteTypeId: s.typeId,
      groupIdHierarchy: s.groupIdHierarchy || [],
      latitude: s.lat,
      longitude: s.lng,
      organizationId: orgId,
      modelType: 'site',
      slug,
      urlPath: `${basePath}/${slug}`,
      internalPath: `sites/${siteId}`,
      createdAt: now,
      updatedAt: now,
      createdById: userId,
      updatedById: userId,
    };
    await db.collection('sites').doc(siteId).set(site);
    sites[s.key] = { ...site, key: s.key };
  }

  return sites;
}

async function createGenets(orgId, userId, rng, baseDate, now, orgUrlPrefix) {
  const genets = [];
  const orgRef = db.collection('organizations').doc(orgId);
  const basePath = normalizeUrlPrefix(orgUrlPrefix || orgId);

  // Track crosswalk assignment index per species
  const crosswalkIndex = {};

  // Main species with multiple genets
  const mainSpecies = [SPECIES.apal, SPECIES.acer];

  for (const sp of mainSpecies) {
    crosswalkIndex[sp.code] = 0;

    // Create founder genets (generation 0)
    const founderCount = 8 + Math.floor(rng() * 5); // 8-12 founders
    for (let i = 0; i < founderCount; i++) {
      const genet = await createGenet(orgRef, orgId, userId, basePath, sp, {
        generation: 0,
        index: i,
        provenanceType: PROVENANCE_TYPES.wild,
        crosswalkIndex,
        rng,
        baseDate,
        now,
      });
      genets.push(genet);
    }

    // Create F1 generation (children of founders)
    const f1Count = 12 + Math.floor(rng() * 8); // 12-19 F1
    for (let i = 0; i < f1Count; i++) {
      const parentGenet = pickRandom(
        genets.filter((g) => g.speciesId === sp.id && g.generation === 0),
        rng,
      );
      const genet = await createGenet(orgRef, orgId, userId, basePath, sp, {
        generation: 1,
        index: i,
        provenanceType: PROVENANCE_TYPES.wild,
        parentGenetId: parentGenet?.id,
        parentProvenanceId: parentGenet?.provenanceId,
        crosswalkIndex,
        rng,
        baseDate,
        now,
      });
      genets.push(genet);
    }

    // Create F2 generation (grandchildren)
    const f2Count = 8 + Math.floor(rng() * 6); // 8-13 F2
    for (let i = 0; i < f2Count; i++) {
      const parentGenet = pickRandom(
        genets.filter((g) => g.speciesId === sp.id && g.generation === 1),
        rng,
      );
      const genet = await createGenet(orgRef, orgId, userId, basePath, sp, {
        generation: 2,
        index: i,
        provenanceType: PROVENANCE_TYPES.wild,
        parentGenetId: parentGenet?.id,
        parentProvenanceId: parentGenet?.provenanceId,
        crosswalkIndex,
        rng,
        baseDate,
        now,
      });
      genets.push(genet);
    }
  }

  // Additional species with fewer genets (no crosswalk data)
  const extraSpecies = [SPECIES.past, SPECIES.pstr, SPECIES.cnat, SPECIES.mcav, SPECIES.ofav];
  for (const sp of extraSpecies) {
    const count = 3 + Math.floor(rng() * 4); // 3-6 genets
    for (let i = 0; i < count; i++) {
      const genet = await createGenet(orgRef, orgId, userId, basePath, sp, {
        generation: 0,
        index: i,
        provenanceType: PROVENANCE_TYPES.wild,
        crosswalkIndex: null,
        rng,
        baseDate,
        now,
      });
      genets.push(genet);
    }
  }

  return genets;
}

async function createGenet(orgRef, orgId, userId, orgUrlPrefix, species, options) {
  const {
    generation,
    index,
    provenanceType,
    parentGenetId,
    parentProvenanceId,
    crosswalkIndex,
    rng,
    baseDate,
    now,
  } = options;

  const genetId = orgRef.collection('genets').doc().id;
  const genSuffix = generation > 0 ? `-F${generation}` : '';
  const localId = `${species.code}-${(index + 1).toString().padStart(3, '0')}${genSuffix}`;
  const slug = localId.toLowerCase();

  const collectionDate = new Date(baseDate);
  collectionDate.setDate(collectionDate.getDate() - Math.floor(rng() * 365 * 3));

  // Generate readyForOutplant (30% chance for founders)
  const readyForOutplant = generation === 0 && rng() < 0.3;

  // Generate crossDate for F1 and F2 (they came from crosses)
  let crossDate = null;
  if (generation > 0) {
    const crossDateObj = new Date(baseDate);
    crossDateObj.setDate(crossDateObj.getDate() - Math.floor(rng() * 180 + 30)); // 30-210 days ago
    crossDate = crossDateObj.toISOString();
  }

  // Determine if this genet gets crosswalk data (50% of ACER/APAL genets)
  const crosswalkEntries = CROSSWALK_DATA[species.code] || [];
  const cwIdx = crosswalkIndex ? (crosswalkIndex[species.code] || 0) : 0;
  const totalGenetIndex = cwIdx; // Track absolute genet index for this species
  const useCrosswalk = crosswalkEntries.length > 0 && totalGenetIndex % 2 === 0;

  let provenanceId, clonalId, accessionNumber, aliases;

  if (useCrosswalk) {
    const entry = crosswalkEntries[Math.floor(cwIdx / 2) % crosswalkEntries.length];
    provenanceId = entry.provenanceId;
    clonalId = entry.masterClonalId;
    accessionNumber = entry.accessionNumber;
    // Build aliases as array of maps (matches OrganismAlias.fromJson format)
    aliases = (entry.aliases || [])
      .filter((a) => a.id)
      .map((a) => ({
        sourceSystem: a.org || 'unknown',
        value: a.id,
      }));
    console.log(`  [crosswalk] ${species.code} gen${generation} #${index}: PID=${provenanceId}, clonalId=${clonalId}, aliases=${aliases.length}`);
  } else {
    // Non-crosswalk genets get synthetic IDs
    provenanceId = `PID-${species.demoCode}-${String(index + 1).padStart(4, '0')}`;
    clonalId = null;
    accessionNumber = null;
    aliases = null;
  }

  // Advance crosswalk counter
  if (crosswalkIndex && species.code in crosswalkIndex) {
    crosswalkIndex[species.code] = cwIdx + 1;
  }

  const genet = {
    id: genetId,
    name: localId,
    nameLowercase: localId.toLowerCase(),
    localId,
    speciesId: species.id,
    provenanceTypeId: provenanceType,
    provenanceKind: 'genet',
    lineageKind: 'genet',
    provenanceId,
    organismKind: 'coral',
    slug,
    organizationId: orgId,
    modelType: 'genet',
    urlPath: `${orgUrlPrefix}/${slug}`,
    internalPath: `organizations/${orgId}/genets/${genetId}`,
    archived: false,
    createdAt: now,
    updatedAt: now,
    createdById: userId,
    updatedById: userId,
    generation,
    readyForOutplant,
    ...(crossDate && { crossDate }),
    ...(clonalId && { clonalId }),
    ...(accessionNumber && { accessionNumber }),
    ...(aliases && aliases.length > 0 && { aliases }),
    provenance: {
      reefOfOrigin: `${species.name} Reef ${index + 1}`,
      collectionDate: formatDate(collectionDate),
      depth: String(5 + Math.floor(rng() * 15)),
      habitatType: rng() > 0.5 ? 'reef_crest' : 'fore_reef',
      collectingInstitution: 'SeaFoundry Research',
    },
  };

  if (parentGenetId) {
    genet.parentGenetIds = [parentGenetId];
  }
  if (parentProvenanceId) {
    genet.parentProvenanceId = parentProvenanceId;
    genet.parentProvenanceIds = [parentProvenanceId];
  }

  await orgRef.collection('genets').doc(genetId).set(genet);
  return genet;
}

async function createGroupsAndOrganisms(orgId, userId, sites, genets, rng, baseDate, now) {
  const orgRef = db.collection('organizations').doc(orgId);
  let groupCount = 0;
  let organismCount = 0;
  const organisms = [];
  const organismsBySiteKey = Object.fromEntries(
    Object.keys(sites).map((key) => [key, []]),
  );
  const groupsBySiteKey = Object.fromEntries(
    Object.keys(sites).map((key) => [key, []]),
  );

  // Create structures and organisms for each site
  const siteConfigs = [
    { key: 'nurseryLand', site: sites.nurseryLand, structureType: GROUP_TYPES.tank, rackType: GROUP_TYPES.tray, structures: 4, racksPerStruct: 6 },
    { key: 'nurseryField', site: sites.nurseryField, structureType: GROUP_TYPES.tree, rackType: GROUP_TYPES.treeBranch, structures: 6, racksPerStruct: 8 },
    { key: 'geneBank', site: sites.geneBank, structureType: GROUP_TYPES.tank, rackType: GROUP_TYPES.tray, structures: 3, racksPerStruct: 4 },
    { key: 'outplant', site: sites.outplant, structureType: GROUP_TYPES.grid, rackType: GROUP_TYPES.gridCell, structures: 4, racksPerStruct: 5 },
    { key: 'outplant2', site: sites.outplant2, structureType: GROUP_TYPES.grid, rackType: GROUP_TYPES.gridCell, structures: 3, racksPerStruct: 4 },
    { key: 'baseline', site: sites.baseline, structureType: GROUP_TYPES.grid, rackType: GROUP_TYPES.tag, structures: 2, racksPerStruct: 4 },
    { key: 'reference', site: sites.reference, structureType: GROUP_TYPES.grid, rackType: GROUP_TYPES.tag, structures: 2, racksPerStruct: 4 },
  ];

  for (const config of siteConfigs) {
    const { site, structureType, rackType, structures, racksPerStruct, key } = config;
    if (!site) {
      continue;
    }

    for (let s = 0; s < structures; s++) {
      // Create structure group
      const structureId = orgRef.collection('groups').doc().id;
      const structureLabel = groupLabel(structureType);
      const structureName = `${structureLabel} ${s + 1}`;
      const structureSlug = `${site.slug}-${slugify(structureLabel)}-${s + 1}`;

      const structure = {
        id: structureId,
        name: structureName,
        groupTypeId: structureType,
        siteId: site.id,
        parentId: site.id,  // Root-level group uses siteId as parentId (matches app behavior)
        organizationId: orgId,
        modelType: 'group',
        slug: structureSlug,
        urlPath: `${site.urlPath}/${structureSlug}`,
        internalPath: `organizations/${orgId}/groups/${structureId}`,
        createdAt: now,
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
      };

      await orgRef.collection('groups').doc(structureId).set(structure);
      groupCount++;

      // Create racks/branches within structure
      for (let r = 0; r < racksPerStruct; r++) {
        const rackId = orgRef.collection('groups').doc().id;
        const rackLabel = groupLabel(rackType);
        const rackName = `${rackLabel} ${r + 1}`;
        const rackSlug = `${structureSlug}-${slugify(rackLabel)}-${r + 1}`;

        const rack = {
          id: rackId,
          name: rackName,
          groupTypeId: rackType,
          siteId: site.id,
          parentId: structureId,  // Parent group ID
          organizationId: orgId,
          modelType: 'group',
          slug: rackSlug,
          urlPath: `${structure.urlPath}/${rackSlug}`,
          internalPath: `organizations/${orgId}/groups/${rackId}`,
          createdAt: now,
          updatedAt: now,
          createdById: userId,
          updatedById: userId,
        };

        await orgRef.collection('groups').doc(rackId).set(rack);
        groupCount++;
        if (groupsBySiteKey[key]) {
          groupsBySiteKey[key].push(rack);
        }

        // Create organisms in this rack
        const organismsPerRack = 3 + Math.floor(rng() * 5); // 3-7 organisms
        for (let o = 0; o < organismsPerRack; o++) {
          const genet = pickRandom(genets, rng);
          const organism = await createOrganism(orgRef, orgId, userId, site, rack, genet, {
            index: o,
            rng,
            baseDate,
            now,
          });
          organisms.push(organism);
          if (organismsBySiteKey[key]) {
            organismsBySiteKey[key].push(organism);
          }
          organismCount++;
        }
      }
    }
  }

  return { groupCount, organismCount, organisms, organismsBySiteKey, groupsBySiteKey };
}

async function createOrganism(orgRef, orgId, userId, site, group, genet, options) {
  const { index, rng, baseDate, now } = options;

  const organismId = orgRef.collection('organismRecords').doc().id;
  const localKey = genet.localId || genet.id || 'unknown';
  const currentCount = (recordNameCounters.get(localKey) || 0) + 1;
  recordNameCounters.set(localKey, currentCount);
  const recordName = deriveRecordName(localKey, currentCount) || localKey;
  const slug = recordName.toLowerCase().replace(/\s+/g, '-');

  // Determine life stage with variety based on site type and randomness
  let lifeStage;
  const lifeStageRoll = rng();
  if (site.siteTypeId === SITE_TYPES.outplantSite) {
    // Outplant sites: mostly juveniles and adults
    if (lifeStageRoll < 0.5) lifeStage = LIFE_STAGES.juvenile;
    else if (lifeStageRoll < 0.85) lifeStage = LIFE_STAGES.adult;
    else lifeStage = LIFE_STAGES.broodstock;
  } else if (
    site.siteTypeId === SITE_TYPES.baselineSite ||
    site.siteTypeId === SITE_TYPES.referenceSite
  ) {
    // Monitoring-only reefs: prioritize adult and broodstock
    if (lifeStageRoll < 0.55) lifeStage = LIFE_STAGES.adult;
    else lifeStage = LIFE_STAGES.broodstock;
  } else if (site.siteTypeId === SITE_TYPES.geneBank) {
    // Gene bank: mostly adults and broodstock
    if (lifeStageRoll < 0.45) lifeStage = LIFE_STAGES.adult;
    else if (lifeStageRoll < 0.8) lifeStage = LIFE_STAGES.broodstock;
    else lifeStage = LIFE_STAGES.juvenile;
  } else if (site.siteTypeId === SITE_TYPES.nurseryExSitu) {
    // Land-based nursery: juvenile and adult mix
    if (lifeStageRoll < 0.6) lifeStage = LIFE_STAGES.juvenile;
    else if (lifeStageRoll < 0.9) lifeStage = LIFE_STAGES.adult;
    else lifeStage = LIFE_STAGES.broodstock;
  } else {
    // In-water nursery: juveniles with some adults
    if (lifeStageRoll < 0.7) lifeStage = LIFE_STAGES.juvenile;
    else if (lifeStageRoll < 0.9) lifeStage = LIFE_STAGES.adult;
    else lifeStage = LIFE_STAGES.broodstock;
  }

  const quantity = site.siteTypeId === SITE_TYPES.nurseryExSitu
    ? 5 + Math.floor(rng() * 20) // 5-24 fragments
    : 1;

  const createdDate = randomDateBetween(
    new Date(baseDate.getTime() - 365 * DAY_MS),
    baseDate,
    rng,
  );

  const healthRoll = rng();
  const healthStatus = healthRoll < 0.7
    ? 'healthy'
    : healthRoll < 0.82
      ? 'stressed'
      : healthRoll < 0.92
        ? 'recovering'
        : healthRoll < 0.97
          ? 'diseased'
          : 'bleached';

  const readyRoll = rng();
  const readyForOutplant = healthStatus === 'healthy' && readyRoll < 0.25;
  const readyForPropagation =
    healthStatus === 'healthy' && readyRoll >= 0.25 && readyRoll < 0.45;

  const physicalForm = resolvePhysicalFormForLifeStage(lifeStage, rng);
  const inventoryMetrics = calculateInventoryMetrics(physicalForm, quantity);

  const organism = {
    id: organismId,
    recordName,
    localId: genet.localId,
    genetId: genet.id,
    foreignKeys: {
      genetId: { id: genet.id, collection: 'genets' },
    },
    speciesId: genet.speciesId,
    siteId: site.id,
    groupId: group.id,
    lifeStage: { id: lifeStage },
    provenanceType: genet.provenanceTypeId,
    organismKind: 'coral',
    organizationId: orgId,
    modelType: 'organismRecord',
    slug,
    urlPath: `${group.urlPath}/${slug}`,
    internalPath: `organizations/${orgId}/organismRecords/${organismId}`,
    createdAt: createdDate.toISOString(),
    updatedAt: now,
    createdById: userId,
    updatedById: userId,
    measurement: {
      value: quantity,
      unit: 'count',
    },
    lifeStageHistory: [{
      fromStage: { id: lifeStage },
      toStage: { id: lifeStage },
      occurredAt: createdDate.toISOString(),
    }],
    measurementHistory: [{
      measurement: { value: quantity, unit: 'count' },
      recordedAt: createdDate.toISOString(),
    }],
    physicalForm,
    physicalFormConfigVersion: 'v1',
    // Inventory metrics fields (inventoryCount, inventoryVolumeCm3, inventoryTissueAreaCm2)
    ...inventoryMetrics,
    metadata: {
      healthStatus,
      readyForOutplant,
      readyForPropagation,
    },
  };

  await orgRef.collection('organismRecords').doc(organismId).set(organism);
  return organism;
}

function buildEventUrlPath(recordUrlPath, slug) {
  if (!recordUrlPath) return slug;
  return `${recordUrlPath}/events/${slug}`;
}

function buildEventBase({
  orgId,
  userId,
  eventId,
  createdAt,
  recordId,
  recordModelType,
  recordUrlPath,
  slug,
}) {
  return {
    id: eventId,
    modelType: 'event',
    organizationId: orgId,
    createdAt,
    updatedAt: createdAt,
    createdById: userId,
    updatedById: userId,
    recordId,
    recordModelType,
    slug,
    urlPath: buildEventUrlPath(recordUrlPath, slug),
    internalPath: `organizations/${orgId}/events/${eventId}`,
  };
}

function buildOrganismSnapshot(organism) {
  return {
    ...organism,
    modelType: 'organismRecord',
  };
}

function buildOrganismSnapshotWithOverrides(organism, overrides = {}) {
  const snapshot = {
    ...organism,
    ...overrides,
    modelType: 'organismRecord',
  };
  if (overrides.metadata || organism.metadata) {
    snapshot.metadata = {
      ...(organism.metadata || {}),
      ...(overrides.metadata || {}),
    };
  }
  if (overrides.measurement || organism.measurement) {
    snapshot.measurement = {
      ...(organism.measurement || {}),
      ...(overrides.measurement || {}),
    };
  }
  return snapshot;
}

async function createOrganismHistoryEvents(orgId, userId, organisms, rng, baseDate, now) {
  if (!organisms.length) return 0;
  const events = [];
  const dayMs = 24 * 60 * 60 * 1000;
  for (let i = 0; i < organisms.length; i++) {
    const organism = organisms[i];
    const eventId = db.collection('events').doc().id;
    const slug = `create-${organism.slug || eventId.slice(0, 6)}`;
    const createdAt = organism.createdAt || now;
    const metadata = organism.metadata || {};
    const seededHealthStatus = metadata.healthStatus || 'healthy';
    events.push({
      eventTypeId: 'event_create',
      ...buildEventBase({
        orgId,
        userId,
        eventId,
        createdAt,
        recordId: organism.id,
        recordModelType: 'organismRecord',
        recordUrlPath: organism.urlPath,
        slug,
      }),
      snapshotData: buildOrganismSnapshot(organism),
    });

    const statusEventId = db.collection('events').doc().id;
    const statusSlug = `status-${organism.slug || statusEventId.slice(0, 6)}`;
    const statusCreatedAt = new Date(new Date(createdAt).getTime() + dayMs).toISOString();
    events.push({
      eventTypeId: 'event_update',
      updateType: 'health_status',
      fieldUpdates: {
        healthStatus: seededHealthStatus,
        readyForOutplant: metadata.readyForOutplant ?? false,
        readyForPropagation: metadata.readyForPropagation ?? false,
      },
      notes: 'Initial health and readiness status recorded at creation.',
      ...buildEventBase({
        orgId,
        userId,
        eventId: statusEventId,
        createdAt: statusCreatedAt,
        recordId: organism.id,
        recordModelType: 'organismRecord',
        recordUrlPath: organism.urlPath,
        slug: statusSlug,
      }),
      snapshotData: buildOrganismSnapshotWithOverrides(organism, {
        metadata: {
          healthStatus: seededHealthStatus,
          readyForOutplant: metadata.readyForOutplant ?? false,
          readyForPropagation: metadata.readyForPropagation ?? false,
        },
      }),
    });

    if (rng() > 0.65 && organism.measurement?.value != null) {
      const gainEventId = db.collection('events').doc().id;
      const gainSlug = `gain-${organism.slug || gainEventId.slice(0, 6)}`;
      const newPopulation = Math.max(1, Math.round(Number(organism.measurement.value)));
      const oldPopulation = Math.max(1, newPopulation - (1 + Math.floor(rng() * 2)));
      const gainCreatedAt = new Date(new Date(createdAt).getTime() + 86400000).toISOString();
      events.push({
        eventTypeId: 'event_population_gain',
        ...buildEventBase({
          orgId,
          userId,
          eventId: gainEventId,
          createdAt: gainCreatedAt,
          recordId: organism.id,
          recordModelType: 'organismRecord',
          recordUrlPath: organism.urlPath,
          slug: gainSlug,
        }),
        snapshotData: buildOrganismSnapshot(organism),
        oldPopulation,
        newPopulation,
        gainReasonId: 'population_gain_reason_fragmentation',
        comment: 'Fragmentation recorded during routine husbandry.',
      });
    }

    if (rng() > 0.55) {
      const updateEventId = db.collection('events').doc().id;
      const updateSlug = `update-${organism.slug || updateEventId.slice(0, 6)}`;
      const updateCreatedAt = new Date(
        new Date(createdAt).getTime() + (2 + Math.floor(rng() * 6)) * dayMs,
      ).toISOString();
      const newHealthStatus = rng() > 0.8 ? 'stressed' : 'healthy';
      events.push({
        eventTypeId: 'event_update',
        updateType: 'health_status',
        fieldUpdates: {
          healthStatus: newHealthStatus,
          readyForOutplant: metadata.readyForOutplant ?? false,
          readyForPropagation: metadata.readyForPropagation ?? false,
        },
        notes: 'Health status updated after routine monitoring.',
        ...buildEventBase({
          orgId,
          userId,
          eventId: updateEventId,
          createdAt: updateCreatedAt,
          recordId: organism.id,
          recordModelType: 'organismRecord',
          recordUrlPath: organism.urlPath,
          slug: updateSlug,
        }),
        snapshotData: buildOrganismSnapshotWithOverrides(organism, {
          metadata: {
            healthStatus: newHealthStatus,
            readyForOutplant: metadata.readyForOutplant ?? false,
            readyForPropagation: metadata.readyForPropagation ?? false,
          },
        }),
      });
    }

    if (rng() > 0.7 && organism.measurement?.value != null) {
      const lossEventId = db.collection('events').doc().id;
      const lossSlug = `loss-${organism.slug || lossEventId.slice(0, 6)}`;
      const lossCreatedAt = new Date(
        new Date(createdAt).getTime() + (6 + Math.floor(rng() * 10)) * dayMs,
      ).toISOString();
      const oldPopulation = Math.max(
        1,
        Math.round(Number(organism.measurement.value)),
      );
      const newPopulation = Math.max(0, oldPopulation - 1);
      events.push({
        eventTypeId: 'event_population_loss',
        ...buildEventBase({
          orgId,
          userId,
          eventId: lossEventId,
          createdAt: lossCreatedAt,
          recordId: organism.id,
          recordModelType: 'organismRecord',
          recordUrlPath: organism.urlPath,
          slug: lossSlug,
        }),
        snapshotData: buildOrganismSnapshotWithOverrides(organism, {
          measurement: {
            value: newPopulation,
          },
          metadata: {
            healthStatus: 'stressed',
            readyForOutplant: metadata.readyForOutplant ?? false,
            readyForPropagation: metadata.readyForPropagation ?? false,
          },
        }),
        oldPopulation,
        newPopulation,
        lossReasonId: 'population_loss_reason_mortality',
        comment: 'Observed mortality during monitoring.',
      });
    }
  }

  const batchSize = 400;
  let created = 0;
  for (let i = 0; i < events.length; i += batchSize) {
    const batch = db.batch();
    events.slice(i, i + batchSize).forEach((event) => {
      batch.set(db.collection('events').doc(event.id), event);
    });
    await batch.commit();
    created += Math.min(batchSize, events.length - i);
  }
  return created;
}

async function createEvents(
  orgId,
  userId,
  sites,
  organismsBySiteKey,
  groupsBySiteKey,
  rng,
  baseDate,
  now,
  linkedData = {},
  {
    includeTasks = true,
    includeHusbandry = true,
  } = {},
) {
  let eventCount = 0;
  const events = [];

  // Create outplant events
  const outplantSite = sites.outplant;
  const outplantGroups = groupsBySiteKey.outplant || [];
  const sourceOrganisms = [
    ...(organismsBySiteKey.nurseryLand || []),
    ...(organismsBySiteKey.nurseryField || []),
    ...(organismsBySiteKey.geneBank || []),
  ];
  const deliverables = linkedData.deliverables || [];
  const permits = linkedData.permits || [];
  const funders = linkedData.funders || [];
  const outplantPermit = permits[0] || null;
  const outplantDeliverable =
    deliverables.find((d) => d.permitId === outplantPermit?.id) ||
    deliverables[0] ||
    null;
  const permitMetadata = outplantPermit
    ? {
      permitId: outplantPermit.id,
      permitType: outplantPermit.typeId,
      issuingAuthority: outplantPermit.issuingAuthority,
      validFrom: outplantPermit.validFrom,
      validTo: outplantPermit.validTo,
      attachmentUrls: outplantPermit.attachmentUrls || [],
    }
    : null;
  for (let i = 0; i < 12; i++) {
    const eventId = db.collection('events').doc().id;
    const slug = `outplant-${i + 1}`;
    const eventDate = seasonalDate({
      anchorDate: baseDate,
      rng,
      allowedMonths: OUTPLANT_MONTHS,
    });
    const allocations = [];
    const allocationCount = 3 + Math.floor(rng() * 4);
    for (let a = 0; a < allocationCount; a++) {
      const organism = pickRandom(sourceOrganisms, rng);
      if (!organism) continue;
      const groupTarget = outplantGroups.length ? pickRandom(outplantGroups, rng) : null;
      const quantity = Math.max(1, Math.min(3, Math.round(rng() * 3)));
      allocations.push({
        organismId: organism.id,
        recordName: organism.recordName || organism.localId || 'Record',
        speciesId: organism.speciesId || '',
        genetId: organism.genetId || null,
        tagId: null,
        tagName: groupTarget?.name,
        tagPath: groupTarget?.urlPath,
        groupId: groupTarget?.id,
        groupName: groupTarget?.name,
        groupPath: groupTarget?.urlPath,
        quantity,
        sourcePath: organism.urlPath || '',
        snapshot: buildOrganismSnapshot(organism),
      });
    }

    // Generate realistic percentCover values for outplant events
    // Earlier events have lower cover (new outplants), later events have higher cover
    const coverProgress = (i + 1) / 12; // Progress through events (0.08 to 1.0)
    const basePercentCover = 40 + coverProgress * 40; // 40-80% base
    const percentCover = Math.min(95, Math.round(basePercentCover + (rng() * 15 - 7.5)));
    const percentBleaching = Math.round(rng() * 8);
    const percentDisease = Math.round(rng() * 5);
    const healthStatus = percentBleaching > 5 ? 'stressed' : (rng() > 0.9 ? 'stressed' : 'healthy');

    const event = {
      eventTypeId: 'outplant_event',
      name: `Outplant Event ${i + 1}`,
      comment: `Outplanted fragments to ${outplantSite.name}.`,
      siteId: outplantSite.id,
      allocations,
      percentCover,
      percentBleaching,
      percentDisease,
      healthStatus,
      ...(outplantDeliverable?.id ? { deliverableId: outplantDeliverable.id } : {}),
      ...(permitMetadata ? { permitMetadata } : {}),
      metadata: {
        fragmentCount: allocations.reduce((sum, a) => sum + a.quantity, 0),
        genetCount: new Set(allocations.map((a) => a.genetId).filter(Boolean)).size,
        organismKind: 'coral',
      },
      ...buildEventBase({
        orgId,
        userId,
        eventId,
        createdAt: eventDate.toISOString(),
        recordId: outplantSite.id,
        recordModelType: 'site',
        recordUrlPath: outplantSite.urlPath,
        slug,
      }),
    };

    await db.collection('events').doc(eventId).set(event);
    events.push(event);
    eventCount++;
  }

  const inSituSiteTypes = new Set([
    SITE_TYPES.nurseryInSitu,
    SITE_TYPES.outplantSite,
    SITE_TYPES.baselineSite,
    SITE_TYPES.referenceSite,
  ]);
  const exSituSiteTypes = new Set([
    SITE_TYPES.nurseryExSitu,
    SITE_TYPES.geneBank,
  ]);

  const isInSituSite = (site) => inSituSiteTypes.has(site.siteTypeId);

  // Task templates with categories for varied tasks
  const taskTemplatesShared = [
    // Monitoring tasks
    { title: 'Growth measurement', category: 'monitoring', description: 'Measure and document coral growth rates' },
    { title: 'Photo documentation', category: 'monitoring', description: 'Take progress photos of coral specimens' },
    { title: 'Bleaching assessment', category: 'monitoring', description: 'Check for signs of coral bleaching or stress' },
    // Health tasks
    { title: 'Fragment health check', category: 'health', description: 'Assess health status of all fragments' },
    { title: 'Disease inspection', category: 'health', description: 'Look for signs of disease, tissue loss, or pests' },
    { title: 'Algae removal', category: 'health', description: 'Remove algae growth from corals and structures' },
    { title: 'Pest treatment', category: 'health', description: 'Treat for flatworms, nudibranchs, or other pests' },
    // Administrative tasks
    { title: 'Inventory update', category: 'admin', description: 'Update inventory records and counts' },
    { title: 'Data entry', category: 'admin', description: 'Enter observation data into system' },
    { title: 'Report generation', category: 'admin', description: 'Generate weekly/monthly reports' },
    { title: 'Supply check', category: 'admin', description: 'Check and reorder supplies as needed' },
    // Propagation tasks
    { title: 'Fragmentation', category: 'propagation', description: 'Fragment corals for propagation' },
    { title: 'Coral mounting', category: 'propagation', description: 'Mount fragments to new plugs or structures' },
    { title: 'Fragment relocation', category: 'propagation', description: 'Move fragments to appropriate grow-out locations' },
  ];

  const taskTemplatesExSitu = [
    // Routine maintenance tasks (ex-situ equipment)
    { title: 'Weekly tank cleaning', category: 'maintenance', description: 'Clean tank walls, remove debris, check filters' },
    { title: 'Filter maintenance', category: 'maintenance', description: 'Replace/clean filter media, check flow rates' },
    { title: 'Equipment inspection', category: 'maintenance', description: 'Check pumps, heaters, lights, and other equipment' },
    { title: 'Plumbing check', category: 'maintenance', description: 'Inspect all plumbing connections for leaks or buildup' },
    // Monitoring tasks
    { title: 'Water quality testing', category: 'monitoring', description: 'Test pH, salinity, temperature, alkalinity, calcium, magnesium' },
    { title: 'Temperature logging', category: 'monitoring', description: 'Record temperature readings across all systems' },
    // Husbandry tasks
    { title: 'Feeding schedule', category: 'husbandry', description: 'Feed corals according to schedule' },
    { title: 'Water change', category: 'husbandry', description: 'Perform scheduled water change' },
    { title: 'Supplement dosing', category: 'husbandry', description: 'Dose calcium, alkalinity, and trace elements' },
    { title: 'Light adjustment', category: 'husbandry', description: 'Adjust lighting schedule or intensity' },
    { title: 'Flow optimization', category: 'husbandry', description: 'Adjust water flow for optimal conditions' },
  ];

  const taskTemplatesInSitu = [
    { title: 'Mooring inspection', category: 'maintenance', description: 'Inspect anchors, lines, and attachment points for wear' },
    { title: 'Frame cleaning', category: 'maintenance', description: 'Clear biofouling from nursery structures and frames' },
    { title: 'Buoy check', category: 'maintenance', description: 'Inspect floats and replace damaged buoys' },
    { title: 'Dive safety check', category: 'operations', description: 'Review dive plan, tides, and safety equipment before fieldwork' },
    { title: 'Current & visibility log', category: 'monitoring', description: 'Record current speed, visibility, and surface conditions' },
  ];

  const taskTemplatesForSite = (site) => {
    const base = [...taskTemplatesShared];
    if (isInSituSite(site)) {
      return base.concat(taskTemplatesInSitu);
    }
    if (exSituSiteTypes.has(site.siteTypeId)) {
      return base.concat(taskTemplatesExSitu);
    }
    return base;
  };

  // Status distribution: 45% completed, 30% in_progress, 25% not_started
  // Only statuses supported by the Dart TaskStatus enum
  const statusDistribution = [
    { status: 'completed', weight: 0.45 },
    { status: 'in_progress', weight: 0.75 },
    { status: 'not_started', weight: 1.0 },
  ];

  function getTaskStatus(roll) {
    for (const s of statusDistribution) {
      if (roll < s.weight) return s.status;
    }
    return 'not_started';
  }

  // Create 30 varied tasks
  const sitesList = Object.values(sites);
  if (includeTasks) {
    for (let i = 0; i < 30; i++) {
      const eventId = db.collection('events').doc().id;
      const eventDate = new Date(baseDate);
      eventDate.setDate(eventDate.getDate() - Math.floor(rng() * 60));

      const site = pickRandom(sitesList, rng);
      const templatePool = taskTemplatesForSite(site);
      const template = pickRandom(
        templatePool.length ? templatePool : taskTemplatesShared,
        rng,
      );
      const statusRoll = rng();
      const statusId = getTaskStatus(statusRoll);

      // Completed tasks have a completion date
      let completedAt = null;
      if (statusId === 'completed') {
        const completionDate = new Date(eventDate);
        completionDate.setDate(completionDate.getDate() + Math.floor(rng() * 7) + 1);
        completedAt = completionDate.toISOString();
      }

      // Due dates: some overdue, some upcoming
      const dueDate = new Date(baseDate);
      if (statusId === 'completed') {
        dueDate.setDate(dueDate.getDate() - Math.floor(rng() * 30)); // Past due dates for completed
      } else if (statusId === 'not_started' && rng() > 0.5) {
        dueDate.setDate(dueDate.getDate() - Math.floor(rng() * 14)); // Some overdue
      } else {
        dueDate.setDate(dueDate.getDate() + Math.floor(rng() * 14)); // Upcoming
      }

      const event = {
        eventTypeId: 'event_task',
        title: template.title,
        description: `${template.description} at ${site.name}`,
        statusId,
        priorityId: rng() > 0.7 ? 'high' : (rng() > 0.4 ? 'medium' : 'low'),
        category: template.category,
        dueDate: dueDate.toISOString(),
        assignedUserId: userId,
        ...buildEventBase({
          orgId,
          userId,
          eventId,
          createdAt: eventDate.toISOString(),
          recordId: site.id,
          recordModelType: 'site',
          recordUrlPath: site.urlPath,
          slug: `task-${i + 1}`,
        }),
      };

      if (completedAt) {
        event.completedAt = completedAt;
        event.completedById = userId;
      }

      await db.collection('events').doc(eventId).set(event);
      events.push(event);
      eventCount++;
    }
  }

  // Create husbandry log events
  const husbandryNotesShared = [
    'Observed healthy polyp extension across all fragments. Good response noted.',
    'Applied algae treatment to affected areas. Will monitor for improvement.',
    'Documented new growth on several fragments. ACER-003 showing exceptional TLE.',
    'Performed weekly health assessment - all corals stable. No signs of RTN or STN.',
    'Noticed slight bleaching on two APAL fragments. Monitoring closely.',
    'Fragged 12 new pieces from ACER-007 broodstock. Mounted on new ceramic plugs.',
    'Observed spawning behavior in the nursery. Documenting for research records.',
  ];

  const husbandryNotesExSitu = [
    'Completed routine water change and parameter check. All readings within normal range.',
    'Adjusted flow rates for optimal growth conditions. Moved some corals to higher flow zones.',
    'Water parameters: pH 8.2, Alk 9.5, Ca 420, Mg 1350. All within target range.',
    'Pest dip completed on new arrivals. Quarantine period started.',
    'Temperature spike detected overnight. Chiller maintenance scheduled.',
    'Feeding broadcast today - mixture of reef roids and coral frenzy.',
    'New LED schedule implemented. Ramping up 10% over next week.',
    'Monthly deep clean completed. All equipment functioning properly.',
  ];

  const husbandryNotesInSitu = [
    'Diver inspection completed. Nursery structures stable after last swell.',
    'Cleared biofouling from in-water frames and resecured loose ties.',
    'Checked mooring lines and anchors; re-tensioned two lines.',
    'Logged visibility and current conditions during site visit.',
    'Reattached loose fragments to nursery trees. No additional losses noted.',
    'Storm prep underway - secured gear and verified tag integrity.',
  ];

  const husbandryNotesForSite = (site) =>
    isInSituSite(site)
      ? [...husbandryNotesShared, ...husbandryNotesInSitu]
      : [...husbandryNotesShared, ...husbandryNotesExSitu];

  if (includeHusbandry) {
    for (let i = 0; i < 15; i++) {
      const eventId = db.collection('events').doc().id;
      const eventDate = new Date(baseDate);
      eventDate.setDate(eventDate.getDate() - Math.floor(rng() * 90));

      const site = pickRandom(sitesList, rng);
      const notePool = husbandryNotesForSite(site);

      const event = {
        eventTypeId: 'event_husbandry_log',
        comment: pickRandom(notePool, rng),
        metadata: {
          organismKind: 'coral',
        },
        ...buildEventBase({
          orgId,
          userId,
          eventId,
          createdAt: eventDate.toISOString(),
          recordId: site.id,
          recordModelType: 'site',
          recordUrlPath: site.urlPath,
          slug: `husbandry-${i + 1}`,
        }),
      };

      await db.collection('events').doc(eventId).set(event);
      events.push(event);
      eventCount++;
    }
  }

  // Create organism observation events for husbandry health analytics
  if (includeHusbandry && sourceOrganisms.length > 0) {
    const observationCount = 20;
    const healthStatuses = ['healthy', 'stressed', 'recovering', 'diseased', 'bleached'];
    const issueTypes = [
      { eventType: 'event_disease_observation', issueLabel: 'Disease' },
      { eventType: 'event_biofouling_observation', issueLabel: 'Biofouling' },
      { eventType: 'event_thermal_stress_observation', issueLabel: 'Thermal Stress' },
      { eventType: 'event_discoloration_observation', issueLabel: 'Discoloration' },
    ];

    for (let i = 0; i < observationCount; i++) {
      const eventId = db.collection('events').doc().id;
      const eventDate = new Date(baseDate);
      eventDate.setDate(eventDate.getDate() - Math.floor(rng() * 45));

      const targetOrganism = pickRandom(sourceOrganisms, rng);
      if (!targetOrganism) continue;

      const site = sites.nurseryLand || sites.nurseryField;
      if (!site) continue;

      // 60% general observations with health status changes, 40% issue observations
      const isIssueObservation = rng() < 0.4;

      if (isIssueObservation) {
        // Create issue-type observation (disease, biofouling, etc.)
        const issueType = pickRandom(issueTypes, rng);
        const event = {
          eventTypeId: issueType.eventType,
          siteId: site.id,
          siteName: site.name,
          organismId: targetOrganism.id,
          organismName: targetOrganism.recordName || targetOrganism.localId,
          speciesId: targetOrganism.speciesId,
          genetId: targetOrganism.genetId || null,
          notes: `${issueType.issueLabel} observation recorded during routine inspection.`,
          severity: rng() < 0.3 ? 'high' : (rng() < 0.6 ? 'medium' : 'low'),
          metadata: {
            organismKind: 'coral',
            issueType: issueType.issueLabel.toLowerCase(),
          },
          ...buildEventBase({
            orgId,
            userId,
            eventId,
            createdAt: eventDate.toISOString(),
            recordId: targetOrganism.id,
            recordModelType: 'organismRecord',
            recordUrlPath: targetOrganism.urlPath,
            slug: `observation-issue-${i + 1}`,
          }),
        };

        await db.collection('events').doc(eventId).set(event);
        events.push(event);
        eventCount++;
      } else {
        // Create general observation with health status change
        const oldHealthStatus = pickRandom(healthStatuses, rng);
        const newHealthStatus = pickRandom(healthStatuses.filter((s) => s !== oldHealthStatus), rng);

        const event = {
          eventTypeId: 'event_observation',
          siteId: site.id,
          siteName: site.name,
          organismId: targetOrganism.id,
          organismName: targetOrganism.recordName || targetOrganism.localId,
          speciesId: targetOrganism.speciesId,
          genetId: targetOrganism.genetId || null,
          oldHealthStatus,
          newHealthStatus,
          healthStatus: newHealthStatus,
          notes: `Health status changed from ${oldHealthStatus} to ${newHealthStatus}.`,
          metadata: {
            organismKind: 'coral',
            isHealthStatusChange: true,
          },
          ...buildEventBase({
            orgId,
            userId,
            eventId,
            createdAt: eventDate.toISOString(),
            recordId: targetOrganism.id,
            recordModelType: 'organismRecord',
            recordUrlPath: targetOrganism.urlPath,
            slug: `observation-health-${i + 1}`,
          }),
        };

        await db.collection('events').doc(eventId).set(event);
        events.push(event);
        eventCount++;
      }
    }
  }

  // Create maintenance required observation events for husbandry analytics
  if (includeHusbandry) {
    const maintenanceTypes = [
      { id: 'cleaning_required', label: 'Cleaning Required' },
      { id: 'equipment_repair', label: 'Equipment Repair' },
      { id: 'water_quality', label: 'Water Quality Issue' },
      { id: 'structural_damage', label: 'Structural Damage' },
    ];
    const sitesList = Object.values(sites).filter(Boolean);

    for (let i = 0; i < 10; i++) {
      const eventId = db.collection('events').doc().id;
      const eventDate = new Date(baseDate);
      eventDate.setDate(eventDate.getDate() - Math.floor(rng() * 30));

      const site = pickRandom(sitesList, rng);
      if (!site) continue;

      const maintenanceType = pickRandom(maintenanceTypes, rng);
      const isCompleted = rng() < 0.4; // 40% are already completed

      const event = {
        eventTypeId: 'event_maintenance_required_observation',
        siteId: site.id,
        siteName: site.name,
        maintenanceTypeId: maintenanceType.id,
        maintenanceTypeName: maintenanceType.label,
        completed: isCompleted,
        priority: rng() < 0.3 ? 'high' : (rng() < 0.6 ? 'medium' : 'low'),
        notes: `${maintenanceType.label} flagged during site inspection.`,
        ...(isCompleted && {
          completedAt: new Date(new Date(eventDate).getTime() + 86400000 * (1 + Math.floor(rng() * 3))).toISOString(),
          completedById: userId,
        }),
        metadata: {
          maintenanceType: maintenanceType.id,
        },
        ...buildEventBase({
          orgId,
          userId,
          eventId,
          createdAt: eventDate.toISOString(),
          recordId: site.id,
          recordModelType: 'site',
          recordUrlPath: site.urlPath,
          slug: `maintenance-${i + 1}`,
        }),
      };

      await db.collection('events').doc(eventId).set(event);
      events.push(event);
      eventCount++;
    }
  }

  // Create propagation events (fragmentation)
  if (includeHusbandry && sourceOrganisms.length > 0) {
    const propagationCount = 8;
    for (let i = 0; i < propagationCount; i++) {
      const eventId = db.collection('events').doc().id;
      const eventDate = new Date(baseDate);
      eventDate.setDate(eventDate.getDate() - Math.floor(rng() * 60));

      const sourceOrganism = pickRandom(sourceOrganisms, rng);
      if (!sourceOrganism) continue;

      const site = sites.nurseryLand || sites.nurseryField;
      if (!site) continue;

      const inputQuantity = 1 + Math.floor(rng() * 3); // 1-3 input fragments
      const fragmentsPerInput = 3 + Math.floor(rng() * 5); // 3-7 fragments per input
      const outputQuantity = inputQuantity * fragmentsPerInput;

      const event = {
        eventTypeId: 'event_propagation',
        propagationType: 'asexual',
        propagationMethodId: 'fragmentation',
        inputOrganismId: sourceOrganism.id,
        inputOrganismName: sourceOrganism.recordName || sourceOrganism.localId,
        inputQuantity,
        outputQuantity,
        fragmentsPerInput,
        siteId: site.id,
        siteName: site.name,
        speciesId: sourceOrganism.speciesId,
        genetId: sourceOrganism.genetId || null,
        notes: `Fragmented ${inputQuantity} ${sourceOrganism.recordName || 'colony'} into ${outputQuantity} fragments.`,
        metadata: {
          speciesId: sourceOrganism.speciesId,
          genetId: sourceOrganism.genetId,
          fragmentsPerInput,
          organismKind: 'coral',
        },
        ...buildEventBase({
          orgId,
          userId,
          eventId,
          createdAt: eventDate.toISOString(),
          recordId: sourceOrganism.id,
          recordModelType: 'organismRecord',
          recordUrlPath: sourceOrganism.urlPath,
          slug: `propagation-${i + 1}`,
        }),
      };

      await db.collection('events').doc(eventId).set(event);
      events.push(event);
      eventCount++;
    }
  }

  return { eventCount, events };
}

async function main() {
  const orgId = argValue('--org');
  const userId = argValue('--user');
  const seed = argValue('--seed');
  const seedDate = argValue('--seed-date') || argValue('--seed_date');

  if (!orgId || !userId) {
    console.error('Usage: node scripts/seed-coral-inventory.js --org=ORG_ID --user=USER_ID [--seed=N] [--seed-date=YYYY-MM-DD]');
    process.exit(1);
  }

  console.log(`INFO: Starting coral inventory seeding for org ${orgId}...`);

  try {
    const resolvedUser = await ensureUserAndMembership({ orgId, userId });
    await seedInventory({
      orgId,
      userId: resolvedUser.userId,
      seed,
      seedDate,
      orgUrlPrefix: resolvedUser.orgUrlPrefix,
    });
    console.log('SEEDING_COMPLETE');
  } catch (error) {
    console.error('ERROR: Coral inventory seeding failed:', error.message || error);
    process.exit(1);
  }
}

main().then(() => process.exit(0));
