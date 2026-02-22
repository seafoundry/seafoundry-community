#!/usr/bin/env ts-node

/**
 * Normalizes Firestore site/group documents to the new facility enum IDs and
 * ensures site documents store the organism whitelist introduced with
 * `SiteCapabilities`.
 *
 * Usage:
 *   ts-node --project tsconfig.scripts.json scripts/migrations/backfill_facility_enums.ts
 *        [--collection sites|groups|all]
 *        [--organization <orgId>]
 *        [--start-after <docId>]
 *        [--limit <n>]
 *        [--batch-size <n>]
 *        [--dry-run]
 *        [--force]
 *        [--report <path>]
 *
 * Examples:
 *   # Preview updates without writing
 *   npm run migrate:facility-enums -- --dry-run
 *
 *   # Backfill only sites for a specific organization
 *   npm run migrate:facility-enums -- --collection sites --organization org_123
 *
 *   # Run against the emulator
 *   FIRESTORE_EMULATOR_HOST=localhost:58080 npm run migrate:facility-enums
 */

import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { admin, db } = require('../config-json') as {
  admin: typeof import('firebase-admin');
  db: FirebaseFirestore.Firestore;
};

type CollectionName = 'sites' | 'groups';

interface Options {
  dryRun: boolean;
  force: boolean;
  verbose: boolean;
  batchSize: number;
  limit: number | null;
  organizationId: string | null;
  startAfter: string | null;
  collections: Set<CollectionName>;
  reportPath: string | null;
}

interface CollectionStats {
  scanned: number;
  updated: number;
  skipped: number;
  typeNormalized: number;
  defaultedOrganisms?: number;
  missingType: number;
  errors: number;
}

const args = process.argv.slice(2);
const options: Options = {
  dryRun: args.includes('--dry-run') || args.includes('-d'),
  force: args.includes('--force') || args.includes('-f'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  batchSize: 400,
  limit: null,
  organizationId: null,
  startAfter: null,
  collections: new Set<CollectionName>(['sites', 'groups']),
  reportPath: null,
};

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  switch (arg) {
    case '--batch-size':
      options.batchSize = Number.parseInt(args[i + 1], 10) || options.batchSize;
      i += 1;
      break;
    case '--limit':
    case '-l':
      options.limit = Number.parseInt(args[i + 1], 10);
      i += 1;
      break;
    case '--organization':
    case '--org':
      options.organizationId = (args[i + 1] || '').trim() || null;
      i += 1;
      break;
    case '--start-after':
      options.startAfter = (args[i + 1] || '').trim() || null;
      i += 1;
      break;
    case '--collection':
    case '-c': {
      const rawValue = (args[i + 1] || '').trim().toLowerCase();
      const selections = rawValue.length > 0 ? rawValue.split(',') : [];
      options.collections.clear();
      selections.forEach((token) => {
        const trimmed = token.trim();
        if (trimmed === 'sites' || trimmed === 'groups' || trimmed === 'all') {
          if (trimmed === 'all') {
            options.collections.add('sites');
            options.collections.add('groups');
          } else {
            options.collections.add(trimmed as CollectionName);
          }
        }
      });
      if (options.collections.size === 0) {
        options.collections.add('sites');
        options.collections.add('groups');
      }
      i += 1;
      break;
    }
    case '--report':
      options.reportPath = (args[i + 1] || '').trim() || null;
      i += 1;
      break;
    default:
      break;
  }
}

const FieldPath = admin.firestore.FieldPath;
const startedAt = new Date().toISOString();

const stats: Record<CollectionName, CollectionStats> = {
  sites: {
    scanned: 0,
    updated: 0,
    skipped: 0,
    typeNormalized: 0,
    defaultedOrganisms: 0,
    missingType: 0,
    errors: 0,
  },
  groups: {
    scanned: 0,
    updated: 0,
    skipped: 0,
    typeNormalized: 0,
    missingType: 0,
    errors: 0,
  },
};

