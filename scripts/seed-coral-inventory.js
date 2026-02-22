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

const args = process.argv.slice(2);

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
  // Coral species
  apal: { id: 'apal', code: 'APAL', demoCode: 'DMAP', name: 'Acropora palmata', organismKind: 'coral' },
  acer: { id: 'acer', code: 'ACER', demoCode: 'DMAC', name: 'Acropora cervicornis', organismKind: 'coral' },
  past: { id: 'past', code: 'PAST', demoCode: 'DMPA', name: 'Porites astreoides', organismKind: 'coral' },
  pstr: { id: 'pstr', code: 'PSTR', demoCode: 'DMPS', name: 'Pseudodiploria strigosa', organismKind: 'coral' },
  cnat: { id: 'cnat', code: 'CNAT', demoCode: 'DMCN', name: 'Colpophyllia natans', organismKind: 'coral' },
  mcav: { id: 'mcav', code: 'MCAV', demoCode: 'DMMC', name: 'Montastraea cavernosa', organismKind: 'coral' },
  ofav: { id: 'ofav', code: 'OFAV', demoCode: 'DMOF', name: 'Orbicella faveolata', organismKind: 'coral' },
  // Oyster species
  cvir: { id: 'cvir', code: 'CVIR', demoCode: 'DMCV', name: 'Crassostrea virginica', organismKind: 'oyster' },
  cgig: { id: 'cgig', code: 'CGIG', demoCode: 'DMCG', name: 'Crassostrea gigas', organismKind: 'oyster' },
  // Kelp species
  mpyr: { id: 'mpyr', code: 'MPYR', demoCode: 'DMMP', name: 'Macrocystis pyrifera', organismKind: 'kelp' },
  slat: { id: 'slat', code: 'SLAT', demoCode: 'DMSL', name: 'Saccharina latissima', organismKind: 'kelp' },
  // Seagrass species
  ttes: { id: 'ttes', code: 'TTES', demoCode: 'DMTT', name: 'Thalassia testudinum', organismKind: 'seagrass' },
  zwri: { id: 'zwri', code: 'ZWRI', demoCode: 'DMZW', name: 'Zostera wrightii', organismKind: 'seagrass' },
};

// Organism kinds
const ORGANISM_KINDS = {
  coral: 'coral',
  oyster: 'oyster',
  kelp: 'kelp',
  seagrass: 'seagrass',
};

// Site types
const SITE_TYPES = {
  nurseryExSitu: 'site_type_nursery_ex_situ',
  nurseryInSitu: 'site_type_nursery_in_situ',
  geneBank: 'site_type_gene_bank',
  outplantSite: 'site_type_outplanting',
  baselineSite: 'site_type_baseline',
  referenceSite: 'site_type_reference',
  // Non-coral site types
  kelpFarm: 'site_type_kelp_farm',
  reefAquaculture: 'site_type_reef_aquaculture',
  seagrassPlot: 'site_type_seagrass_plot',
  hatchery: 'site_type_hatchery',
};

