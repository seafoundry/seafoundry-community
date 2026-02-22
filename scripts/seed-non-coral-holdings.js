#!/usr/bin/env node

/**
 * Seed Non-Coral Holdings
 *
 * Seeds non-coral holdings (kelp seeded lines, oyster/seagrass gamete/larval batches)
 * for all organizations or a specific organization.
 *
 * NOTE: Production DB must be wiped/reset after Data Field Unification (SOT)
 * to ensure all data uses canonical fields (genetId top-level, physicalFormId,
 * SizeSpec format, no legacy fields).
 * 
 * Usage:
 *   node scripts/seed-non-coral-holdings.js [--org=ORG_ID] [--user=USER_ID] [--seed=SEED] [--seed-date=YYYY-MM-DD]
 *   node scripts/seed-non-coral-holdings.js --remove [--org=ORG_ID] [--user=USER_ID]
 * 
 * If no org/user provided, seeds for all organizations.
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { admin, db } = require('./config-json');

const args = process.argv.slice(2);
const shouldRemove = args.includes('--remove') || args.includes('--delete');

function argValue(prefix) {
  const match = args.find(arg => arg.startsWith(`${prefix}=`));
  if (!match) return null;
  return match.slice(prefix.length + 1);
}

function parseSeed(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseSeedDate(value) {
  if (!value || value.trim().length === 0) {
    return new Date(Date.UTC(2025, 0, 15));
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.valueOf())) {
    return new Date(Date.UTC(2025, 0, 15));
  }
  return parsed;
}

function makeRng(seedValue) {
  let seed = seedValue % 2147483647;
  if (seed <= 0) seed += 2147483646;
  return () => {
    seed = seed * 16807 % 2147483647;
    return (seed - 1) / 2147483646;
  };
}

function shuffle(list, rng) {
  const copy = list.slice();
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function loadAdjectives() {
  const adjectivesPath = path.join(
    __dirname,
    '../assets/wordlists/record_name_adjectives.txt',
  );
  if (!fs.existsSync(adjectivesPath)) {
    throw new Error(`Record name adjectives file not found at ${adjectivesPath}`);
  }
  const lines = fs.readFileSync(adjectivesPath, 'utf8')
    .split(/\r?\n/)
    .map(line => line.trim().toLowerCase())
    .filter(Boolean)
    .filter(line => !(line.startsWith('bay') && line.length > 3));
  if (!lines.length) {
    throw new Error('Record name adjective list is empty.');
  }
  return lines;
}

class RecordNameGenerator {
  constructor(adjectives, rng) {
    this.adjectives = shuffle(
      adjectives.map(value => value.trim().toLowerCase()).filter(Boolean),
      rng,
    );
    this.nextIndex = 0;
    this.speciesCounts = new Map();
    if (!this.adjectives.length) {
      throw new Error('Record name adjective list is empty.');
    }
  }

  nextForSpeciesCode(code) {
    const normalized = (code || 'unk').toLowerCase();
    const count = (this.speciesCounts.get(normalized) || 0) + 1;
    this.speciesCounts.set(normalized, count);
    const adjective = this.nextAdjective();
    // New recordName format: just capitalized adjective (e.g., "Crimson")
    // Append count suffix only if not the first occurrence (e.g., "Crimson2")
    const capitalized = adjective.charAt(0).toUpperCase() + adjective.slice(1);
    return count > 1 ? `${capitalized}${count}` : capitalized;
  }

  nextAdjective() {
    if (this.nextIndex >= this.adjectives.length) {
      throw new Error('Ran out of unique adjectives for recordName generation.');
    }
    const adjective = this.adjectives[this.nextIndex];
    this.nextIndex += 1;
    return adjective;
  }
}

function normalizeSpeciesCode(species) {
  return (species.code || species.id || 'UNK').toString();
}

function buildLocalId(speciesCode, prefix, index) {
  return `${speciesCode.toUpperCase()}-${prefix}-${String(index).padStart(3, '0')}`;
}

const orgId = argValue('--org');
const userId = argValue('--user');
const seed = parseSeed(argValue('--seed'), 7);
const seedDate = parseSeedDate(argValue('--seed-date') || argValue('--seed_date'));
const rng = makeRng(seed);
const recordNameGenerator = new RecordNameGenerator(loadAdjectives(), makeRng(seed + 1));
const rand = (max) => Math.floor(rng() * max);
const randDouble = (min, max) => rng() * (max - min) + min;
const dayMs = 24 * 60 * 60 * 1000;

// Site type IDs
const SITE_TYPES = {
  kelpFarm: 'site_type_kelp_farm',
  reefAquaculture: 'site_type_reef_aquaculture',
  seagrassPlot: 'site_type_seagrass_plot',
};

// Group type IDs
const GROUP_TYPES = {
  longline: 'group_type_longline',
  rack: 'group_type_rack',
  plotTransect: 'group_type_plot_transect',
};

// Organism kinds
const ORGANISM_KINDS = {
  kelp: 'kelp',
  oyster: 'oyster',
  seagrass: 'seagrass',
};

// Holding kinds
const HOLDING_KINDS = {
  seededLineBatch: 'seededLineBatch',
  gameteBatch: 'gameteBatch',
  larvalBatch: 'larvalBatch',
};

const NON_CORAL_ORGANISM_KINDS = new Set([
  ORGANISM_KINDS.kelp,
  ORGANISM_KINDS.oyster,
  ORGANISM_KINDS.seagrass,
]);

const NON_CORAL_HOLDING_KINDS = new Set([
  HOLDING_KINDS.seededLineBatch,
  HOLDING_KINDS.gameteBatch,
  HOLDING_KINDS.larvalBatch,
]);

const NON_CORAL_SITE_TYPE_IDS = new Set([
  SITE_TYPES.kelpFarm,
  SITE_TYPES.reefAquaculture,
  SITE_TYPES.seagrassPlot,
]);

const NON_CORAL_GROUP_TYPE_IDS = new Set([
  GROUP_TYPES.longline,
  GROUP_TYPES.rack,
  GROUP_TYPES.plotTransect,
]);

async function deleteMatchingDocs(docs, label) {
  if (!docs.length) return 0;
  const batchSize = 450;
  let deleted = 0;
  let batch = db.batch();
  let count = 0;

  for (const doc of docs) {
    batch.delete(doc.ref);
    deleted += 1;
    count += 1;
    if (count >= batchSize) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0) {
    await batch.commit();
  }

  if (deleted > 0) {
    console.log(`  🧹 Removed ${deleted} ${label}.`);
  }

  return deleted;
}

async function removeNonCoralHoldings(orgId) {
  console.log(`\n🧹 Removing non-coral sites and inventory for ${orgId}...`);
  const orgRef = db.collection('organizations').doc(orgId);

  const [holdingSnap, groupSnap, siteSnap] = await Promise.all([
    orgRef.collection('holdings').get(),
    orgRef.collection('groups').get(),
    db.collection('sites').where('organizationId', '==', orgId).get(),
  ]);

  const siteDocs = siteSnap.docs.filter((doc) => {
    const data = doc.data() || {};
    return NON_CORAL_SITE_TYPE_IDS.has(data.siteTypeId)
      || ['Kelp Farm Alpha', 'Oyster Reef Site', 'Seagrass Restoration Plot'].includes(data.name);
  });

  const siteIds = new Set(siteDocs.map((doc) => doc.id));

  const groupDocs = groupSnap.docs.filter((doc) => {
    const data = doc.data() || {};
    return NON_CORAL_GROUP_TYPE_IDS.has(data.groupTypeId)
      || (data.siteId && siteIds.has(data.siteId));
  });

  const holdingDocs = holdingSnap.docs.filter((doc) => {
    const data = doc.data() || {};
    return NON_CORAL_ORGANISM_KINDS.has(data.organismKind)
      || NON_CORAL_HOLDING_KINDS.has(data.holdingKind);
  });

  await deleteMatchingDocs(holdingDocs, 'non-coral holdings');
  await deleteMatchingDocs(groupDocs, 'non-coral groups');
  await deleteMatchingDocs(siteDocs, 'non-coral sites');
}

function generateId() {
  return admin.firestore().collection('_').doc().id;
}

function now() {
  return admin.firestore.FieldValue.serverTimestamp();
}

async function getOrCreateSite(orgId, userId, name, siteTypeId) {
  const sitesRef = db.collection('sites');
  const existing = await sitesRef
    .where('organizationId', '==', orgId)
    .where('name', '==', name)
    .where('siteTypeId', '==', siteTypeId)
    .limit(1)
    .get();

  if (!existing.empty) {
    const site = existing.docs[0];
    console.log(`  Using existing site: ${name} (${site.id})`);
    return { id: site.id, ...site.data() };
  }

  const siteId = generateId();
  const orgDoc = await db.collection('organizations').doc(orgId).get();
  const orgData = orgDoc.data();
  const urlPath = `${orgData.slug || orgData.domain || orgId}/${name.toLowerCase().replace(/\s+/g, '-')}`;
  const slug = name.toLowerCase().replace(/\s+/g, '-');

  const siteData = {
    id: siteId,
    name,
    organizationId: orgId,
    siteTypeId,
    groupIdHierarchy: [],  // Required field for Site model
    urlPath,
    internalPath: `sites/${siteId}`,
    slug,
    modelType: 'site',
    createdById: userId,
    updatedById: userId,
    createdAt: now(),
    updatedAt: now(),
  };

  await sitesRef.doc(siteId).set(siteData);
  console.log(`  Created new site: ${name} (${siteId})`);
  return siteData;
}

async function createGroups(orgId, siteId, siteUrlPath, groupTypeId, namePrefix, count, userId) {
  const groups = [];
  // Write to nested collection: organizations/{orgId}/groups
  const groupsRef = db.collection('organizations').doc(orgId).collection('groups');

  for (let i = 1; i <= count; i++) {
    const groupId = generateId();
    const name = `${namePrefix} ${i}`;
    const slug = name.toLowerCase().replace(/\s+/g, '-');
    const urlPath = `${siteUrlPath}/${slug}`;

    const groupData = {
      id: groupId,
      name,
      organizationId: orgId,
      siteId,
      parentId: '',  // Root-level group has empty parentId
      groupTypeId,
      urlPath,
      internalPath: `${orgId}/${siteId}/${groupId}`,
      slug,
      modelType: 'group',
      createdById: userId,
      updatedById: userId,
      createdAt: now(),
      updatedAt: now(),
    };

    await groupsRef.doc(groupId).set(groupData);
    groups.push(groupData);
  }

  return groups;
}

async function getSpeciesByOrganismKind(organismKind) {
  const speciesSnapshot = await db
    .collection('taxonomy_species')
    .where('organismKind', '==', organismKind)
    .limit(2)
    .get();

  return speciesSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

async function createHolding(orgId, userId, holdingData) {
  const holdingsRef = db.collection('organizations').doc(orgId).collection('holdings');
  const holdingId = generateId();
  const slug = (holdingData.recordName || holdingId).toLowerCase().replace(/\s+/g, '-');

  const fullHolding = {
    id: holdingId,
    modelType: 'holding',
    ...holdingData,
    organizationId: orgId,
    slug,
    urlPath: `${orgId}/${slug}`,
    internalPath: `organizations/${orgId}/holdings/${holdingId}`,
    createdAt: now(),
    createdById: userId,
    updatedAt: now(),
    updatedById: userId,
  };

  await holdingsRef.doc(holdingId).set(fullHolding);
  return fullHolding;
}

async function seedForOrganization(orgId, userId) {
  console.log(`\n📋 Processing organization: ${orgId}`);

  if (shouldRemove) {
    await removeNonCoralHoldings(orgId);
    console.log(`  ✅ Completed removal for organization ${orgId}`);
    return;
  }

  // Get or create sites
  const kelpSite = await getOrCreateSite(
    orgId,
    userId,
    'Kelp Farm Alpha',
    SITE_TYPES.kelpFarm,
  );
  const oysterSite = await getOrCreateSite(
    orgId,
    userId,
    'Oyster Reef Site',
    SITE_TYPES.reefAquaculture,
  );
  const seagrassSite = await getOrCreateSite(
    orgId,
    userId,
    'Seagrass Restoration Plot',
    SITE_TYPES.seagrassPlot,
  );

  // Create groups/structures
  const kelpLonglines = await createGroups(
    orgId,
    kelpSite.id,
    kelpSite.urlPath,
    GROUP_TYPES.longline,
    'Longline',
    3,
    userId,
  );
  const oysterRacks = await createGroups(
    orgId,
    oysterSite.id,
    oysterSite.urlPath,
    GROUP_TYPES.rack,
    'Rack',
    4,
    userId,
  );
  const seagrassPlots = await createGroups(
    orgId,
    seagrassSite.id,
    seagrassSite.urlPath,
    GROUP_TYPES.plotTransect,
    'Plot',
    5,
    userId,
  );

  // Get species for each organism kind
  const kelpSpecies = await getSpeciesByOrganismKind(ORGANISM_KINDS.kelp);
  const oysterSpecies = await getSpeciesByOrganismKind(ORGANISM_KINDS.oyster);
  const seagrassSpecies = await getSpeciesByOrganismKind(ORGANISM_KINDS.seagrass);

  // Seed kelp seeded lines
  if (kelpSpecies.length > 0 && kelpLonglines.length > 0) {
    console.log('  Seeding kelp seeded lines...');
    for (let i = 0; i < 8; i++) {
      const species = kelpSpecies[rand(kelpSpecies.length)];
      const longline = kelpLonglines[rand(kelpLonglines.length)];
      const speciesCode = normalizeSpeciesCode(species);
      const lineLength = randDouble(50, 150);
      const biomass = randDouble(0.5, 2.5);
      const recordName = recordNameGenerator.nextForSpeciesCode(speciesCode);
      const localId = buildLocalId(speciesCode, 'LINE', i + 1);

      await createHolding(orgId, userId, {
        holdingKind: HOLDING_KINDS.seededLineBatch,
        organismKind: ORGANISM_KINDS.kelp,
        recordName,
        lifeStage: { id: 'life_stage_juvenile' },
        lifeStageId: 'life_stage_juvenile',
        physicalForm: { formId: 'seeded_line', sizeBandId: 'medium' },
        physicalFormConfigVersion: 'v1',
        measurement: {
          value: biomass,
          unit: 'kg_per_m',
        },
        siteId: kelpSite.id,
        groupId: longline.id,
        lineIdentifier: `LL-${i + 1}`,
        lineLengthMeters: lineLength,
        deployedAt: new Date(seedDate.getTime() - rand(180) * dayMs).toISOString(),
        metadata: {
          localId,
          speciesId: species.id,
          speciesCode: speciesCode,
          speciesScientific: species.scientificName || `${species.genus} ${species.species}`,
        },
      });
    }
    console.log('    ✅ Created 8 kelp seeded lines');
  }

  // Seed oyster gamete and larval batches
  if (oysterSpecies.length > 0 && oysterRacks.length > 0) {
    console.log('  Seeding oyster gamete and larval batches...');
    for (let i = 0; i < 6; i++) {
      const species = oysterSpecies[rand(oysterSpecies.length)];
      const rack = oysterRacks[rand(oysterRacks.length)];
      const speciesCode = normalizeSpeciesCode(species);
      const gameteRecordName = recordNameGenerator.nextForSpeciesCode(speciesCode);
      const gameteLocalId = buildLocalId(speciesCode, 'GAM', i + 1);

      // Create gamete batch
      await createHolding(orgId, userId, {
        holdingKind: HOLDING_KINDS.gameteBatch,
        organismKind: ORGANISM_KINDS.oyster,
        recordName: gameteRecordName,
        lifeStage: { id: 'life_stage_gamete' },
        lifeStageId: 'life_stage_gamete',
        physicalForm: { formId: 'liquid_suspension', sizeBandId: 'medium' },
        physicalFormConfigVersion: 'v1',
        measurement: {
          value: randDouble(1000, 6000),
          unit: 'count',
        },
        siteId: oysterSite.id,
        groupId: rack.id,
        spawnedAt: new Date(seedDate.getTime() - rand(30) * dayMs).toISOString(),
        parentProvenanceIds: [],
        metadata: {
          localId: gameteLocalId,
          speciesId: species.id,
          speciesCode: speciesCode,
          speciesScientific: species.scientificName || `${species.genus} ${species.species}`,
        },
      });

      // Create larval batch from some gamete batches
      if (i < 4) {
        const larvalRecordName = recordNameGenerator.nextForSpeciesCode(speciesCode);
        const larvalLocalId = buildLocalId(speciesCode, 'LAR', i + 1);
        await createHolding(orgId, userId, {
          holdingKind: HOLDING_KINDS.larvalBatch,
          organismKind: ORGANISM_KINDS.oyster,
          recordName: larvalRecordName,
          lifeStage: { id: 'life_stage_larva' },
          lifeStageId: 'life_stage_larva',
          physicalForm: { formId: 'liquid_suspension', sizeBandId: 'medium' },
          physicalFormConfigVersion: 'v1',
          measurement: {
            value: randDouble(500, 2500),
            unit: 'count',
          },
          siteId: oysterSite.id,
          groupId: rack.id,
          settlementWindowStart: new Date(seedDate.getTime() + 5 * dayMs).toISOString(),
          settlementWindowEnd: new Date(seedDate.getTime() + 15 * dayMs).toISOString(),
          survivalRatePct: randDouble(60, 90),
          metadata: {
            localId: larvalLocalId,
            speciesId: species.id,
            speciesCode: speciesCode,
            speciesScientific: species.scientificName || `${species.genus} ${species.species}`,
          },
        });
      }
    }
    console.log('    ✅ Created 6 oyster gamete batches and 4 larval batches');
  }

  // Seed seagrass gamete and larval batches
  if (seagrassSpecies.length > 0 && seagrassPlots.length > 0) {
    console.log('  Seeding seagrass gamete and larval batches...');
    for (let i = 0; i < 5; i++) {
      const species = seagrassSpecies[rand(seagrassSpecies.length)];
      const plot = seagrassPlots[rand(seagrassPlots.length)];
      const speciesCode = normalizeSpeciesCode(species);
      const gameteRecordName = recordNameGenerator.nextForSpeciesCode(speciesCode);
      const gameteLocalId = buildLocalId(speciesCode, 'GAM', i + 1);

      // Create gamete batch
      await createHolding(orgId, userId, {
        holdingKind: HOLDING_KINDS.gameteBatch,
        organismKind: ORGANISM_KINDS.seagrass,
        recordName: gameteRecordName,
        lifeStage: { id: 'life_stage_gamete' },
        lifeStageId: 'life_stage_gamete',
        physicalForm: { formId: 'loose_seed', sizeBandId: 'medium' },
        physicalFormConfigVersion: 'v1',
        measurement: {
          value: randDouble(500, 2500),
          unit: 'count',
        },
        siteId: seagrassSite.id,
        groupId: plot.id,
        spawnedAt: new Date(seedDate.getTime() - rand(20) * dayMs).toISOString(),
        parentProvenanceIds: [],
        metadata: {
          localId: gameteLocalId,
          speciesId: species.id,
          speciesCode: speciesCode,
          speciesScientific: species.scientificName || `${species.genus} ${species.species}`,
        },
      });

      // Create larval batch
      if (i < 3) {
        const larvalRecordName = recordNameGenerator.nextForSpeciesCode(speciesCode);
        const larvalLocalId = buildLocalId(speciesCode, 'LAR', i + 1);
        await createHolding(orgId, userId, {
          holdingKind: HOLDING_KINDS.larvalBatch,
          organismKind: ORGANISM_KINDS.seagrass,
          recordName: larvalRecordName,
          lifeStage: { id: 'life_stage_larva' },
          lifeStageId: 'life_stage_larva',
          physicalForm: { formId: 'individual', sizeBandId: 'small' },
          physicalFormConfigVersion: 'v1',
          measurement: {
            value: randDouble(200, 1000),
            unit: 'count',
          },
          siteId: seagrassSite.id,
          groupId: plot.id,
          settlementWindowStart: new Date(seedDate.getTime() + 3 * dayMs).toISOString(),
          settlementWindowEnd: new Date(seedDate.getTime() + 10 * dayMs).toISOString(),
          survivalRatePct: randDouble(50, 90),
          metadata: {
            localId: larvalLocalId,
            speciesId: species.id,
            speciesCode: speciesCode,
            speciesScientific: species.scientificName || `${species.genus} ${species.species}`,
          },
        });
      }
    }
    console.log('    ✅ Created 5 seagrass gamete batches and 3 larval batches');
  }

  console.log(`  ✅ Completed seeding for organization ${orgId}`);
}

async function main() {
  console.log(shouldRemove
    ? '🧹 Removing non-coral holdings...\n'
    : '🌊 Seeding non-coral holdings...\n');

  try {
    if (orgId && userId) {
      // Single org mode
      await seedForOrganization(orgId, userId);
    } else {
      // All orgs mode
      const orgsSnapshot = await db.collection('organizations').get();

      if (orgsSnapshot.empty) {
        console.log('❌ No organizations found in Firestore.');
        return;
      }

      console.log(`Found ${orgsSnapshot.size} organization(s)\n`);

      for (const orgDoc of orgsSnapshot.docs) {
        const orgData = orgDoc.data();
        const currentOrgId = orgDoc.id;

        // Try to find a user for this org (prefer createdById, or any user)
        let user = null;
        const createdById = orgData.createdById;
        if (createdById) {
          try {
            const userDoc = await db.collection('users').doc(createdById).get();
            if (userDoc.exists) {
              user = { id: createdById, ...userDoc.data() };
            }
          } catch (_) {
            // Fall through to find any user
          }
        }

        // If no user found, get the first available user
        if (!user) {
          const usersSnapshot = await db.collection('users').limit(1).get();
          if (!usersSnapshot.empty) {
            const userDoc = usersSnapshot.docs[0];
            user = { id: userDoc.id, ...userDoc.data() };
          }
        }

        if (!user) {
          console.log(`  ⚠️  Skipping ${orgData.name || currentOrgId}: No user found\n`);
          continue;
        }

        const userDisplay = user.email || user.name || user.id;
        console.log(`  👤 Using user: ${userDisplay}`);
        try {
          await seedForOrganization(currentOrgId, user.id);
          console.log(`  ✅ Completed seeding for ${orgData.name || currentOrgId}\n`);
        } catch (e) {
          console.error(`  ❌ Error seeding for ${orgData.name || currentOrgId}: ${e.message}\n`);
        }
      }
    }

    console.log('✨ Finished seeding all organizations!');
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

main().then(() => {
  process.exit(0);
}).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