const SITE_DEFAULT_ORGANISMS: Record<string, string[]> = {
  site_type_nursery_ex_situ: ['coral', 'echinoid', 'crab', 'seaCucumber'],
  site_type_nursery_in_situ: ['coral'],
  site_type_outplanting: ['coral', 'oyster', 'seagrass', 'seaCucumber'],
  site_type_gene_bank: ['coral'],
  fc: ['coral'],
  site_type_kelp_farm: ['kelp'],
  site_type_reef_aquaculture: ['oyster'],
  site_type_seagrass_plot: ['seagrass'],
  site_type_mangrove_outplant: ['mangrove'],
  site_type_grow_out_pond: ['echinoid', 'crab'],
  site_type_raceway: ['finfish'],
  site_type_release: ['finfish'],
};

type AliasEntry = { id: string; aliases?: string[] };

const SITE_TYPE_LOOKUP = buildLookup([
  {
    id: 'site_type_nursery_ex_situ',
    aliases: [
      'nes',
      'nursery_ex_situ',
      'nursery-ex-situ',
      'nursery ex situ',
      'ex_situ',
      'exsitu',
    ],
  },
  {
    id: 'site_type_nursery_in_situ',
    aliases: [
      'nis',
      'nursery_in_situ',
      'nursery-in-situ',
      'nursery in situ',
      'in_situ',
      'insitu',
    ],
  },
  {
    id: 'site_type_outplanting',
    aliases: ['op', 'outplanting', 'outplant'],
  },
  {
    id: 'site_type_gene_bank',
    aliases: ['gb', 'gene_bank', 'genebank'],
  },
  {
    id: 'fc',
    aliases: ['field_collection', 'fieldcollection', 'site_type_field_collection'],
  },
  {
    id: 'site_type_kelp_farm',
    aliases: ['kelp_farm', 'kelpfarm'],
  },
  {
    id: 'site_type_reef_aquaculture',
    aliases: ['reef_aquaculture', 'reefaquaculture'],
  },
  {
    id: 'site_type_seagrass_plot',
    aliases: ['seagrass_plot', 'seagrassplot'],
  },
  {
    id: 'site_type_mangrove_outplant',
    aliases: ['mangrove_outplant', 'mangrove'],
  },
  {
    id: 'site_type_grow_out_pond',
    aliases: ['grow_out_pond', 'growoutpond'],
  },
  {
    id: 'site_type_raceway',
    aliases: ['raceway', 'raceway_site'],
  },
  {
    id: 'site_type_release',
    aliases: ['release_site', 'release'],
  },
] satisfies AliasEntry[]);

const GROUP_TYPE_LOOKUP = buildLookup([
  {
    id: 'group_type_life_support_system',
    aliases: ['lss', 'life_support_system', 'lifesupportsystem'],
  },
  { id: 'group_type_tank', aliases: ['tank', 'tanks'] },
  { id: 'group_type_raceway', aliases: ['raceway', 'rwy'] },
  { id: 'group_type_tray', aliases: ['tray', 'trays'] },
  { id: 'group_type_group', aliases: ['group', 'grp'] },
  { id: 'patch', aliases: ['group_type_patch'] },
  { id: 'group_type_tree', aliases: ['tree'] },
  { id: 'group_type_tree_branch', aliases: ['tree_branch', 'branch', 'tb'] },
  { id: 'group_type_dome', aliases: ['dome'] },
  { id: 'group_type_reebar_table', aliases: ['rebar_table', 'reebar', 'rtb'] },
  { id: 'group_type_cradle', aliases: ['cradle', 'crd'] },
  { id: 'group_type_aframe', aliases: ['aframe', 'a-frame', 'frame', 'afra'] },
  { id: 'group_type_zone', aliases: ['zone'] },
  { id: 'group_type_grid', aliases: ['grid'] },
  { id: 'group_type_grid_cell', aliases: ['grid_cell', 'gridcell', 'grdc'] },
  { id: 'group_type_tag', aliases: ['tag'] },
  { id: 'group_type_longline', aliases: ['longline'] },
  { id: 'group_type_raft', aliases: ['raft'] },
  { id: 'group_type_dropper_line', aliases: ['dropper_line', 'dropperline'] },
  { id: 'group_type_pen', aliases: ['pen'] },
  { id: 'group_type_pond', aliases: ['pond'] },
  { id: 'group_type_reef_patch', aliases: ['reef_patch', 'reefpatch'] },
  { id: 'group_type_bag', aliases: ['bag'] },
  { id: 'group_type_rack', aliases: ['rack'] },
  { id: 'group_type_cage', aliases: ['cage'] },
  {
    id: 'group_type_plot_transect',
    aliases: ['plot_transect', 'plot', 'transect'],
  },
  { id: 'group_type_quadrat', aliases: ['quadrat'] },
  { id: 'group_type_belt_transect', aliases: ['belt_transect'] },
  { id: 'group_type_line_pen', aliases: ['line_pen'] },
  { id: 'group_type_boat_drop', aliases: ['boat_drop', 'boatdrop'] },
] satisfies AliasEntry[]);