// Group types
const GROUP_TYPES = {
  tank: 'group_type_tank',
  tray: 'group_type_tray',
  tree: 'group_type_tree',
  treeBranch: 'group_type_tree_branch',
  dome: 'group_type_dome',
  grid: 'group_type_grid',
  gridCell: 'group_type_grid_cell',
  tag: 'group_type_tag',
  // Non-coral group types
  longline: 'group_type_longline',
  rack: 'group_type_rack',
  plotTransect: 'group_type_plot_transect',
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
  [GROUP_TYPES.longline]: 'Longline',
  [GROUP_TYPES.rack]: 'Rack',
  [GROUP_TYPES.plotTransect]: 'Plot Transect',
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

// Physical form profiles for oyster
const OYSTER_PHYSICAL_FORM_PROFILES = {
  gamete: [
    { formId: 'liquid_suspension', sizeBandId: 'small' },
    { formId: 'liquid_suspension', sizeBandId: 'medium' },
  ],
  larva: [
    { formId: 'liquid_suspension', sizeBandId: 'small' },
    { formId: 'liquid_suspension', sizeBandId: 'medium' },
    { formId: 'liquid_suspension', sizeBandId: 'large' },
  ],
  juvenile: [
    { formId: 'spat_bag', sizeBandId: 'small' },
    { formId: 'spat_bag', sizeBandId: 'medium' },
    { formId: 'individual', sizeBandId: 'small' },
  ],
  adult: [
    { formId: 'individual', sizeBandId: 'medium' },
    { formId: 'individual', sizeBandId: 'large' },
    { formId: 'oyster_cluster', sizeBandId: 'medium' },
  ],
  broodstock: [
    { formId: 'individual', sizeBandId: 'large' },
    { formId: 'individual', sizeBandId: 'xl' },
  ],
};

// Physical form profiles for kelp
const KELP_PHYSICAL_FORM_PROFILES = {
  gametophyte: [
    { formId: 'gametophyte_culture', sizeBandId: 'small' },
    { formId: 'gametophyte_culture', sizeBandId: 'medium' },
  ],
  sporophyte: [
    { formId: 'seeded_twine', sizeBandId: 'small' },
    { formId: 'seeded_twine', sizeBandId: 'medium' },
  ],
  juvenile: [
    { formId: 'seeded_twine', sizeBandId: 'medium' },
    { formId: 'individual_blade', sizeBandId: 'small' },
  ],
  adult: [
    { formId: 'individual_blade', sizeBandId: 'medium' },
    { formId: 'individual_blade', sizeBandId: 'large' },
  ],
};

// Physical form profiles for seagrass
const SEAGRASS_PHYSICAL_FORM_PROFILES = {
  seed: [
    { formId: 'loose_seed', sizeBandId: 'small' },
    { formId: 'loose_seed', sizeBandId: 'medium' },
    { formId: 'seed_buoy', sizeBandId: 'small' },
  ],
  seedling: [
    { formId: 'seedling_plug', sizeBandId: 'small' },
    { formId: 'seedling_plug', sizeBandId: 'medium' },
  ],
  juvenile: [
    { formId: 'individual', sizeBandId: 'small' },
    { formId: 'individual', sizeBandId: 'medium' },
  ],
  adult: [
    { formId: 'individual', sizeBandId: 'medium' },
    { formId: 'individual', sizeBandId: 'large' },
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

// Gamete roles for spawn events
const GAMETE_ROLES = {
  egg: 'egg',
  sperm: 'sperm',
};

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

// Provenance types
const PROVENANCE_TYPES = {
  wild: 'provenance_type_wild',
  sexualCohort: 'provenance_type_sexual_cohort',
  graduatedIndividual: 'provenance_type_graduated_individual',
  transfer: 'provenance_type_transfer',
  unknown: 'provenance_type_unknown',
};

const OUTPLANT_MONTHS = [2, 3, 4, 8, 9, 10]; // Mar-May, Sep-Nov
const SPAWN_MONTHS = [7, 8, 9, 10]; // Aug-Nov

async function seedInventory({ orgId, userId, seed, seedDate, tier = 'scale', orgUrlPrefix }) {
  const rng = createSeededRandom(seed || 7);
  const baseDate = seedDate ? new Date(seedDate) : new Date();
  const now = new Date().toISOString();

  const orgRef = db.collection('organizations').doc(orgId);

  // Tier-based feature flags
  // - Permits: Pro and Scale tiers
  // - Deliverables: Pro and Scale tiers
  // - Monitoring + Husbandry: Pro and Scale tiers
  // - Tasks + Chat: Scale tier only
  const isCommunity = tier === 'community';
  const isProOrScale = tier === 'pro' || tier === 'scale';
  const isScale = tier === 'scale';
  const hasMonitoring = isProOrScale;
  const hasHusbandry = isProOrScale;
  const hasTasks = isScale;
  const hasComments = isProOrScale;
  const hasSiteChat = isScale;
  const hasSpawning = isProOrScale;

  console.log('INFO: Clearing existing inventory...');
  await clearInventory(orgId);
  console.log('INFO: Inventory cleared.');

  // Create sites
  console.log('INFO: Creating sites...');
  const sites = await createSites(
    orgId,
    userId,
    now,
    orgUrlPrefix,
    {
      includeMonitoringSites: hasMonitoring,
      nurserySiteKeys: isCommunity ? ['nurseryLand'] : ['nurseryLand', 'nurseryField'],
      includeGeneBank: !isCommunity,
    },
  );
  console.log(`INFO: Created ${Object.keys(sites).length} sites.`);

  // Funders are available to all tiers (linked to permits/deliverables if those exist)
  console.log('INFO: Creating funders...');
  const funders = await createFunders(orgId, userId, now);
  console.log(`INFO: Created ${funders.length} funders.`);

  // Permits: Pro and Scale tiers only
  let permits = [];
  if (isProOrScale) {
    console.log('INFO: Creating permits...');
    permits = await createPermits(orgId, userId, sites, now);
    console.log(`INFO: Created ${permits.length} permits.`);
  } else {
    console.log('INFO: Skipping permits (Community tier).');
  }

  // Deliverables: Pro and Scale tiers
  let deliverables = [];
  if (isProOrScale) {
    console.log('INFO: Creating deliverables...');
    deliverables = await createDeliverables(
      orgId,
      userId,
      sites,
      permits,
      funders,
      baseDate,
      now,
    );
    console.log(`INFO: Created ${deliverables.length} deliverables.`);
  } else {
    console.log(`INFO: Skipping deliverables (${tier} tier).`);
  }

  // Vessels and Missions: Scale tier only
  let vessels = [];
  let missions = [];
  if (isScale) {
    console.log('INFO: Creating vessels...');
    vessels = await createVessels(orgId, userId, sites, now);
    console.log(`INFO: Created ${vessels.length} vessels.`);

    console.log('INFO: Creating missions...');
    missions = await createMissions(
      orgId,
      userId,
      sites,
      vessels,
      deliverables,
      baseDate,
      now,
      orgUrlPrefix,
    );
    console.log(`INFO: Created ${missions.length} missions.`);
  } else {
    console.log(`INFO: Skipping vessels and missions (${tier} tier).`);
  }

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

  // Create events (outplants, tasks, husbandry)
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
    {
      permits,
      deliverables,
      funders,
    },
    {
      includeTasks: hasTasks,
      includeHusbandry: hasHusbandry,
    },
  );
  console.log(`INFO: Created ${eventCount} events.`);

  if (hasMonitoring) {
    console.log('INFO: Creating monitoring events...');
    const monitoringEvents = await createMonitoringEvents({
      orgId,
      userId,
      sites,
      outplantEvents: events.filter((event) => event.eventTypeId === 'outplant_event'),
      genets,
      rng,
      baseDate,
    });
    console.log(`INFO: Created ${monitoringEvents.length} monitoring events.`);

    console.log('INFO: Creating ecological surveys...');
    const ecologicalSurveys = await createEcologicalSurveys({
      orgId,
      userId,
      sites,
      deliverables,
      permits,
      rng,
      baseDate,
    });
    console.log(`INFO: Created ${ecologicalSurveys.length} ecological surveys.`);
  } else {
    console.log(`INFO: Skipping monitoring events (tier=${tier}).`);
    console.log(`INFO: Skipping ecological surveys (tier=${tier}).`);
  }

  // Create spawn events and gamete organisms
  let crossEvents = [];
  let cohortOrganisms = [];
  let graduatedOrganisms = [];

  if (hasSpawning) {
    console.log('INFO: Creating spawn events and gametes...');
    const { spawnEvents, gameteOrganisms } = await createSpawnEventsAndGametes({
      orgId,
      userId,
      sites,
      genets,
      groupsBySiteKey,
      rng,
      baseDate,
      now,
    });
    console.log(`INFO: Created ${spawnEvents.length} spawn events and ${gameteOrganisms.length} gamete organisms.`);

    // Create cross events using gametes
    console.log('INFO: Creating cross events...');
    crossEvents = await createCrossEvents({
      orgId,
      userId,
      sites,
      gameteOrganisms,
      genets,
      rng,
      baseDate,
      now,
    });
    console.log(`INFO: Created ${crossEvents.length} cross events.`);

    // Create sexual cohort organisms from cross events
    if (crossEvents.length > 0) {
      console.log('INFO: Creating sexual cohort organisms...');
      cohortOrganisms = await createSexualCohortOrganisms({
        orgId,
        userId,
        sites,
        crossEvents,
        gameteOrganisms,
        rng,
        baseDate,
        now,
      });
      console.log(`INFO: Created ${cohortOrganisms.length} sexual cohort organisms.`);

      // Create graduated individuals from cohorts
      if (cohortOrganisms.length > 0) {
        console.log('INFO: Creating graduated individuals...');
        graduatedOrganisms = await createGraduatedIndividuals({
          orgId,
          userId,
          sites,
          cohortOrganisms,
          genets,
          rng,
          baseDate,
          now,
        });
        console.log(`INFO: Created ${graduatedOrganisms.length} graduated individuals.`);
      }
    }
  } else {
    console.log(`INFO: Skipping spawn/cross events (tier=${tier}).`);
  }

  // Create non-coral organism sites and organisms for Pro/Scale tiers
  if (isProOrScale) {
    console.log('INFO: Creating non-coral organism sites...');
    const nonCoralSites = await createNonCoralSites(orgId, userId, now, orgUrlPrefix);
    console.log(`INFO: Created ${Object.keys(nonCoralSites).length} non-coral sites.`);

    console.log('INFO: Creating non-coral organisms...');
    const { organisms: nonCoralOrganisms, groupCount: nonCoralGroupCount } = await createNonCoralOrganisms({
      orgId,
      userId,
      sites: nonCoralSites,
      rng,
      baseDate,
      now,
      tier,
    });
    console.log(`INFO: Created ${nonCoralGroupCount} non-coral groups and ${nonCoralOrganisms.length} non-coral organisms.`);

    // Create additional monitoring and husbandry events
    console.log('INFO: Creating additional events...');
    const allOrganismsForEvents = [...organisms, ...cohortOrganisms, ...graduatedOrganisms, ...nonCoralOrganisms];
    const additionalEvents = await createAdditionalEvents({
      orgId,
      userId,
      organisms: allOrganismsForEvents,
      rng,
      baseDate,
      now,
      tier,
    });
    console.log(`INFO: Created ${additionalEvents.length} additional events.`);
  } else {
    console.log(`INFO: Skipping non-coral organisms (tier=${tier}).`);
  }

  // Create comments on events
  if (hasComments) {
    console.log('INFO: Creating comments...');
    const commentCount = await createComments(
      orgId,
      userId,
      events,
      rng,
      baseDate,
      now,
    );
    console.log(`INFO: Created ${commentCount} comments.`);
  } else {
    console.log(`INFO: Skipping comments (tier=${tier}).`);
  }

  // Create chat rooms and messages
  if (hasSiteChat) {
    console.log('INFO: Creating chat rooms and messages...');
    const { roomCount, messageCount } =
      await createChatRoomsAndMessages(orgId, userId, sites, rng, baseDate, now);
    console.log(`INFO: Created ${roomCount} chat rooms and ${messageCount} messages.`);
  } else {
    console.log(`INFO: Skipping chat rooms/messages (tier=${tier}).`);
  }

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
    // Additional outplant site for Pro/Scale tiers
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

async function createFunders(orgId, userId, now) {
  const funders = [];
  const funderData = [
    {
      name: 'Ocean Resilience Fund',
      contactName: 'Dr. Ava Carter',
      contactEmail: 'ava.carter@oceanresilience.org',
      notes: 'Supports large-scale outplanting and monitoring.',
    },
    {
      name: 'Reef Recovery Initiative',
      contactName: 'Marcus Lee',
      contactEmail: 'marcus.lee@reefinitiative.org',
      notes: 'Focuses on baseline and reference site recovery.',
    },
    {
      name: 'Coral Futures Grant',
      contactName: 'Sofia Ramirez',
      contactEmail: 'sofia.ramirez@coralfutures.org',
      notes: 'Funds field operations and ecological surveys.',
    },
  ];

  for (const data of funderData) {
    const funderId = db.collection('funders').doc().id;
    const funder = {
      id: funderId,
      modelType: 'funder',
      organizationId: orgId,
      createdAt: now,
      updatedAt: now,
      createdById: userId,
      updatedById: userId,
      name: data.name,
      contactName: data.contactName,
      contactEmail: data.contactEmail,
      notes: data.notes,
      isActive: true,
    };
    await db.collection('funders').doc(funderId).set(funder);
    funders.push(funder);
  }

  return funders;
}

async function createPermits(orgId, userId, sites, now) {
  const permits = [];
  const outplantSite = sites.outplant;
  if (!outplantSite) return permits;

  const baselineSite = sites.baseline;
  const referenceSite = sites.reference;
  const permitData = [
    {
      permitNumber: 'OP-2025-001',
      name: 'Outplanting Permit',
      issuingAuthority: 'Florida Fish & Wildlife Commission',
      typeId: 'outplanting',
      siteIds: [outplantSite.id],
      contactName: 'Compliance Office',
      contactEmail: 'permits@floridafwc.gov',
      authorizedActivities: ['outplant_event', 'event_observation'],
      regulatoryAgency: 'Florida Department of Environmental Protection',
      permitConditions: 'Submit quarterly monitoring reports for outplanted sites.',
      attachmentUrls: [
        'https://example.org/permits/outplanting-guidelines.pdf',
      ],
    },
    {
      permitNumber: 'MON-2025-014',
      name: 'Monitoring Permit',
      issuingAuthority: 'NOAA Marine Sanctuaries',
      typeId: 'monitoring',
      siteIds: [baselineSite?.id, referenceSite?.id].filter(Boolean),
      contactName: 'Monitoring Desk',
      contactEmail: 'monitoring@noaa.gov',
      authorizedActivities: ['event_observation', 'event_ecological_survey'],
      regulatoryAgency: 'NOAA',
      permitConditions: 'Annual ecological surveys at reference sites.',
      attachmentUrls: [
        'https://example.org/permits/monitoring-protocols.pdf',
      ],
    },
    {
      permitNumber: 'RES-2025-203',
      name: 'Research Permit',
      issuingAuthority: 'University Coastal Lab',
      typeId: 'research',
      siteIds: [referenceSite?.id].filter(Boolean),
      contactName: 'Research Coordinator',
      contactEmail: 'research@coastallab.edu',
      authorizedActivities: ['event_ecological_survey'],
      regulatoryAgency: 'State Research Board',
      permitConditions: 'Share survey data quarterly with partners.',
      attachmentUrls: [
        'https://example.org/permits/research-permit.pdf',
      ],
    },
  ];

  for (let i = 0; i < permitData.length; i += 1) {
    const permitId = db.collection('permits').doc().id;
    const validFrom = new Date(now);
    validFrom.setDate(validFrom.getDate() - (30 + i * 15));
    const validTo = new Date(now);
    validTo.setFullYear(validTo.getFullYear() + 1);

    const permit = {
      id: permitId,
      modelType: 'permit',
      organizationId: orgId,
      createdAt: now,
      updatedAt: now,
      createdById: userId,
      updatedById: userId,
      validFrom: validFrom.toISOString(),
      validTo: validTo.toISOString(),
      ...permitData[i],
    };

    await db.collection('permits').doc(permitId).set(permit);
    permits.push(permit);
  }

  return permits;
}

async function createDeliverables(
  orgId,
  userId,
  sites,
  permits,
  funders,
  baseDate,
  now,
) {
  const deliverables = [];
  const outplantSite = sites.outplant;
  if (!outplantSite) return deliverables;

  const baselineSite = sites.baseline;
  const referenceSite = sites.reference;
  const deliverableData = [
    {
      name: 'Outplanting Compliance Report',
      description: 'Quarterly outplant compliance and monitoring summary.',
      typeId: 'report',
      frequencyId: 'quarterly',
      requiredSiteIds: [outplantSite.id],
      progressPercent: 45,
      totalOrganismTarget: 240,
      genetDiversityTarget: 18,
      speciesTargets: [
        {
          speciesId: SPECIES.apal.id,
          speciesName: SPECIES.apal.name,
          targetCount: 140,
          genetTargetCount: 8,
        },
        {
          speciesId: SPECIES.acer.id,
          speciesName: SPECIES.acer.name,
          targetCount: 100,
          genetTargetCount: 6,
        },
      ],
      siteAllocations: [
        {
          siteId: outplantSite.id,
          siteName: outplantSite.name,
          targetCount: 240,
        },
      ],
      monitoringRequirements: [
        {
          typeId: 'pre_outplant',
          intervalId: '7_days',
          isRequired: true,
          notes: 'Baseline survey before deployment.',
        },
        {
          typeId: 'post_outplant',
          intervalId: '1_month',
          isRequired: true,
          notes: 'Early survivorship assessment.',
        },
      ],
    },
    {
      name: 'Reference Site Ecological Survey',
      description: 'Annual ecological survey for reference reef health.',
      typeId: 'survey',
      frequencyId: 'annual',
      requiredSiteIds: referenceSite?.id ? [referenceSite.id] : [],
      progressPercent: 20,
      totalOrganismTarget: 120,
      genetDiversityTarget: 10,
      speciesTargets: [
        {
          speciesId: SPECIES.past.id,
          speciesName: SPECIES.past.name,
          targetCount: 60,
          genetTargetCount: 4,
        },
        {
          speciesId: SPECIES.mcav.id,
          speciesName: SPECIES.mcav.name,
          targetCount: 60,
          genetTargetCount: 4,
        },
      ],
      siteAllocations: referenceSite?.id
        ? [
          {
            siteId: referenceSite.id,
            siteName: referenceSite.name,
            targetCount: 120,
          },
        ]
        : [],
      monitoringRequirements: [
        {
          typeId: 'ecological_survey',
          intervalId: 'annual',
          isRequired: true,
          notes: 'Annual ecological survey at reference reef.',
        },
      ],
    },
    {
      name: 'Baseline Survey Update',
      description: 'Semi-annual baseline monitoring for trend tracking.',
      typeId: 'documentation',
      frequencyId: 'semi_annual',
      requiredSiteIds: baselineSite?.id ? [baselineSite.id] : [],
      progressPercent: 10,
      totalOrganismTarget: 90,
      genetDiversityTarget: 6,
      speciesTargets: [
        {
          speciesId: SPECIES.ofav.id,
          speciesName: SPECIES.ofav.name,
          targetCount: 50,
          genetTargetCount: 3,
        },
        {
          speciesId: SPECIES.cnat.id,
          speciesName: SPECIES.cnat.name,
          targetCount: 40,
          genetTargetCount: 3,
        },
      ],
      siteAllocations: baselineSite?.id
        ? [
          {
            siteId: baselineSite.id,
            siteName: baselineSite.name,
            targetCount: 90,
          },
        ]
        : [],
      monitoringRequirements: [
        {
          typeId: 'ecological_survey',
          intervalId: 'semi_annual',
          isRequired: true,
          notes: 'Baseline ecological survey cadence.',
        },
      ],
    },
  ];

  for (let i = 0; i < deliverableData.length; i += 1) {
    const deliverableId = db.collection('deliverables').doc().id;
    const dueDate = new Date(baseDate);
    dueDate.setDate(dueDate.getDate() + 30 + i * 20);
    const permit = permits[i % permits.length];
    const funder = funders[i % funders.length];

    const deliverable = {
      id: deliverableId,
      modelType: 'deliverable',
      organizationId: orgId,
      createdAt: now,
      updatedAt: now,
      createdById: userId,
      updatedById: userId,
      permitId: permit?.id,
      dueDate: dueDate.toISOString(),
      statusId: 'in_progress',
      assigneeUserIds: [userId],
      funderIds: funder ? [funder.id] : [],
      funderContactName: funder?.contactName,
      funderContactEmail: funder?.contactEmail,
      grantNumber: `GR-${2025 + i}-0${i + 1}`,
      isExclusive: i === 0,
      ...deliverableData[i],
    };

    await db.collection('deliverables').doc(deliverableId).set(deliverable);
    deliverables.push(deliverable);
  }

  return deliverables;
}

async function createVessels(orgId, userId, sites, now) {
  const vessels = [];
  const nurserySite = sites.nurseryLand || sites.nurseryField;

  const vesselData = [
    {
      name: 'R/V Blue Horizon',
      registrationNumber: 'FL-RV-2024-001',
      crewCapacity: 8,
      maxSpeedKnots: 18.5,
      homePortSiteId: nurserySite?.id || null,
      capabilities: ['diving', 'research_lab', 'crane', 'specimen_transport', 'wet_lab'],
      fuelCapacityGallons: 1200,
      rangeNauticalMiles: 350,
      statusId: 'available',
    },
    {
      name: 'Coral Runner',
      registrationNumber: 'FL-CB-2024-015',
      crewCapacity: 4,
      maxSpeedKnots: 32.0,
      homePortSiteId: nurserySite?.id || null,
      capabilities: ['diving', 'specimen_transport', 'towing'],
      fuelCapacityGallons: 400,
      rangeNauticalMiles: 180,
      statusId: 'available',
    },
    {
      name: 'Reef Guardian',
      registrationNumber: 'FL-MP-2023-042',
      crewCapacity: 6,
      maxSpeedKnots: 12.0,
      homePortSiteId: null,
      capabilities: ['diving', 'crane', 'monitoring_equipment', 'rov'],
      fuelCapacityGallons: 800,
      rangeNauticalMiles: 250,
      statusId: 'in_maintenance',
    },
  ];

  for (const data of vesselData) {
    const vesselId = db.collection('vessels').doc().id;
    const vessel = {
      id: vesselId,
      modelType: 'vessel',
      organizationId: orgId,
      createdAt: now,
      updatedAt: now,
      createdById: userId,
      updatedById: userId,
      name: data.name,
      registrationNumber: data.registrationNumber,
      crewCapacity: data.crewCapacity,
      maxSpeedKnots: data.maxSpeedKnots,
      capabilities: data.capabilities,
      fuelCapacityGallons: data.fuelCapacityGallons,
      rangeNauticalMiles: data.rangeNauticalMiles,
      statusId: data.statusId,
    };
    if (data.homePortSiteId) {
      vessel.homePortSiteId = data.homePortSiteId;
    }
    await db.collection('vessels').doc(vesselId).set(vessel);
    vessels.push(vessel);
  }

  return vessels;
}

async function createMissions(orgId, userId, sites, vessels, deliverables, baseDate, now, orgUrlPrefix) {
  const missions = [];
  const basePath = normalizeUrlPrefix(orgUrlPrefix || orgId);

  // Collect crew user IDs from org members
  const orgRef = db.collection('organizations').doc(orgId);
  const membersSnap = await orgRef.collection('members').limit(10).get();
  const crewUserIds = membersSnap.docs.map((doc) => doc.id);
  if (!crewUserIds.includes(userId)) {
    crewUserIds.unshift(userId);
  }

  // Resolve site references
  const nurserySite = sites.nurseryLand || sites.nurseryField;
  const outplantSite = sites.outplant;
  const baselineSite = sites.baseline;
  const referenceSite = sites.reference;

  // Resolve vessel references
  const primaryVessel = vessels.find((v) => v.name === 'R/V Blue Horizon') || vessels[0];
  const transportVessel = vessels.find((v) => v.name === 'Coral Runner') || vessels[1] || vessels[0];

  // Collect deliverable IDs (first two if available)
  const deliverableIds = deliverables.slice(0, 2).map((d) => d.id);

  const pastDate1 = new Date(baseDate);
  pastDate1.setDate(pastDate1.getDate() - 14);

  const pastDate2 = new Date(baseDate);
  pastDate2.setDate(pastDate2.getDate() - 7);

  const currentDate = new Date(baseDate);

  const futureDate1 = new Date(baseDate);
  futureDate1.setDate(futureDate1.getDate() + 10);

  const futureDate2 = new Date(baseDate);
  futureDate2.setDate(futureDate2.getDate() + 45);

  const missionData = [
    {
      name: 'Weekly Nursery Assessment',
      description: 'Routine weekly assessment of land-based and in-water nursery fragments. Check growth rates, mortality, and water quality parameters.',
      scheduledDate: pastDate1.toISOString(),
      endDate: pastDate1.toISOString(),
      siteIds: [nurserySite?.id].filter(Boolean),
      vesselId: null,
      crewUserIds: crewUserIds.slice(0, 3),
      statusId: 'completed',
      estimatedDurationHours: 4,
      notes: 'Assessment completed. All fragments in good condition. Growth rate above average this period.',
      deliverableIds: deliverableIds.slice(0, 1),
    },
    {
      name: 'Outplant Deployment - Reef 7',
      description: 'Deploy nursery-reared coral fragments to designated outplant site. Transport specimens via vessel and secure to reef substrate.',
      scheduledDate: pastDate2.toISOString(),
      endDate: pastDate2.toISOString(),
      siteIds: [outplantSite?.id, nurserySite?.id].filter(Boolean),
      vesselId: transportVessel?.id || null,
      crewUserIds: crewUserIds.slice(0, 4),
      statusId: 'completed',
      estimatedDurationHours: 8,
      notes: 'Successfully deployed 48 fragments. Sea conditions were favorable. All fragments attached securely.',
      deliverableIds,
    },
    {
      name: 'Quarterly Monitoring Survey',
      description: 'Conduct quarterly health and survival monitoring at baseline and reference reef sites. Record photo transects, bleaching observations, and species counts.',
      scheduledDate: currentDate.toISOString(),
      endDate: null,
      siteIds: [baselineSite?.id, referenceSite?.id].filter(Boolean),
      vesselId: primaryVessel?.id || null,
      crewUserIds: crewUserIds.slice(0, 5),
      statusId: 'in_progress',
      estimatedDurationHours: 12,
      notes: 'Survey underway. Morning dives completed at baseline site. Afternoon session at reference site pending.',
      deliverableIds: deliverableIds.slice(1, 2),
    },
    {
      name: 'Emergency Fragment Rescue',
      description: 'Urgent recovery of coral fragments from nursery tree damaged by storm surge. Relocate surviving fragments to land-based nursery for stabilization.',
      scheduledDate: futureDate1.toISOString(),
      endDate: null,
      siteIds: [nurserySite?.id].filter(Boolean),
      vesselId: transportVessel?.id || null,
      crewUserIds: crewUserIds.slice(0, 3),
      statusId: 'scheduled',
      estimatedDurationHours: 6,
      notes: 'Pre-mission check: confirm nursery tree damage extent. Prepare emergency holding tanks.',
      deliverableIds: [],
    },
    {
      name: 'Annual Population Census',
      description: 'Comprehensive annual census of all outplanted coral populations. Assess survival rates, colony growth, and genetic diversity across all outplant sites.',
      scheduledDate: futureDate2.toISOString(),
      endDate: new Date(futureDate2.getTime() + 3 * DAY_MS).toISOString(),
      siteIds: [outplantSite?.id, baselineSite?.id, referenceSite?.id].filter(Boolean),
      vesselId: primaryVessel?.id || null,
      crewUserIds: crewUserIds.slice(0, Math.min(crewUserIds.length, 6)),
      statusId: 'draft',
      estimatedDurationHours: 40,
      notes: 'Multi-day operation. Requires full crew and research vessel. Coordinate with partner organizations.',
      deliverableIds,
    },
  ];

  for (const data of missionData) {
    const missionId = db.collection('missions').doc().id;
    const slug = slugify(data.name);
    const mission = {
      id: missionId,
      modelType: 'mission',
      organizationId: orgId,
      slug,
      urlPath: `${basePath}/${slug}`,
      internalPath: `missions/${missionId}`,
      createdAt: now,
      updatedAt: now,
      createdById: userId,
      updatedById: userId,
      name: data.name,
      description: data.description,
      scheduledDate: data.scheduledDate,
      siteIds: data.siteIds,
      taskIds: [],
      crewUserIds: data.crewUserIds,
      statusId: data.statusId,
      estimatedDurationHours: data.estimatedDurationHours,
      notes: data.notes,
      deliverableIds: data.deliverableIds,
      plannedAllocations: [],
    };
    if (data.endDate) {
      mission.endDate = data.endDate;
    }
    if (data.vesselId) {
      mission.vesselId = data.vesselId;
    }
    await db.collection('missions').doc(missionId).set(mission);
    missions.push(mission);
  }

  return missions;
}

function buildMonitoringEntriesFromAllocations(allocations, rng) {
  return allocations
    .filter((allocation) => allocation.genetId)
    .map((allocation) => ({
      genetId: allocation.genetId,
      tagId: allocation.tagId || null,
      healthStatus: rng() > 0.8 ? 'stressed' : 'healthy',
      percentCover: Math.round(20 + rng() * 50),
      percentBleaching: Math.round(rng() * 10),
      percentDisease: Math.round(rng() * 5),
      notes: 'Routine monitoring entry.',
    }));
}

async function createMonitoringEvents({
  orgId,
  userId,
  sites,
  outplantEvents,
  genets,
  rng,
  baseDate,
}) {
  const events = [];
  const allSites = Object.values(sites || {});
  const outplantSites = allSites.filter(
    (site) => site.siteTypeId === SITE_TYPES.outplantSite,
  );
  const baselineSites = allSites.filter(
    (site) => site.siteTypeId === SITE_TYPES.baselineSite,
  );
  const referenceSites = allSites.filter(
    (site) => site.siteTypeId === SITE_TYPES.referenceSite,
  );

  const outplantById = new Map(outplantSites.map((site) => [site.id, site]));
  const outplantEventList = (outplantEvents || []).filter(
    (event) => event.eventTypeId === 'outplant_event',
  );

  for (const outplantEvent of outplantEventList) {
    const site =
      outplantById.get(outplantEvent.siteId) || outplantSites[0];
    if (!site) continue;

    const outplantDate = new Date(outplantEvent.createdAt);
    const preDate = new Date(outplantDate);
    preDate.setDate(preDate.getDate() - 7);
    const postDate = new Date(outplantDate);
    postDate.setDate(postDate.getDate() + 30);

    const allocations = outplantEvent.allocations || [];
    const entries = buildMonitoringEntriesFromAllocations(allocations, rng);
    const organismIds = allocations
      .map((allocation) => allocation.organismId)
      .filter(Boolean);
    const totalCount = allocations.reduce(
      (sum, allocation) => sum + (allocation.quantity || 0),
      0,
    );

    const shared = {
      siteId: site.id,
      siteName: site.name,
      outplantEventId: outplantEvent.id,
      outplantEventName: outplantEvent.name,
      entries,
      organismIds,
      totalCount: totalCount || entries.length,
    };

    const preSlug = `monitoring-pre-${outplantEvent.slug || outplantEvent.id}`;
    events.push({
      eventTypeId: 'event_observation',
      monitoringTypeId: 'pre_outplant',
      monitoringDate: preDate.toISOString(),
      healthStatus: 'healthy',
      percentCover: Math.round(20 + rng() * 20),
      percentBleaching: Math.round(rng() * 4),
      percentDisease: Math.round(rng() * 3),
      notes: 'Pre-outplant monitoring baseline.',
      ...shared,
      ...buildEventBase({
        orgId,
        userId,
        eventId: db.collection('events').doc().id,
        createdAt: preDate.toISOString(),
        recordId: site.id,
        recordModelType: 'site',
        recordUrlPath: site.urlPath,
        slug: preSlug,
      }),
    });

    const postSlug = `monitoring-post-${outplantEvent.slug || outplantEvent.id}`;
    events.push({
      eventTypeId: 'event_observation',
      monitoringTypeId: 'post_outplant',
      monitoringDate: postDate.toISOString(),
      healthStatus: rng() > 0.85 ? 'stressed' : 'healthy',
      percentCover: Math.round(15 + rng() * 25),
      percentBleaching: Math.round(rng() * 8),
      percentDisease: Math.round(rng() * 6),
      notes: 'Post-outplant survivorship monitoring.',
      ...shared,
      ...buildEventBase({
        orgId,
        userId,
        eventId: db.collection('events').doc().id,
        createdAt: postDate.toISOString(),
        recordId: site.id,
        recordModelType: 'site',
        recordUrlPath: site.urlPath,
        slug: postSlug,
      }),
    });
  }

  const siteMonitoringTargets = [...baselineSites, ...referenceSites];
  const genetIds = (genets || []).map((genet) => genet.id);
  siteMonitoringTargets.forEach((site, index) => {
    const monitorDate = new Date(baseDate);
    monitorDate.setDate(monitorDate.getDate() - (10 + index * 5));
    const entryCount = Math.min(4, genetIds.length);
    const entries = [];
    for (let i = 0; i < entryCount; i++) {
      const genetId = genetIds[(index + i) % genetIds.length];
      if (!genetId) continue;
      entries.push({
        genetId,
        healthStatus: rng() > 0.7 ? 'stressed' : 'healthy',
        percentCover: Math.round(10 + rng() * 40),
        percentBleaching: Math.round(rng() * 6),
        percentDisease: Math.round(rng() * 4),
        notes: 'Site monitoring entry.',
      });
    }

    // Calculate top-level aggregates from entries for analytics
    const avgPercentCover = entries.length > 0
      ? Math.round(entries.reduce((sum, e) => sum + (e.percentCover || 0), 0) / entries.length)
      : null;
    const avgPercentDisease = entries.length > 0
      ? Math.round(entries.reduce((sum, e) => sum + (e.percentDisease || 0), 0) / entries.length)
      : null;
    const healthStatus = entries.some((e) => e.healthStatus === 'stressed') ? 'stressed' : 'healthy';

    events.push({
      eventTypeId: 'event_observation',
      monitoringTypeId: 'adhoc',
      monitoringDate: monitorDate.toISOString(),
      siteId: site.id,
      siteName: site.name,
      percentCover: avgPercentCover,
      percentDisease: avgPercentDisease,
      healthStatus,
      entries,
      totalCount: entries.length,
      notes: `Routine monitoring at ${site.name}.`,
      ...buildEventBase({
        orgId,
        userId,
        eventId: db.collection('events').doc().id,
        createdAt: monitorDate.toISOString(),
        recordId: site.id,
        recordModelType: 'site',
        recordUrlPath: site.urlPath,
        slug: `monitoring-site-${site.slug}-${index + 1}`,
      }),
    });
  });

  outplantSites.forEach((site, index) => {
    const firstDate = new Date(baseDate);
    firstDate.setDate(firstDate.getDate() - (14 + index * 3));
    const secondDate = new Date(baseDate);
    secondDate.setDate(secondDate.getDate() - (45 + index * 4));
    const dates = [firstDate, secondDate];
    dates.forEach((monitorDate, entryIndex) => {
      const entryCount = Math.min(6, genetIds.length);
      const entries = [];
      for (let i = 0; i < entryCount; i++) {
        const genetId = genetIds[(index + i + entryIndex) % genetIds.length];
        if (!genetId) continue;
        entries.push({
          genetId,
          healthStatus: rng() > 0.75 ? 'stressed' : 'healthy',
          percentCover: Math.round(15 + rng() * 45),
          percentBleaching: Math.round(rng() * 8),
          percentDisease: Math.round(rng() * 5),
          notes: 'Outplant site monitoring entry.',
        });
      }

      // Calculate top-level aggregates from entries for analytics
      const avgPercentCover = entries.length > 0
        ? Math.round(entries.reduce((sum, e) => sum + (e.percentCover || 0), 0) / entries.length)
        : null;
      const avgPercentDisease = entries.length > 0
        ? Math.round(entries.reduce((sum, e) => sum + (e.percentDisease || 0), 0) / entries.length)
        : null;
      const healthStatus = entries.some((e) => e.healthStatus === 'stressed') ? 'stressed' : 'healthy';

      events.push({
        eventTypeId: 'event_observation',
        monitoringTypeId: 'adhoc',
        monitoringDate: monitorDate.toISOString(),
        siteId: site.id,
        siteName: site.name,
        percentCover: avgPercentCover,
        percentDisease: avgPercentDisease,
        healthStatus,
        entries,
        totalCount: entries.length,
        notes: `Outplant site follow-up monitoring at ${site.name}.`,
        ...buildEventBase({
          orgId,
          userId,
          eventId: db.collection('events').doc().id,
          createdAt: monitorDate.toISOString(),
          recordId: site.id,
          recordModelType: 'site',
          recordUrlPath: site.urlPath,
          slug: `monitoring-outplant-${site.slug}-${index + 1}-${entryIndex + 1}`,
        }),
      });
    });
  });

  const batchSize = 400;
  for (let i = 0; i < events.length; i += batchSize) {
    const batch = db.batch();
    events.slice(i, i + batchSize).forEach((event) => {
      batch.set(db.collection('events').doc(event.id), event);
    });
    await batch.commit();
  }

  return events;
}

async function createEcologicalSurveys({
  orgId,
  userId,
  sites,
  deliverables,
  permits,
  rng,
  baseDate,
}) {
  const orgRef = db.collection('organizations').doc(orgId);
  const surveys = [];
  const allSites = Object.values(sites || {});
  const targetSites = allSites.filter(
    (site) =>
      site.siteTypeId === SITE_TYPES.referenceSite ||
      site.siteTypeId === SITE_TYPES.baselineSite,
  );
  const permit = permits?.[0];
  const deliverable = deliverables?.[0];

  for (let i = 0; i < targetSites.length; i += 1) {
    const site = targetSites[i];
    for (let s = 0; s < 2; s += 1) {
      const surveyId = orgRef.collection('ecological_surveys').doc().id;
      const surveyDate = new Date(baseDate);
      surveyDate.setDate(surveyDate.getDate() - (30 + s * 45 + i * 10));
      const createdAt = surveyDate.toISOString();
      const isReference = site.siteTypeId === SITE_TYPES.referenceSite;

      const survey = {
        id: surveyId,
        modelType: 'event',
        eventTypeId: 'event_ecological_survey',
        organizationId: orgId,
        createdAt,
        updatedAt: createdAt,
        createdById: userId,
        updatedById: userId,
        recordId: site.id,
        recordModelType: 'site',
        urlPath: site.urlPath,
        internalPath: site.internalPath,
        slug: site.slug,
        siteId: site.id,
        siteName: site.name,
        surveyDate: createdAt,
        surveyMethod: isReference ? 'Reference transect' : 'Baseline quadrat',
        transectLength: 25,
        transectWidth: 2,
        quadratSize: 1,
        waterTemperatureCelsius: 26 + rng() * 2,
        ambientTemperatureCelsius: 28 + rng() * 3,
        salinityPpt: 34 + rng(),
        visibilityMeters: 12 + rng() * 6,
        turbidityNtu: 0.8 + rng() * 0.6,
        depthMeters: 6 + rng() * 4,
        liveCoralCoverPercent: isReference ? 35 + Math.round(rng() * 15) : 20 + Math.round(rng() * 10),
        deadCoralCoverPercent: isReference ? 8 + Math.round(rng() * 6) : 12 + Math.round(rng() * 8),
        recentMortalityPercent: 2 + Math.round(rng() * 4),
        diseasedColoniesPercent: 3 + Math.round(rng() * 5),
        bleachedColoniesPercent: 2 + Math.round(rng() * 4),
        bleachingSeverityId: rng() > 0.7 ? 'mild' : 'none',
        algaeCover: {
          turfAlgaePercent: 20 + Math.round(rng() * 10),
          macroalgaePercent: 8 + Math.round(rng() * 8),
          ccaPercent: 10 + Math.round(rng() * 8),
          cyanobacteriaPercent: 2 + Math.round(rng() * 3),
        },
        substrateComposition: {
          sandPercent: 25 + Math.round(rng() * 10),
          rubblePercent: 20 + Math.round(rng() * 10),
          rockPercent: 30 + Math.round(rng() * 10),
          siltPercent: 5 + Math.round(rng() * 5),
          pavementPercent: 10 + Math.round(rng() * 8),
        },
        diversityMetrics: {
          speciesRichness: 12 + Math.round(rng() * 6),
          shannonIndex: Number((1.2 + rng() * 0.6).toFixed(2)),
          simpsonIndex: Number((0.6 + rng() * 0.2).toFixed(2)),
          speciesList: [SPECIES.apal.id, SPECIES.acer.id, SPECIES.past.id],
        },
        exposureLevelId: rng() > 0.5 ? 'moderate' : 'sheltered',
        waveHeight: Number((0.4 + rng() * 0.5).toFixed(2)),
        notes: isReference
          ? 'Reference site ecological survey with stable coral cover.'
          : 'Baseline site ecological survey for trend tracking.',
        weatherConditions: rng() > 0.5 ? 'Partly cloudy' : 'Clear skies',
        surveyor: 'Demo Survey Team',
        assistants: ['Field Tech A', 'Field Tech B'],
        ...(isReference && deliverable ? { deliverableId: deliverable.id } : {}),
        ...(isReference && permit ? { permitId: permit.id } : {}),
      };

      await orgRef.collection('ecological_surveys').doc(surveyId).set(survey);
      surveys.push(survey);
    }
  }

  return surveys;
}

/**
 * Create spawn events and gamete organism records.
 * Spawn events represent the collection of gametes (eggs or sperm) from broodstock.
 * Each spawn event creates gamete organisms with the appropriate gameteRole.
 */
async function createSpawnEventsAndGametes({
  orgId,
  userId,
  sites,
  genets,
  groupsBySiteKey,
  rng,
  baseDate,
  now,
}) {
  const orgRef = db.collection('organizations').doc(orgId);
  const spawnEvents = [];
  const gameteOrganisms = [];

  // Use gene bank site for spawning (ex-situ controlled environment)
  const geneBankSite = sites.geneBank;
  if (!geneBankSite) {
    console.log('WARN: No gene bank site found, skipping spawn events.');
    return { spawnEvents, gameteOrganisms };
  }

  // Get broodstock genets (generation 0 founders) for spawning
  const broodstockGenets = genets.filter(
    (g) => g.generation === 0 && (g.speciesId === SPECIES.apal.id || g.speciesId === SPECIES.acer.id)
  );

  if (broodstockGenets.length < 4) {
    console.log('WARN: Not enough broodstock genets for spawn events.');
    return { spawnEvents, gameteOrganisms };
  }

  const geneBankGroups = groupsBySiteKey.geneBank || [];
  const targetGroup = geneBankGroups.length > 0 ? geneBankGroups[0] : null;

  // Create 4-6 spawn events (2-3 egg spawns, 2-3 sperm spawns per species)
  const speciesForSpawning = [SPECIES.apal, SPECIES.acer];

  for (const species of speciesForSpawning) {
    const speciesGenets = broodstockGenets.filter((g) => g.speciesId === species.id);
    if (speciesGenets.length < 2) continue;

    // Create egg spawn event
    const eggParents = speciesGenets.slice(0, Math.min(2, speciesGenets.length));
    const eggSpawnResult = await createSpawnEvent({
      orgRef,
      orgId,
      userId,
      site: geneBankSite,
      group: targetGroup,
      parentGenets: eggParents,
      gameteRole: GAMETE_ROLES.egg,
      gameteCount: 50000 + Math.floor(rng() * 100000),
      species,
      rng,
      baseDate,
      now,
      index: spawnEvents.length,
    });
    spawnEvents.push(eggSpawnResult.event);
    gameteOrganisms.push(...eggSpawnResult.gametes);

    // Create sperm spawn event from different parents
    const spermParents = speciesGenets.slice(
      Math.min(2, speciesGenets.length),
      Math.min(4, speciesGenets.length)
    );
    if (spermParents.length > 0) {
      const spermSpawnResult = await createSpawnEvent({
        orgRef,
        orgId,
        userId,
        site: geneBankSite,
        group: targetGroup,
        parentGenets: spermParents.length > 0 ? spermParents : [speciesGenets[0]],
        gameteRole: GAMETE_ROLES.sperm,
        gameteCount: 100000000 + Math.floor(rng() * 500000000),
        species,
        rng,
        baseDate,
        now,
        index: spawnEvents.length,
      });
      spawnEvents.push(spermSpawnResult.event);
      gameteOrganisms.push(...spermSpawnResult.gametes);
    }
  }

  return { spawnEvents, gameteOrganisms };
}

/**
 * Create a single spawn event with associated gamete organism records.
 */
async function createSpawnEvent({
  orgRef,
  orgId,
  userId,
  site,
  group,
  parentGenets,
  gameteRole,
  gameteCount,
  species,
  rng,
  baseDate,
  now,
  index,
}) {
  const eventId = db.collection('events').doc().id;
  const slug = `spawn-${gameteRole}-${species.code.toLowerCase()}-${index + 1}`;

  // Spawn date: late summer/fall, avoid peak summer heat
  const spawnDate = seasonalDate({
    anchorDate: baseDate,
    rng,
    allowedMonths: SPAWN_MONTHS,
  });

  const parentOrganismIds = parentGenets.map((g) => g.id);

  const event = {
    id: eventId,
    modelType: 'event',
    eventTypeId: 'event_spawn',
    organizationId: orgId,
    createdAt: spawnDate.toISOString(),
    updatedAt: spawnDate.toISOString(),
    createdById: userId,
    updatedById: userId,
    recordId: site.id,
    recordModelType: 'site',
    slug,
    urlPath: `${site.urlPath}/events/${slug}`,
    internalPath: `organizations/${orgId}/events/${eventId}`,
    // SpawnEvent-specific fields
    parentOrganismIds,
    gameteCount,
    gameteRole,
    metadata: {
      speciesId: species.id,
      speciesCode: species.code,
      speciesName: species.name,
      parentGenetIds: parentGenets.map((g) => g.id),
      organismKind: 'coral',
    },
  };

  await db.collection('events').doc(eventId).set(event);

  // Create gamete organism records
  const gametes = [];
  const gameteOrganism = await createGameteOrganism({
    orgRef,
    orgId,
    userId,
    site,
    group,
    parentGenets,
    gameteRole,
    gameteCount,
    species,
    spawnEventId: eventId,
    rng,
    createdAt: spawnDate.toISOString(),
    now,
  });
  gametes.push(gameteOrganism);

  return { event, gametes };
}

/**
 * Create a gamete organism record with proper gameteRole in provenanceAttributes.
 */
async function createGameteOrganism({
  orgRef,
  orgId,
  userId,
  site,
  group,
  parentGenets,
  gameteRole,
  gameteCount,
  species,
  spawnEventId,
  rng,
  createdAt,
  now,
}) {
  const organismId = orgRef.collection('organismRecords').doc().id;
  const parentGenet = parentGenets[0];
  const localId = `${species.code}-${gameteRole.toUpperCase()}-${Math.floor(rng() * 1000).toString().padStart(4, '0')}`;
  const slug = localId.toLowerCase();
  const recordName = `${species.code} ${gameteRole === GAMETE_ROLES.egg ? 'Eggs' : 'Sperm'} Batch`;

  const vesselProfiles = [
    { sizeBandId: 'xs', volumeMl: 0.5 },
    { sizeBandId: 'small', volumeMl: 1 },
    { sizeBandId: 'medium', volumeMl: 5 },
    { sizeBandId: 'large', volumeMl: 10 },
    { sizeBandId: 'xl', volumeMl: 50 },
  ];

  const vesselSizeBandOptions =
    gameteRole === GAMETE_ROLES.egg
      ? ['xs', 'small', 'medium']
      : ['small', 'medium', 'large'];
  const selectedSizeBand = pickRandom(vesselSizeBandOptions, rng) || 'small';
  const vesselProfile =
    vesselProfiles.find((profile) => profile.sizeBandId === selectedSizeBand) ||
    vesselProfiles[1];

  const densityPerMlRange =
    gameteRole === GAMETE_ROLES.egg
      ? { min: 5000, max: 20000 }
      : { min: 1000000, max: 5000000 };
  const organismsPerUnit =
    densityPerMlRange.min +
    Math.floor(rng() * (densityPerMlRange.max - densityPerMlRange.min + 1));
  const gametesPerVessel = organismsPerUnit * vesselProfile.volumeMl;
  const vesselCount = Math.max(1, Math.ceil(gameteCount / gametesPerVessel));

  const organism = {
    id: organismId,
    recordName,
    localId,
    genetId: parentGenet?.id || null,
    foreignKeys: parentGenet ? {
      genetId: { id: parentGenet.id, collection: 'genets' },
    } : {},
    speciesId: species.id,
    siteId: site.id,
    groupId: group?.id || null,
    lifeStage: { id: LIFE_STAGES.gamete },
    lifeStageId: LIFE_STAGES.gamete,
    provenanceType: PROVENANCE_TYPES.wild,
    provenanceTypeId: PROVENANCE_TYPES.wild,
    organismKind: 'coral',
    organizationId: orgId,
    modelType: 'organismRecord',
    slug,
    urlPath: group ? `${group.urlPath}/${slug}` : `${site.urlPath}/${slug}`,
    internalPath: `organizations/${orgId}/organismRecords/${organismId}`,
    createdAt,
    updatedAt: now,
    createdById: userId,
    updatedById: userId,
    measurement: {
      value: vesselCount,
      unit: 'count',
    },
    physicalForm: {
      formId: 'liquid_suspension',
      sizeBandId: vesselProfile.sizeBandId,
    },
    physicalFormConfigVersion: 'v1',
    // Inventory metrics: count is vessel count, volume is total across all vessels
    inventoryCount: vesselCount,
    inventoryVolumeCm3: vesselProfile.volumeMl * vesselCount,  // mL ≈ cm³ for aqueous solutions
    sizeSpec: {
      sizeBandId: vesselProfile.sizeBandId,
      organismsPerUnit,
      volumeAmount: vesselProfile.volumeMl,
      volumeUnit: 'mL',
    },
    // Provenance attributes with gameteRole
    provenanceAttributes: {
      gameteRole,
    },
    metadata: {
      spawnEventId,
      parentGenetIds: parentGenets.map((g) => g.id),
      healthStatus: 'healthy',
      gameteCount,
    },
    lifeStageHistory: [{
      fromStage: { id: LIFE_STAGES.gamete },
      toStage: { id: LIFE_STAGES.gamete },
      occurredAt: createdAt,
    }],
    measurementHistory: [{
      measurement: { value: vesselCount, unit: 'count' },
      recordedAt: createdAt,
    }],
  };

  await orgRef.collection('organismRecords').doc(organismId).set(organism);
  return organism;
}

/**
 * Create cross events that combine egg and sperm gametes.
 * Cross events validate that damIds reference egg gametes and sireIds reference sperm gametes.
 */
async function createCrossEvents({
  orgId,
  userId,
  sites,
  gameteOrganisms,
  genets,
  rng,
  baseDate,
  now,
}) {
  const crossEvents = [];

  const geneBankSite = sites.geneBank;
  if (!geneBankSite) {
    console.log('WARN: No gene bank site found, skipping cross events.');
    return crossEvents;
  }

  // Separate gametes by role
  const eggGametes = gameteOrganisms.filter(
    (g) => g.provenanceAttributes?.gameteRole === GAMETE_ROLES.egg
  );
  const spermGametes = gameteOrganisms.filter(
    (g) => g.provenanceAttributes?.gameteRole === GAMETE_ROLES.sperm
  );

  if (eggGametes.length === 0 || spermGametes.length === 0) {
    console.log('WARN: Not enough gametes with proper roles for cross events.');
    return crossEvents;
  }

  // Create crosses - pair eggs with sperm of the same species
  const speciesForCrossing = [SPECIES.apal, SPECIES.acer];

  for (const species of speciesForCrossing) {
    const speciesEggs = eggGametes.filter((g) => g.speciesId === species.id);
    const speciesSperm = spermGametes.filter((g) => g.speciesId === species.id);

    if (speciesEggs.length === 0 || speciesSperm.length === 0) continue;

    // Create 1-2 crosses per species
    const crossCount = 1 + Math.floor(rng() * 2);

    for (let i = 0; i < crossCount; i++) {
      const egg = speciesEggs[i % speciesEggs.length];
      const sperm = speciesSperm[i % speciesSperm.length];

      const crossEvent = await createCrossEvent({
        orgId,
        userId,
        site: geneBankSite,
        damIds: [egg.id],
        sireIds: [sperm.id],
        species,
        genets,
        rng,
        baseDate,
        now,
        index: crossEvents.length,
      });
      crossEvents.push(crossEvent);
    }
  }

  return crossEvents;
}

/**
 * Create a single cross event.
 */
async function createCrossEvent({
  orgId,
  userId,
  site,
  damIds,
  sireIds,
  species,
  genets,
  rng,
  baseDate,
  now,
  index,
}) {
  const eventId = db.collection('events').doc().id;
  const slug = `cross-${species.code.toLowerCase()}-${index + 1}`;

  // Cross date is shortly after spawn (same season)
  const spawnSeasonDate = seasonalDate({
    anchorDate: baseDate,
    rng,
    allowedMonths: SPAWN_MONTHS,
  });
  const crossDate = new Date(spawnSeasonDate);
  crossDate.setDate(crossDate.getDate() + 7 + Math.floor(rng() * 14));
  if (crossDate > baseDate) {
    crossDate.setTime(baseDate.getTime());
  }

  // Find a genet to associate the cross with (typically the first dam's genet)
  const targetGenet = genets.find((g) => g.speciesId === species.id);

  const event = {
    id: eventId,
    modelType: 'event',
    eventTypeId: 'event_cross',
    organizationId: orgId,
    createdAt: crossDate.toISOString(),
    updatedAt: crossDate.toISOString(),
    createdById: userId,
    updatedById: userId,
    recordId: targetGenet?.id || site.id,
    recordModelType: targetGenet ? 'genet' : 'site',
    slug,
    urlPath: targetGenet
      ? `${targetGenet.urlPath}/events/${slug}`
      : `${site.urlPath}/events/${slug}`,
    internalPath: `organizations/${orgId}/events/${eventId}`,
    // CrossEvent-specific fields
    damIds,
    sireIds,
    metadata: {
      speciesId: species.id,
      speciesCode: species.code,
      speciesName: species.name,
      crossType: 'controlled',
      organismKind: 'coral',
    },
  };

  await db.collection('events').doc(eventId).set(event);
  return event;
}

async function createGenets(orgId, userId, rng, baseDate, now, orgUrlPrefix) {
  const genets = [];
  const orgRef = db.collection('organizations').doc(orgId);
  const basePath = normalizeUrlPrefix(orgUrlPrefix || orgId);

  // Main species with multiple genets
  const mainSpecies = [SPECIES.apal, SPECIES.acer];

  for (const sp of mainSpecies) {
    // Create founder genets (generation 0)
    const founderCount = 8 + Math.floor(rng() * 5); // 8-12 founders
    for (let i = 0; i < founderCount; i++) {
      const genet = await createGenet(orgRef, orgId, userId, basePath, sp, {
        generation: 0,
        index: i,
        provenanceType: PROVENANCE_TYPES.wild,
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
        rng,
        baseDate,
        now,
      });
      genets.push(genet);
    }
  }

  // Additional species with fewer genets
  const extraSpecies = [SPECIES.past, SPECIES.pstr, SPECIES.cnat, SPECIES.mcav, SPECIES.ofav];
  for (const sp of extraSpecies) {
    const count = 3 + Math.floor(rng() * 4); // 3-6 genets
    for (let i = 0; i < count; i++) {
      const genet = await createGenet(orgRef, orgId, userId, basePath, sp, {
        generation: 0,
        index: i,
        provenanceType: PROVENANCE_TYPES.wild,
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

  // Generate aliases for some genets (40% chance)
  const aliases = rng() < 0.4 ? {
    [`alias-${species.code.toLowerCase()}-${index + 1}`]: `Alt ID ${index + 1}`,
  } : {};

  const genet = {
    id: genetId,
    name: localId,
    nameLowercase: localId.toLowerCase(),
    localId,
    speciesId: species.id,
    provenanceTypeId: provenanceType,
    provenanceKind: 'genet',
    lineageKind: 'genet',
    provenanceId: `PID-${species.demoCode}-${String(index + 1).padStart(4, '0')}`,
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
    ...(Object.keys(aliases).length > 0 && { aliases }),
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
  const outplantFunder = funders[0] || null;
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
      ...(outplantFunder?.id ? { funderId: outplantFunder.id } : {}),
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

  // Create organism observation events for husbandry health analytics (Pro/Scale tiers)
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

  // Create maintenance required observation events for husbandry analytics (Pro/Scale tiers)
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

  // Create propagation events (fragmentation) for Pro/Scale tiers
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

async function createChatRoomsAndMessages(orgId, userId, sites, rng, baseDate, now) {
  const orgRef = db.collection('organizations').doc(orgId);
  let roomCount = 0;
  let messageCount = 0;

  // Staff names for varied authorship
  const staffMembers = [
    { id: userId, name: 'Demo User' },
    { id: 'staff_sarah', name: 'Sarah Chen' },
    { id: 'staff_marcus', name: 'Marcus Rodriguez' },
    { id: 'staff_emily', name: 'Emily Watson' },
    { id: 'staff_james', name: 'James Park' },
  ];

  // Chat room templates
  const roomTemplates = [
    { suffix: 'general', name: 'General Discussion', description: 'General chat for site operations' },
    { suffix: 'tasks', name: 'Task Coordination', description: 'Coordinate daily tasks and schedules' },
    { suffix: 'alerts', name: 'Alerts & Monitoring', description: 'Important alerts and monitoring updates' },
  ];

  // Message templates by room type
  const generalMessages = [
    'Good morning team! Ready for another day.',
    'Anyone need help with tank maintenance today?',
    'Just finished the morning rounds - all systems nominal.',
    'Heads up: visitor tour at 2pm today.',
    'Great work on the water quality tests everyone!',
    'Coffee run - anyone want anything?',
    'New equipment arrived, will set it up this afternoon.',
    'Reminder: team meeting tomorrow at 9am.',
    'The new coral shipment looks amazing!',
    'Weather report says calm seas all week - perfect for fieldwork.',
  ];

  const taskMessages = [
    'Starting tank 3 cleaning now.',
    'Finished fragmentation - 24 new pieces from ACER broodstock.',
    'Water change complete in all nursery tanks.',
    'Need someone to cover the afternoon feeding.',
    'Photo documentation done for this week.',
    'Equipment maintenance scheduled for Thursday.',
    'All morning tasks completed ahead of schedule!',
    'Can someone help move the coral trees?',
    'Filter replacement done on racks 1-4.',
    'Growth measurements logged in the system.',
  ];

  const alertMessages = [
    '⚠️ Temperature spike in tank 2 - checking chiller.',
    '✅ Chiller fixed, temps returning to normal.',
    'pH slightly elevated in nursery - monitoring.',
    '🔔 Reminder: high tide at 3:45pm today.',
    '✅ All parameters back to normal ranges.',
    'Noticed some algae growth on rack 3 - will treat today.',
    '⚠️ Pump noise in tank 4 - scheduled maintenance.',
    'Storm warning for this weekend - securing equipment.',
    '✅ Weekly backup generator test passed.',
    'New disease observation protocol now in effect.',
  ];

  const messagesByType = {
    general: generalMessages,
    tasks: taskMessages,
    alerts: alertMessages,
  };

  // Common reactions
  const reactionEmojis = ['👍', '✅', '❤️', '🎉', '👀', '🙏'];

  // Create chat rooms for each site
  for (const [siteKey, site] of Object.entries(sites)) {
    for (const template of roomTemplates) {
      const roomId = orgRef.collection('chat_rooms').doc().id;
      const roomSlug = `${site.slug}-${template.suffix}`;

      const room = {
        id: roomId,
        organizationId: orgId,
        siteId: site.id,
        name: `${site.name} - ${template.name}`,
        description: template.description,
        memberIds: [], // Open to all site members
        createdAt: now,
        createdById: userId,
        // These will be updated after messages are created
        lastMessageAt: now,
        lastMessagePreview: '',
        lastMessageSenderId: userId,
      };

      await orgRef.collection('chat_rooms').doc(roomId).set(room);
      roomCount++;

      // Create messages for this room
      const messagePool = messagesByType[template.suffix] || generalMessages;
      const numMessages = 5 + Math.floor(rng() * 10); // 5-14 messages per room

      // Track the most recent message for room metadata update
      let lastMessage = null;
      let lastMessageTime = null;

      for (let m = 0; m < numMessages; m++) {
        const messageId = orgRef.collection('chat_messages').doc().id;
        const sender = pickRandom(staffMembers, rng);
        const content = pickRandom(messagePool, rng);

        // Stagger message times: older messages first, newer at the end
        // Each message is 1-6 hours after the previous one
        const messageDate = new Date(baseDate);
        const hoursBack = (numMessages - m - 1) * (1 + Math.floor(rng() * 5));
        messageDate.setTime(messageDate.getTime() - hoursBack * 60 * 60 * 1000);

        const message = {
          id: messageId,
          roomId,
          organizationId: orgId,
          senderId: sender.id,
          senderName: sender.name,
          content,
          createdAt: messageDate.toISOString(),
          mentions: [],
          attachments: [],
          reactions: {},
          readBy: [sender.id],
          isDeleted: false,
          isEdited: false,
        };

        // Add reactions to some messages (40% chance)
        if (rng() > 0.6) {
          const numReactions = 1 + Math.floor(rng() * 3); // 1-3 reactions
          for (let r = 0; r < numReactions; r++) {
            const emoji = pickRandom(reactionEmojis, rng);
            const reactor = pickRandom(staffMembers, rng);
            if (!message.reactions[emoji]) {
              message.reactions[emoji] = [];
            }
            if (!message.reactions[emoji].includes(reactor.id)) {
              message.reactions[emoji].push(reactor.id);
            }
          }
        }

        await orgRef.collection('chat_messages').doc(messageId).set(message);
        messageCount++;

        // Track the most recent message (last iteration has newest time)
        if (!lastMessageTime || messageDate > lastMessageTime) {
          lastMessage = message;
          lastMessageTime = messageDate;
        }
      }

      // Update room with actual last message info
      if (lastMessage) {
        await orgRef.collection('chat_rooms').doc(roomId).update({
          lastMessageAt: lastMessage.createdAt,
          lastMessagePreview: lastMessage.content.length > 100
            ? lastMessage.content.substring(0, 100) + '...'
            : lastMessage.content,
          lastMessageSenderId: lastMessage.senderId,
        });
      }
    }
  }

  return { roomCount, messageCount };
}

async function createComments(orgId, userId, events, rng, baseDate, now) {
  const orgRef = db.collection('organizations').doc(orgId);
  let commentCount = 0;

  // Comment templates for different event types
  const taskComments = [
    'Started working on this today.',
    'Making good progress, about halfway done.',
    'Completed ahead of schedule!',
    'Had to pause - waiting for supplies to arrive.',
    'This took longer than expected due to equipment issues.',
    'All done! Everything looks great.',
    'Quick update: found some issues that need attention.',
    'Will finish this tomorrow morning.',
    'Great job team! This was a big one.',
    'Note: added some extra maintenance while I was at it.',
    'Flagging this for review - noticed something unusual.',
    'Running behind on this one, will update soon.',
    'Need help with this task - anyone available?',
    'Photos uploaded to shared drive.',
    'Documenting this for the weekly report.',
  ];

  const husbandryComments = [
    'Good observations! I noticed similar patterns last week.',
    'Should we adjust the parameters based on this?',
    'Thanks for the detailed notes.',
    'Following up on this tomorrow.',
    'I\'ll add more data points to track this trend.',
    'Great catch on the bleaching signs.',
    'Let\'s discuss this at the team meeting.',
    'Added this to the monitoring checklist.',
    'Water chemistry has been tricky this month.',
    'Agree with your assessment. Continuing to monitor.',
  ];

  const outplantComments = [
    'Excellent survival rates so far!',
    'Weather conditions were perfect for this event.',
    'Team did an amazing job with the installation.',
    'Follow-up monitoring scheduled for next month.',
    'Some fragments need repositioning - will handle on next dive.',
    'GPS coordinates logged and verified.',
    'Visibility was great, got good photo documentation.',
    'All genets successfully deployed.',
  ];

  // Staff names for varied authorship
  const staffNames = [
    'Sarah Chen',
    'Marcus Rodriguez',
    'Emily Watson',
    'James Park',
    'Alex Thompson',
  ];

  // Add comments to events
  for (const event of events) {
    // Determine how many comments this event gets (0-4)
    const numComments = Math.floor(rng() * 5);
    if (numComments === 0) continue;

    // Pick appropriate comments based on event type
    let commentPool;
    if (event.eventTypeId === 'event_task') {
      commentPool = taskComments;
    } else if (event.eventTypeId === 'event_husbandry_log') {
      commentPool = husbandryComments;
    } else if (event.eventTypeId === 'event_outplant') {
      commentPool = outplantComments;
    } else {
      commentPool = taskComments; // fallback
    }

    let lastCommentId = null;
    for (let c = 0; c < numComments; c++) {
      const commentId = orgRef.collection('comments').doc().id;

      // Stagger comment times after event creation
      const commentDate = new Date(event.createdAt);
      commentDate.setHours(commentDate.getHours() + Math.floor(rng() * 48) + (c * 2));

      // Sometimes make it a reply to previous comment (30% chance if there's a previous comment)
      const isReply = lastCommentId && rng() < 0.3;
      const authorName = pickRandom(staffNames, rng);
      const content = pickRandom(commentPool, rng);

      const comment = {
        id: commentId,
        organizationId: orgId,
        targetType: 'event',
        targetId: event.id,
        authorUid: userId,
        authorName,
        content,
        createdAt: commentDate.toISOString(),
        mentions: [],
        reactions: {},
        isEdited: false,
        isDeleted: false,
      };

      if (isReply) {
        comment.parentCommentId = lastCommentId;
      }

      // Add occasional reactions
      if (rng() > 0.7) {
        const reactions = {};
        if (rng() > 0.5) reactions['👍'] = [userId];
        if (rng() > 0.7) reactions['✅'] = [userId];
        if (rng() > 0.8) reactions['🎉'] = [userId];
        if (Object.keys(reactions).length > 0) {
          comment.reactions = reactions;
        }
      }

      await orgRef.collection('comments').doc(commentId).set(comment);
      lastCommentId = commentId;
      commentCount++;
    }
  }

  return commentCount;
}

// ============================================================================
// Sexual Cohort and Graduated Individual Functions
// ============================================================================

/**
 * Create sexual cohort organisms from cross events.
 * Cohorts use larva/embryo/juvenile life stages with appropriate physical forms.
 */
async function createSexualCohortOrganisms({
  orgId,
  userId,
  sites,
  crossEvents,
  gameteOrganisms,
  rng,
  baseDate,
  now,
}) {
  const orgRef = db.collection('organizations').doc(orgId);
  const cohortOrganisms = [];

  const geneBankSite = sites.geneBank;
  if (!geneBankSite || crossEvents.length === 0) {
    console.log('WARN: No gene bank site or cross events; skipping cohort creation.');
    return cohortOrganisms;
  }

  // Get groups from gene bank for cohort placement
  const groupsSnap = await orgRef.collection('groups')
    .where('siteId', '==', geneBankSite.id)
    .limit(5)
    .get();
  const groups = groupsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  for (let i = 0; i < crossEvents.length; i++) {
    const crossEvent = crossEvents[i];
    const speciesCode = crossEvent.metadata?.speciesCode || 'APAL';
    const speciesId = crossEvent.metadata?.speciesId || 'apal';
    const speciesName = crossEvent.metadata?.speciesName || 'Acropora palmata';

    // Find dam and sire organisms for this cross
    const damId = crossEvent.damIds?.[0];
    const sireId = crossEvent.sireIds?.[0];

    // Create 2-4 cohort organisms per cross (larvae batches)
    const cohortCount = 2 + Math.floor(rng() * 3);

    for (let j = 0; j < cohortCount; j++) {
      const organismId = orgRef.collection('organismRecords').doc().id;
      const targetGroup = groups.length > 0 ? groups[(i + j) % groups.length] : null;

      // Cohorts should be larva, embryo, or juvenile (NOT adult/broodstock)
      const lifeStageRoll = rng();
      let lifeStage;
      let physicalFormProfile;
      if (lifeStageRoll < 0.4) {
        lifeStage = LIFE_STAGES.larva;
        physicalFormProfile = PHYSICAL_FORM_PROFILES.larva;
      } else if (lifeStageRoll < 0.7) {
        lifeStage = LIFE_STAGES.embryo;
        physicalFormProfile = PHYSICAL_FORM_PROFILES.embryo;
      } else {
        lifeStage = LIFE_STAGES.juvenile;
        physicalFormProfile = PHYSICAL_FORM_PROFILES.juvenile;
      }

      const physicalForm = pickRandom(physicalFormProfile, rng) || { formId: 'larval_container', sizeBandId: 'small' };
      const cohortIndex = i * cohortCount + j + 1;
      const localId = `${speciesCode}-COH-${String(cohortIndex).padStart(4, '0')}`;
      const slug = localId.toLowerCase();
      const recordName = deriveRecordName(localId, 1) || `Cohort ${cohortIndex}`;

      // Cohort creation date is after cross event
      const crossDate = new Date(crossEvent.createdAt);
      const createdDate = new Date(crossDate);
      createdDate.setDate(createdDate.getDate() + 7 + Math.floor(rng() * 14));

      const cohortQuantity = 100 + Math.floor(rng() * 900); // 100-999 larvae/embryos
      const cohortMetrics = calculateInventoryMetrics(physicalForm, cohortQuantity);

      const organism = {
        id: organismId,
        recordName,
        localId,
        genetId: null, // Cohorts don't have a single genet
        speciesId,
        siteId: geneBankSite.id,
        groupId: targetGroup?.id || null,
        lifeStage: { id: lifeStage },
        lifeStageId: lifeStage,
        provenanceType: PROVENANCE_TYPES.sexualCohort,
        provenanceTypeId: PROVENANCE_TYPES.sexualCohort,
        provenanceAttributes: {
          damIds: damId ? [damId] : [],
          sireIds: sireId ? [sireId] : [],
          crossEventId: crossEvent.id,
        },
        organismKind: 'coral',
        organizationId: orgId,
        modelType: 'organismRecord',
        slug,
        urlPath: targetGroup ? `${targetGroup.urlPath}/${slug}` : `${geneBankSite.urlPath}/${slug}`,
        internalPath: `organizations/${orgId}/organismRecords/${organismId}`,
        createdAt: createdDate.toISOString(),
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
        measurement: {
          value: cohortQuantity,
          unit: 'count',
        },
        physicalForm,
        physicalFormConfigVersion: 'v1',
        // Inventory metrics fields
        ...cohortMetrics,
        metadata: {
          crossEventId: crossEvent.id,
          speciesCode,
          speciesName,
          healthStatus: 'healthy',
        },
      };

      await orgRef.collection('organismRecords').doc(organismId).set(organism);
      cohortOrganisms.push(organism);
    }
  }

  return cohortOrganisms;
}

/**
 * Create graduated individual organisms from cohorts.
 * Graduated individuals have adult/broodstock life stages and link to source cohort.
 */
async function createGraduatedIndividuals({
  orgId,
  userId,
  sites,
  cohortOrganisms,
  genets,
  rng,
  baseDate,
  now,
}) {
  const orgRef = db.collection('organizations').doc(orgId);
  const graduatedOrganisms = [];

  if (cohortOrganisms.length === 0) {
    console.log('WARN: No cohort organisms; skipping graduated individual creation.');
    return graduatedOrganisms;
  }

  // Use nursery sites for graduated individuals
  const nurserySite = sites.nurseryLand || sites.nurseryField || sites.geneBank;
  if (!nurserySite) {
    console.log('WARN: No nursery site; skipping graduated individual creation.');
    return graduatedOrganisms;
  }

  // Get groups from nursery for placement
  const groupsSnap = await orgRef.collection('groups')
    .where('siteId', '==', nurserySite.id)
    .limit(10)
    .get();
  const groups = groupsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  // Create 2-3 graduated individuals per tier (total of 6-9)
  const graduateCount = Math.min(cohortOrganisms.length, 6 + Math.floor(rng() * 4));

  for (let i = 0; i < graduateCount; i++) {
    const sourceCohort = cohortOrganisms[i % cohortOrganisms.length];
    const organismId = orgRef.collection('organismRecords').doc().id;
    const targetGroup = groups.length > 0 ? groups[i % groups.length] : null;

    // Graduated individuals should be adult or broodstock
    const lifeStage = rng() < 0.7 ? LIFE_STAGES.adult : LIFE_STAGES.broodstock;
    const physicalFormProfile = lifeStage === LIFE_STAGES.broodstock
      ? PHYSICAL_FORM_PROFILES.broodstock
      : PHYSICAL_FORM_PROFILES.adult;
    const physicalForm = pickRandom(physicalFormProfile, rng) || { formId: 'fragment', sizeBandId: 'medium' };

    const speciesCode = sourceCohort.metadata?.speciesCode || 'APAL';
    const speciesId = sourceCohort.speciesId || 'apal';
    const localId = `${speciesCode}-GRD-${String(i + 1).padStart(4, '0')}`;
    const slug = localId.toLowerCase();
    const recordName = deriveRecordName(localId, 1) || `Graduate ${i + 1}`;

    // Assign a genet from the available genets of same species
    const speciesGenets = genets.filter((g) => g.speciesId === speciesId);
    const assignedGenet = pickRandom(speciesGenets, rng);

    // Graduated date is later than cohort creation
    const cohortDate = new Date(sourceCohort.createdAt);
    const graduatedDate = new Date(cohortDate);
    graduatedDate.setDate(graduatedDate.getDate() + 90 + Math.floor(rng() * 180)); // 3-9 months later

    // Graduated individuals are single organisms
    const graduatedMetrics = calculateInventoryMetrics(physicalForm, 1);

    const organism = {
      id: organismId,
      recordName,
      localId,
      genetId: assignedGenet?.id || null,
      foreignKeys: assignedGenet ? {
        genetId: { id: assignedGenet.id, collection: 'genets' },
      } : {},
      speciesId,
      siteId: nurserySite.id,
      groupId: targetGroup?.id || null,
      lifeStage: { id: lifeStage },
      lifeStageId: lifeStage,
      provenanceType: PROVENANCE_TYPES.graduatedIndividual,
      provenanceTypeId: PROVENANCE_TYPES.graduatedIndividual,
      provenanceAttributes: {
        sourceOrganismId: sourceCohort.id,
        sourceProvenanceType: PROVENANCE_TYPES.sexualCohort,
        graduatedAt: graduatedDate.toISOString(),
      },
      organismKind: 'coral',
      organizationId: orgId,
      modelType: 'organismRecord',
      slug,
      urlPath: targetGroup ? `${targetGroup.urlPath}/${slug}` : `${nurserySite.urlPath}/${slug}`,
      internalPath: `organizations/${orgId}/organismRecords/${organismId}`,
      createdAt: graduatedDate.toISOString(),
      updatedAt: now,
      createdById: userId,
      updatedById: userId,
      measurement: {
        value: 1,
        unit: 'count',
      },
      physicalForm,
      physicalFormConfigVersion: 'v1',
      // Inventory metrics fields
      ...graduatedMetrics,
      metadata: {
        sourceOrganismId: sourceCohort.id,
        sourceCohortLocalId: sourceCohort.localId,
        speciesCode,
        healthStatus: 'healthy',
        readyForOutplant: rng() > 0.5,
        readyForPropagation: rng() > 0.7,
      },
    };

    await orgRef.collection('organismRecords').doc(organismId).set(organism);
    graduatedOrganisms.push(organism);
  }

  return graduatedOrganisms;
}

// ============================================================================
// Multi-Organism Kind Support
// ============================================================================

/**
 * Create sites for non-coral organisms (oyster, kelp, seagrass).
 */
async function createNonCoralSites(orgId, userId, now, orgUrlPrefix) {
  const sites = {};
  const basePath = normalizeUrlPrefix(orgUrlPrefix || orgId);

  const siteData = [
    // Oyster sites
    {
      key: 'oysterHatchery',
      name: 'Oyster Hatchery',
      typeId: SITE_TYPES.hatchery,
      lat: 28.0836,
      lng: -80.6081,
      groupIdHierarchy: [GROUP_TYPES.tank, GROUP_TYPES.tray],
    },
    {
      key: 'oysterReef',
      name: 'Oyster Reef Restoration Site',
      typeId: SITE_TYPES.reefAquaculture,
      lat: 28.0915,
      lng: -80.6142,
      groupIdHierarchy: [GROUP_TYPES.rack],
    },
    // Kelp sites
    {
      key: 'kelpFarm',
      name: 'Kelp Farm Alpha',
      typeId: SITE_TYPES.kelpFarm,
      lat: 36.9522,
      lng: -122.0268,
      groupIdHierarchy: [GROUP_TYPES.longline],
    },
    // Seagrass sites
    {
      key: 'seagrassPlot',
      name: 'Seagrass Restoration Plot',
      typeId: SITE_TYPES.seagrassPlot,
      lat: 27.4699,
      lng: -80.3241,
      groupIdHierarchy: [GROUP_TYPES.plotTransect],
    },
  ];

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

/**
 * Create groups and organisms for non-coral organism kinds.
 */
async function createNonCoralOrganisms({
  orgId,
  userId,
  sites,
  rng,
  baseDate,
  now,
  tier,
}) {
  const orgRef = db.collection('organizations').doc(orgId);
  const organisms = [];
  let groupCount = 0;

  // Skip for community tier
  if (tier === 'community') {
    console.log('INFO: Skipping non-coral organisms for community tier.');
    return { organisms, groupCount };
  }

  // Oyster organisms
  const oysterSite = sites.oysterHatchery || sites.oysterReef;
  if (oysterSite) {
    // Create groups for oyster site
    const oysterGroups = [];
    const structureCount = tier === 'scale' ? 3 : 2;
    for (let s = 0; s < structureCount; s++) {
      const groupId = orgRef.collection('groups').doc().id;
      const groupName = `Larval Tank ${s + 1}`;
      const groupSlug = `${oysterSite.slug}-larval-tank-${s + 1}`;
      const group = {
        id: groupId,
        name: groupName,
        groupTypeId: GROUP_TYPES.tank,
        siteId: oysterSite.id,
        parentId: oysterSite.id,
        organizationId: orgId,
        modelType: 'group',
        slug: groupSlug,
        urlPath: `${oysterSite.urlPath}/${groupSlug}`,
        internalPath: `organizations/${orgId}/groups/${groupId}`,
        createdAt: now,
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
      };
      await orgRef.collection('groups').doc(groupId).set(group);
      oysterGroups.push(group);
      groupCount++;
    }

    // Create oyster organisms
    const oysterSpecies = [SPECIES.cvir, SPECIES.cgig];
    const oysterCount = tier === 'scale' ? 4 : 2;

    for (let i = 0; i < oysterCount; i++) {
      const species = oysterSpecies[i % oysterSpecies.length];
      const group = oysterGroups[i % oysterGroups.length];

      // Life stage varies
      const lifeStageRoll = rng();
      let lifeStage;
      let physicalFormProfile;
      if (lifeStageRoll < 0.3) {
        lifeStage = LIFE_STAGES.larva;
        physicalFormProfile = OYSTER_PHYSICAL_FORM_PROFILES.larva;
      } else if (lifeStageRoll < 0.6) {
        lifeStage = LIFE_STAGES.juvenile;
        physicalFormProfile = OYSTER_PHYSICAL_FORM_PROFILES.juvenile;
      } else if (lifeStageRoll < 0.85) {
        lifeStage = LIFE_STAGES.adult;
        physicalFormProfile = OYSTER_PHYSICAL_FORM_PROFILES.adult;
      } else {
        lifeStage = LIFE_STAGES.broodstock;
        physicalFormProfile = OYSTER_PHYSICAL_FORM_PROFILES.broodstock;
      }

      const physicalForm = pickRandom(physicalFormProfile, rng) || { formId: 'individual', sizeBandId: 'medium' };
      const organismId = orgRef.collection('organismRecords').doc().id;
      const localId = `${species.code}-OYS-${String(i + 1).padStart(3, '0')}`;
      const slug = localId.toLowerCase();
      const recordName = deriveRecordName(localId, 1) || `Oyster ${i + 1}`;

      const oysterQuantity = lifeStage === LIFE_STAGES.larva ? 1000 + Math.floor(rng() * 9000) : 1 + Math.floor(rng() * 50);
      const oysterMetrics = calculateInventoryMetrics(physicalForm, oysterQuantity);

      const organism = {
        id: organismId,
        recordName,
        localId,
        speciesId: species.id,
        siteId: oysterSite.id,
        groupId: group.id,
        lifeStage: { id: lifeStage },
        lifeStageId: lifeStage,
        provenanceType: PROVENANCE_TYPES.wild,
        provenanceTypeId: PROVENANCE_TYPES.wild,
        organismKind: ORGANISM_KINDS.oyster,
        organizationId: orgId,
        modelType: 'organismRecord',
        slug,
        urlPath: `${group.urlPath}/${slug}`,
        internalPath: `organizations/${orgId}/organismRecords/${organismId}`,
        createdAt: now,
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
        measurement: {
          value: oysterQuantity,
          unit: 'count',
        },
        physicalForm,
        physicalFormConfigVersion: 'v1',
        // Inventory metrics fields
        ...oysterMetrics,
        metadata: {
          speciesCode: species.code,
          speciesName: species.name,
          healthStatus: 'healthy',
        },
      };

      await orgRef.collection('organismRecords').doc(organismId).set(organism);
      organisms.push(organism);
    }
  }

  // Kelp organisms
  const kelpSite = sites.kelpFarm;
  if (kelpSite) {
    // Create groups for kelp site
    const kelpGroups = [];
    const longlineCount = tier === 'scale' ? 3 : 2;
    for (let s = 0; s < longlineCount; s++) {
      const groupId = orgRef.collection('groups').doc().id;
      const groupName = `Longline ${s + 1}`;
      const groupSlug = `${kelpSite.slug}-longline-${s + 1}`;
      const group = {
        id: groupId,
        name: groupName,
        groupTypeId: GROUP_TYPES.longline,
        siteId: kelpSite.id,
        parentId: kelpSite.id,
        organizationId: orgId,
        modelType: 'group',
        slug: groupSlug,
        urlPath: `${kelpSite.urlPath}/${groupSlug}`,
        internalPath: `organizations/${orgId}/groups/${groupId}`,
        createdAt: now,
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
      };
      await orgRef.collection('groups').doc(groupId).set(group);
      kelpGroups.push(group);
      groupCount++;
    }

    // Create kelp organisms
    const kelpSpecies = [SPECIES.mpyr, SPECIES.slat];
    const kelpCount = tier === 'scale' ? 3 : 2;

    for (let i = 0; i < kelpCount; i++) {
      const species = kelpSpecies[i % kelpSpecies.length];
      const group = kelpGroups[i % kelpGroups.length];

      // Kelp life stages
      const lifeStageRoll = rng();
      let lifeStage;
      let physicalFormProfile;
      if (lifeStageRoll < 0.4) {
        lifeStage = LIFE_STAGES.juvenile;
        physicalFormProfile = KELP_PHYSICAL_FORM_PROFILES.juvenile;
      } else {
        lifeStage = LIFE_STAGES.adult;
        physicalFormProfile = KELP_PHYSICAL_FORM_PROFILES.adult;
      }

      const physicalForm = pickRandom(physicalFormProfile, rng) || { formId: 'seeded_twine', sizeBandId: 'medium' };
      const organismId = orgRef.collection('organismRecords').doc().id;
      const localId = `${species.code}-KLP-${String(i + 1).padStart(3, '0')}`;
      const slug = localId.toLowerCase();
      const recordName = deriveRecordName(localId, 1) || `Kelp ${i + 1}`;

      const kelpQuantity = 5 + Math.floor(rng() * 20);
      const kelpMetrics = calculateInventoryMetrics(physicalForm, kelpQuantity);

      const organism = {
        id: organismId,
        recordName,
        localId,
        speciesId: species.id,
        siteId: kelpSite.id,
        groupId: group.id,
        lifeStage: { id: lifeStage },
        lifeStageId: lifeStage,
        provenanceType: PROVENANCE_TYPES.wild,
        provenanceTypeId: PROVENANCE_TYPES.wild,
        organismKind: ORGANISM_KINDS.kelp,
        organizationId: orgId,
        modelType: 'organismRecord',
        slug,
        urlPath: `${group.urlPath}/${slug}`,
        internalPath: `organizations/${orgId}/organismRecords/${organismId}`,
        createdAt: now,
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
        measurement: {
          value: kelpQuantity,
          unit: 'count',
        },
        physicalForm,
        physicalFormConfigVersion: 'v1',
        // Inventory metrics fields
        ...kelpMetrics,
        metadata: {
          speciesCode: species.code,
          speciesName: species.name,
          healthStatus: 'healthy',
        },
      };

      await orgRef.collection('organismRecords').doc(organismId).set(organism);
      organisms.push(organism);
    }
  }

  // Seagrass organisms
  const seagrassSite = sites.seagrassPlot;
  if (seagrassSite) {
    // Create groups for seagrass site
    const seagrassGroups = [];
    const plotCount = tier === 'scale' ? 3 : 2;
    for (let s = 0; s < plotCount; s++) {
      const groupId = orgRef.collection('groups').doc().id;
      const groupName = `Plot Transect ${s + 1}`;
      const groupSlug = `${seagrassSite.slug}-plot-${s + 1}`;
      const group = {
        id: groupId,
        name: groupName,
        groupTypeId: GROUP_TYPES.plotTransect,
        siteId: seagrassSite.id,
        parentId: seagrassSite.id,
        organizationId: orgId,
        modelType: 'group',
        slug: groupSlug,
        urlPath: `${seagrassSite.urlPath}/${groupSlug}`,
        internalPath: `organizations/${orgId}/groups/${groupId}`,
        createdAt: now,
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
      };
      await orgRef.collection('groups').doc(groupId).set(group);
      seagrassGroups.push(group);
      groupCount++;
    }

    // Create seagrass organisms
    const seagrassSpecies = [SPECIES.ttes, SPECIES.zwri];
    const seagrassCount = tier === 'scale' ? 3 : 2;

    for (let i = 0; i < seagrassCount; i++) {
      const species = seagrassSpecies[i % seagrassSpecies.length];
      const group = seagrassGroups[i % seagrassGroups.length];

      // Seagrass life stages
      const lifeStageRoll = rng();
      let lifeStage;
      let physicalFormProfile;
      if (lifeStageRoll < 0.4) {
        lifeStage = LIFE_STAGES.juvenile;
        physicalFormProfile = SEAGRASS_PHYSICAL_FORM_PROFILES.juvenile;
      } else {
        lifeStage = LIFE_STAGES.adult;
        physicalFormProfile = SEAGRASS_PHYSICAL_FORM_PROFILES.adult;
      }

      const physicalForm = pickRandom(physicalFormProfile, rng) || { formId: 'individual', sizeBandId: 'medium' };
      const organismId = orgRef.collection('organismRecords').doc().id;
      const localId = `${species.code}-SGR-${String(i + 1).padStart(3, '0')}`;
      const slug = localId.toLowerCase();
      const recordName = deriveRecordName(localId, 1) || `Seagrass ${i + 1}`;

      const seagrassQuantity = 20 + Math.floor(rng() * 100);
      const seagrassMetrics = calculateInventoryMetrics(physicalForm, seagrassQuantity);

      const organism = {
        id: organismId,
        recordName,
        localId,
        speciesId: species.id,
        siteId: seagrassSite.id,
        groupId: group.id,
        lifeStage: { id: lifeStage },
        lifeStageId: lifeStage,
        provenanceType: PROVENANCE_TYPES.wild,
        provenanceTypeId: PROVENANCE_TYPES.wild,
        organismKind: ORGANISM_KINDS.seagrass,
        organizationId: orgId,
        modelType: 'organismRecord',
        slug,
        urlPath: `${group.urlPath}/${slug}`,
        internalPath: `organizations/${orgId}/organismRecords/${organismId}`,
        createdAt: now,
        updatedAt: now,
        createdById: userId,
        updatedById: userId,
        measurement: {
          value: seagrassQuantity,
          unit: 'count',
        },
        physicalForm,
        physicalFormConfigVersion: 'v1',
        // Inventory metrics fields
        ...seagrassMetrics,
        metadata: {
          speciesCode: species.code,
          speciesName: species.name,
          healthStatus: 'healthy',
        },
      };

      await orgRef.collection('organismRecords').doc(organismId).set(organism);
      organisms.push(organism);
    }
  }

  return { organisms, groupCount };
}

/**
 * Create additional monitoring and husbandry events for organisms.
 */
async function createAdditionalEvents({
  orgId,
  userId,
  organisms,
  rng,
  baseDate,
  now,
  tier,
}) {
  const events = [];

  if (tier === 'community') {
    console.log('INFO: Skipping additional events for community tier.');
    return events;
  }

  // Create size change events for some organisms
  const sizeChangeCount = tier === 'scale' ? 8 : 4;
  const sizeTargets = organisms.slice(0, Math.min(organisms.length, sizeChangeCount));

  for (let i = 0; i < sizeTargets.length; i++) {
    const organism = sizeTargets[i];
    const eventId = db.collection('events').doc().id;
    const slug = `size-change-${organism.slug || eventId.slice(0, 6)}`;

    const eventDate = new Date(baseDate);
    eventDate.setDate(eventDate.getDate() - Math.floor(rng() * 30));

    const oldSizeBand = organism.physicalForm?.sizeBandId || 'small';
    const sizeBands = ['xs', 'small', 'medium', 'large', 'xl'];
    const oldIndex = sizeBands.indexOf(oldSizeBand);
    const newIndex = Math.min(oldIndex + 1, sizeBands.length - 1);
    const newSizeBand = sizeBands[newIndex];

    const event = {
      id: eventId,
      modelType: 'event',
      eventTypeId: 'event_size_change',
      organizationId: orgId,
      createdAt: eventDate.toISOString(),
      updatedAt: eventDate.toISOString(),
      createdById: userId,
      updatedById: userId,
      recordId: organism.id,
      recordModelType: 'organismRecord',
      slug,
      urlPath: `${organism.urlPath}/events/${slug}`,
      internalPath: `organizations/${orgId}/events/${eventId}`,
      oldSize: {
        sizeBandId: oldSizeBand,
      },
      newSize: {
        sizeBandId: newSizeBand,
      },
      organismRecordSnapshot: {
        id: organism.id,
        modelType: 'organismRecord',
        organismKind: organism.organismKind || 'coral',
        recordName: organism.recordName || organism.name || 'Unknown',
        localId: organism.localId || 'UNKNOWN',
        siteId: organism.siteId || '',
        groupId: organism.groupId || '',
        organizationId: orgId,
        urlPath: organism.urlPath || '',
        internalPath: organism.internalPath || '',
        slug: organism.slug || '',
        createdAt: organism.createdAt || eventDate.toISOString(),
        updatedAt: organism.updatedAt || eventDate.toISOString(),
        createdById: userId,
        updatedById: userId,
        physicalForm: organism.physicalForm || { formId: 'fragment' },
        lifeStage: organism.lifeStage || { stage: 'juvenile' },
        measurement: organism.measurement || { value: 1, unit: 'count' },
      },
      notes: `Size increased from ${oldSizeBand} to ${newSizeBand}.`,
      metadata: {
        organismKind: organism.organismKind || 'coral',
        organismRecordId: organism.id,
      },
    };

    await db.collection('events').doc(eventId).set(event);
    events.push(event);
  }

  // Create mortality events for some organisms
  const mortalityCount = tier === 'scale' ? 3 : 1;
  const mortalityTargets = organisms.slice(
    Math.floor(organisms.length / 2),
    Math.floor(organisms.length / 2) + mortalityCount,
  );

  for (let i = 0; i < mortalityTargets.length; i++) {
    const organism = mortalityTargets[i];
    const eventId = db.collection('events').doc().id;
    const slug = `mortality-${organism.slug || eventId.slice(0, 6)}`;

    const eventDate = new Date(baseDate);
    eventDate.setDate(eventDate.getDate() - Math.floor(rng() * 60));

    const mortalityCauses = [
      'mortality_cause_disease',
      'mortality_cause_bleaching',
      'mortality_cause_predation',
      'mortality_cause_storm_damage',
      'mortality_cause_unknown',
    ];
    const cause = mortalityCauses[Math.floor(rng() * mortalityCauses.length)];
    const mortalityCount = 1 + Math.floor(rng() * 3);

    const event = {
      id: eventId,
      modelType: 'event',
      eventTypeId: 'event_population_loss',
      organizationId: orgId,
      createdAt: eventDate.toISOString(),
      updatedAt: eventDate.toISOString(),
      createdById: userId,
      updatedById: userId,
      recordId: organism.id,
      recordModelType: 'organismRecord',
      slug,
      urlPath: `${organism.urlPath}/events/${slug}`,
      internalPath: `organizations/${orgId}/events/${eventId}`,
      lossCauseId: cause,
      lossCount: mortalityCount,
      notes: `${mortalityCount} organism(s) lost due to ${cause.replace('mortality_cause_', '').replace(/_/g, ' ')}.`,
      metadata: {
        organismKind: organism.organismKind || 'coral',
        organismRecordId: organism.id,
        mortalityCause: cause,
      },
    };

    await db.collection('events').doc(eventId).set(event);
    events.push(event);
  }

  return events;
}

async function main() {
  const orgId = argValue('--org');
  const userId = argValue('--user');
  const seed = argValue('--seed');
  const seedDate = argValue('--seed-date') || argValue('--seed_date');
  const tier = argValue('--tier') || 'scale';

  if (!orgId || !userId) {
    console.error('Usage: node scripts/seed-coral-inventory.js --org=ORG_ID --user=USER_ID [--seed=N] [--tier=community|pro|scale]');
    process.exit(1);
  }

  console.log(`INFO: Starting coral inventory seeding for org ${orgId} (${tier} tier)...`);

  try {
    const resolvedUser = await ensureUserAndMembership({ orgId, userId });
    await seedInventory({
      orgId,
      userId: resolvedUser.userId,
      seed,
      seedDate,
      tier,
      orgUrlPrefix: resolvedUser.orgUrlPrefix,
    });
    console.log('SEEDING_COMPLETE');
  } catch (error) {
    console.error('ERROR: Coral inventory seeding failed:', error.message || error);
    process.exit(1);
  }
}

main().then(() => process.exit(0));