const ORGANISM_KIND_LOOKUP = buildLookup([
  { id: 'coral', aliases: ['corals'] },
  { id: 'oyster', aliases: ['oysters'] },
  { id: 'seagrass', aliases: ['seagrasses'] },
  { id: 'kelp', aliases: [] },
  { id: 'mangrove', aliases: ['mangroves'] },
  { id: 'echinoid', aliases: ['echinoids', 'urchin', 'urchins'] },
  { id: 'crab', aliases: ['crabs'] },
  { id: 'finfish', aliases: ['fish', 'fishes'] },
  {
    id: 'seaCucumber',
    aliases: ['seacucumber', 'sea_cucumber', 'sea-cucumber', 'sea cucumbers'],
  },
] satisfies AliasEntry[]);

const organizationCache = new Map<string, string[] | null>();

let totalScanned = 0;
let pendingWrites = 0;
let batch = db.batch();

function canonicalKey(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]/g, '');
}

function buildLookup(entries: AliasEntry[]): Map<string, string> {
  const map = new Map<string, string>();
  entries.forEach(({ id, aliases }) => {
    map.set(canonicalKey(id), id);
    aliases?.forEach((alias) => map.set(canonicalKey(alias), id));
  });
  return map;
}

function normalizeSiteTypeId(raw: unknown): { id: string; inferred: boolean } | null {
  if (typeof raw === 'string' && raw.trim().length > 0) {
    const lookup = SITE_TYPE_LOOKUP.get(canonicalKey(raw));
    if (lookup) {
      return { id: lookup, inferred: lookup !== raw };
    }
    return null;
  }
  // Default to ex-situ nursery when missing
  return { id: 'site_type_nursery_ex_situ', inferred: true };
}

function normalizeGroupTypeId(raw: unknown): { id: string; inferred: boolean } | null {
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    return { id: 'group_type_group', inferred: true };
  }
  const lookup = GROUP_TYPE_LOOKUP.get(canonicalKey(raw));
  if (!lookup) {
    return null;
  }
  return { id: lookup, inferred: lookup !== raw };
}

function normalizeOrganismKind(raw: unknown): string | null {
  if (typeof raw !== 'string') {
    return null;
  }
  const lookup = ORGANISM_KIND_LOOKUP.get(canonicalKey(raw));
  return lookup ?? null;
}

function normalizeOrganismKinds(raw: unknown): string[] | null {
  if (!Array.isArray(raw)) {
    return null;
  }
  const result: string[] = [];
  raw.forEach((entry) => {
    const normalized = normalizeOrganismKind(entry);
    if (normalized && !result.includes(normalized)) {
      result.push(normalized);
    }
  });
  return result.length > 0 ? result : null;
}

async function getOrganizationKinds(
  organizationId: string | undefined,
): Promise<string[] | null> {
  if (!organizationId) {
    return null;
  }
  if (organizationCache.has(organizationId)) {
    return organizationCache.get(organizationId) ?? null;
  }
  try {
    const doc = await db.collection('organizations').doc(organizationId).get();
    if (!doc.exists) {
      organizationCache.set(organizationId, null);
      return null;
    }
    const data = doc.data();
    const kinds = normalizeOrganismKinds(data?.supportedOrganismKinds);
    organizationCache.set(organizationId, kinds ?? null);
    return kinds ?? null;
  } catch (error) {
    console.error(`⚠️  Failed to load organization ${organizationId}:`, error);
    organizationCache.set(organizationId, null);
    return null;
  }
}

function determineDefaultOrganisms(
  siteTypeId: string,
  organizationKinds: string[] | null,
): string[] {
  const defaults = SITE_DEFAULT_ORGANISMS[siteTypeId] ?? [];
  if (organizationKinds && organizationKinds.length > 0) {
    const intersection = defaults.filter((kind) => organizationKinds.includes(kind));
    if (intersection.length > 0) {
      return intersection;
    }
  }
  if (defaults.length > 0) {
    return defaults;
  }
  if (organizationKinds && organizationKinds.length > 0) {
    return organizationKinds;
  }
  return ['coral'];
}

async function promptContinue(message: string): Promise<boolean> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(message, (answer) => {
      rl.close();
      resolve(answer.trim().toLowerCase().startsWith('y'));
    });
  });
}

async function flushBatch(): Promise<void> {
  if (pendingWrites === 0) {
    return;
  }
  await batch.commit();
  batch = db.batch();
  pendingWrites = 0;
}

async function queueUpdate(
  ref: FirebaseFirestore.DocumentReference,
  updates: Record<string, unknown>,
  collection: CollectionName,
): Promise<void> {
  if (Object.keys(updates).length === 0) {
    return;
  }
  if (options.dryRun) {
    if (options.verbose) {
      console.log(`📝 [dry-run] ${ref.path}`, updates);
    }
    stats[collection].updated += 1;
    return;
  }
  if (options.verbose) {
    console.log(`📝 Updating ${ref.path}`, updates);
  }
  batch.update(ref, updates);
  pendingWrites += 1;
  stats[collection].updated += 1;
  if (pendingWrites >= options.batchSize) {
    await flushBatch();
  }
}

function reachedLimit(): boolean {
  return options.limit !== null && totalScanned >= options.limit;
}

async function processSites(): Promise<void> {
  if (!options.collections.has('sites')) {
    return;
  }
  console.log('🏗️  Processing sites…');
  let query: FirebaseFirestore.Query<FirebaseFirestore.DocumentData> = db.collection('sites');
  if (options.organizationId) {
    query = query.where('organizationId', '==', options.organizationId);
  }
  query = query.orderBy(FieldPath.documentId());
  let cursor = options.startAfter;

  while (true) {
    if (reachedLimit()) {
      console.log('⏹️  Site processing halted (limit reached).');
      break;
    }
    let paged = query;
    if (cursor) {
      paged = paged.startAfter(cursor);
    }
    const snapshot = await paged.limit(options.batchSize).get();
    if (snapshot.empty) {
      break;
    }
    for (const doc of snapshot.docs) {
      cursor = doc.id;
      if (reachedLimit()) {
        console.log('⏹️  Site processing halted (limit reached).');
        return;
      }
      await handleSiteDoc(doc);
    }
  }
}

async function handleSiteDoc(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
): Promise<void> {
  totalScanned += 1;
  stats.sites.scanned += 1;
  const data = doc.data() ?? {};

  const normalization = normalizeSiteTypeId(data.siteTypeId ?? data.createdEvent?.siteTypeId);
  if (!normalization) {
    stats.sites.missingType += 1;
    console.warn(`⚠️  Unknown siteTypeId for site ${doc.id}; skipping.`);
    stats.sites.skipped += 1;
    return;
  }

  const updates: Record<string, unknown> = {};
  if (data.siteTypeId !== normalization.id) {
    updates.siteTypeId = normalization.id;
    stats.sites.typeNormalized += 1;
  }
  if (data.createdEvent?.siteTypeId && data.createdEvent.siteTypeId !== normalization.id) {
    updates['createdEvent.siteTypeId'] = normalization.id;
  }

  const organizationKinds = await getOrganizationKinds(data.organizationId);
  const existingKinds =
      normalizeOrganismKinds(data.supportedOrganismKinds ?? data.organismKinds);
  const targetKinds = existingKinds ?? determineDefaultOrganisms(
    normalization.id,
    organizationKinds,
  );

  if (!existingKinds && targetKinds.length > 0) {
    stats.sites.defaultedOrganisms =
      (stats.sites.defaultedOrganisms ?? 0) + 1;
  }

  if (
    targetKinds.length > 0 &&
    !arraysEqual(existingKinds ?? [], targetKinds)
  ) {
    updates.supportedOrganismKinds = targetKinds;
  }

  if (Object.keys(updates).length === 0) {
    stats.sites.skipped += 1;
    return;
  }

  try {
    await queueUpdate(doc.ref, updates, 'sites');
  } catch (error) {
    stats.sites.errors += 1;
    console.error(`❌ Failed to update site ${doc.id}:`, error);
  }
}

async function processGroups(): Promise<void> {
  if (!options.collections.has('groups')) {
    return;
  }
  console.log('🏗️  Processing groups…');
  let query: FirebaseFirestore.Query<FirebaseFirestore.DocumentData> = db.collection('groups');
  if (options.organizationId) {
    query = query.where('organizationId', '==', options.organizationId);
  }
  query = query.orderBy(FieldPath.documentId());
  let cursor = options.startAfter;

  while (true) {
    if (reachedLimit()) {
      console.log('⏹️  Group processing halted (limit reached).');
      break;
    }
    let paged = query;
    if (cursor) {
      paged = paged.startAfter(cursor);
    }
    const snapshot = await paged.limit(options.batchSize).get();
    if (snapshot.empty) {
      break;
    }
    for (const doc of snapshot.docs) {
      cursor = doc.id;
      if (reachedLimit()) {
        console.log('⏹️  Group processing halted (limit reached).');
        return;
      }
      await handleGroupDoc(doc);
    }
  }
}

async function handleGroupDoc(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
): Promise<void> {
  totalScanned += 1;
  stats.groups.scanned += 1;
  const data = doc.data() ?? {};

  const normalization = normalizeGroupTypeId(data.groupTypeId ?? data.createdEvent?.groupTypeId);
  if (!normalization) {
    stats.groups.missingType += 1;
    console.warn(`⚠️  Unknown groupTypeId for group ${doc.id}; skipping.`);
    stats.groups.skipped += 1;
    return;
  }

  const updates: Record<string, unknown> = {};
  if (data.groupTypeId !== normalization.id) {
    updates.groupTypeId = normalization.id;
    stats.groups.typeNormalized += 1;
  }
  if (data.createdEvent?.groupTypeId && data.createdEvent.groupTypeId !== normalization.id) {
    updates['createdEvent.groupTypeId'] = normalization.id;
  }

  if (Object.keys(updates).length === 0) {
    stats.groups.skipped += 1;
    return;
  }

  try {
    await queueUpdate(doc.ref, updates, 'groups');
  } catch (error) {
    stats.groups.errors += 1;
    console.error(`❌ Failed to update group ${doc.id}:`, error);
  }
}

function arraysEqual(a: string[] | null, b: string[]): boolean {
  if (!a || a.length !== b.length) {
    return false;
  }
  return a.every((value, index) => value === b[index]);
}

function ensureReportPath(): string {
  if (options.reportPath) {
    return options.reportPath;
  }
  const reportsDir = path.join('scripts', 'migrations', 'reports');
  if (!fs.existsSync(reportsDir)) {
    fs.mkdirSync(reportsDir, { recursive: true });
  }
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  return path.join(reportsDir, `facility_enums_${timestamp}.json`);
}

async function writeReport(): Promise<void> {
  const report = {
    startedAt,
    finishedAt: new Date().toISOString(),
    options: {
      ...options,
      collections: Array.from(options.collections),
    },
    stats,
  };
  const targetPath = ensureReportPath();
  fs.writeFileSync(targetPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  console.log(`🗂️  Report written to ${targetPath}`);
}

async function main(): Promise<void> {
  console.log('🚚 Facility enum backfill starting…');
  if (!options.dryRun && !options.force) {
    const confirmed = await promptContinue(
      'This will rewrite site/group documents in Firestore. Continue? (y/N): ',
    );
    if (!confirmed) {
      console.log('Aborted.');
      process.exit(0);
    }
  }

  if (options.collections.has('sites')) {
    await processSites();
  }
  if (options.collections.has('groups')) {
    await processGroups();
  }

  await flushBatch();
  await writeReport();

  console.log('✅ Backfill complete.');
  console.log('📊 Stats:', stats);
}

main().catch(async (error) => {
  console.error('❌ Migration failed:', error);
  try {
    await flushBatch();
  } catch (_) {
    // Ignore
  }
  process.exit(1);
});
