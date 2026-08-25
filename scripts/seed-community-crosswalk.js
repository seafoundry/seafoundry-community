#!/usr/bin/env node

/**
 * Seed the community genetics crosswalk into Firestore.
 *
 * Reads a local crosswalk JSON export (NOT committed to this repo — sourced
 * from an external provenance registry / partner data source) and uploads
 * sanitized records to:
 *   - community_genetics_provenances/{provenanceId}
 *   - community_genetics_aliases/{speciesCode}_{normalizedAliasId}
 *
 * The input path is supplied at runtime via the CROSSWALK_PATH env var; the
 * file itself is never shipped with this repo.
 *
 * Scrub rules (applied to every record):
 *   - rawAliases matching /^M-L-/i are dropped (source-registry internal IDs)
 *   - collectionSite "M-L-..." substrings are removed/cleared
 *   - rawAliases containing "M-L-" anywhere are dropped
 *   - the orgA..orgJ anonymized alias dict is kept
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=seafoundry-community-oss \
 *     CROSSWALK_PATH=/path/to/crosswalk.json \
 *     node scripts/seed-community-crosswalk.js
 *
 *   # Optional flags:
 *   #   --dry-run         Print what would be written, write nothing
 *   #   --limit=N         Cap the number of records uploaded (for smoke testing)
 *   #   --species=ACER    Only upload records for the given species code
 */

require('dotenv').config();

const fs = require('fs');
const path = require('path');
// Requiring ./config-json runs the authoritative emulator/demo-project guard at
// module load time (validating the exact project id passed to admin.initializeApp)
// BEFORE any Firestore write can happen, so no separate guard call is needed here.
const { admin, db } = require('./config-json');

const PROVENANCE_COLLECTION = 'community_genetics_provenances';
const ALIAS_COLLECTION = 'community_genetics_aliases';

const SOURCE_ID_PREFIX_RE = /^M-L-/i;
const SOURCE_ID_ANYWHERE_RE = /\bM-L-/i;
const ALIAS_NORMALIZE_RE = /[^A-Z0-9]/g;

function parseArgs(argv) {
  const args = { dryRun: false, limit: null, species: null };
  for (const a of argv.slice(2)) {
    if (a === '--dry-run') args.dryRun = true;
    else if (a.startsWith('--limit=')) args.limit = parseInt(a.split('=')[1], 10);
    else if (a.startsWith('--species=')) args.species = a.split('=')[1].toUpperCase();
  }
  return args;
}

function loadCrosswalk() {
  const crosswalkPath = process.env.CROSSWALK_PATH;
  if (!crosswalkPath) {
    console.error('❌ Set CROSSWALK_PATH to a local crosswalk JSON file.');
    console.error('   Example: CROSSWALK_PATH=$HOME/data/crosswalk.json');
    process.exit(1);
  }
  const resolved = path.resolve(crosswalkPath);
  if (!fs.existsSync(resolved)) {
    console.error(`❌ Crosswalk file not found: ${resolved}`);
    process.exit(1);
  }
  const data = JSON.parse(fs.readFileSync(resolved, 'utf8'));
  if (!data || !data.genotypes || typeof data.genotypes !== 'object') {
    console.error('❌ Expected { genotypes: { ... } } structure in crosswalk file.');
    process.exit(1);
  }
  console.log(`✓ Loaded ${Object.keys(data.genotypes).length} genotypes from ${resolved}`);
  return data;
}

function scrubGenotype(g) {
  const rawAliases = Array.isArray(g.rawAliases)
    ? g.rawAliases.filter((a) => typeof a === 'string' && !SOURCE_ID_ANYWHERE_RE.test(a))
    : [];

  let collectionSite = g.collectionSite || null;
  if (typeof collectionSite === 'string') {
    // Strip parenthetical source-registry codes like "Site Name (M-L-XX) + ..."
    let cleaned = collectionSite.replace(/\s*\(\s*M-L-[^)]*\)/gi, '').trim();
    // If the remaining string still starts with M-L-, drop entirely.
    if (SOURCE_ID_ANYWHERE_RE.test(cleaned)) cleaned = '';
    collectionSite = cleaned || null;
  }

  return { rawAliases, collectionSite };
}

function normalizeAlias(value) {
  return String(value).toUpperCase().replace(ALIAS_NORMALIZE_RE, '');
}

function buildProvenanceDoc(g, scrub) {
  const speciesCode = (g.species || '').toUpperCase();
  const aliases = [];

  // From the anonymized orgA..orgJ dict
  if (g.aliases && typeof g.aliases === 'object') {
    for (const [orgKey, value] of Object.entries(g.aliases)) {
      if (!value || typeof value !== 'string') continue;
      if (SOURCE_ID_ANYWHERE_RE.test(value)) continue;
      aliases.push({
        id: value,
        org: orgKey, // already anonymized to 'orgA'..'orgJ'
        orgType: 'clonal_id',
      });
    }
  }

  return {
    provenanceId: g.provenanceId,
    species: g.speciesName || '',
    speciesCode,
    masterClonalId: g.clonalId || null,
    aliases,
    hasGeneticData: !!g.hasGeneticData,
    isFounder: !!g.isFounder,
    isSR: !!g.isSexualRecruit,
    sources: Array.isArray(g.sources) ? g.sources : ['external_registry'],
    partnerIds: [],
    metadata: {
      accessionNumber: g.accessionNumber || null,
      firstOutplantDate: g.firstOutplantDate || null,
      collectionDate: g.collectionDate || null,
      collectionSite: scrub.collectionSite,
      collectionRegion: g.collectionRegion || null,
      rawAliases: scrub.rawAliases,
      totalOutplantEvents: g.totalOutplantEvents || 0,
    },
  };
}

function buildAliasDocs(provenanceDoc) {
  const docs = [];
  const provenanceId = provenanceDoc.provenanceId;
  const speciesCode = provenanceDoc.speciesCode;
  const seen = new Set();

  for (const alias of provenanceDoc.aliases) {
    const normalized = normalizeAlias(alias.id);
    if (!normalized) continue;
    const docId = `${speciesCode}_${normalized}`;
    if (seen.has(docId)) continue;
    seen.add(docId);
    docs.push({
      docId,
      data: {
        provenanceId,
        org: alias.org,
        orgType: alias.orgType,
        aliasId: alias.id,
        normalizedAliasId: normalized,
        speciesCode,
      },
    });
  }
  return docs;
}

async function uploadInBatches(collectionRef, items, dryRun) {
  const BATCH_SIZE = 400;
  let written = 0;
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const slice = items.slice(i, i + BATCH_SIZE);
    if (dryRun) {
      written += slice.length;
      continue;
    }
    const batch = db.batch();
    for (const item of slice) {
      const ref = collectionRef.doc(item.docId);
      batch.set(ref, item.data, { merge: true });
    }
    await batch.commit();
    written += slice.length;
    process.stdout.write(`  wrote ${written}/${items.length}\r`);
  }
  if (!dryRun) process.stdout.write('\n');
  return written;
}

async function main() {
  const args = parseArgs(process.argv);

  const data = loadCrosswalk();
  const provenanceItems = [];
  const aliasItems = [];

  let scanned = 0;
  let droppedNoSurvivingAliases = 0;

  for (const [, g] of Object.entries(data.genotypes)) {
    scanned++;
    const speciesCode = (g.species || '').toUpperCase();
    if (args.species && speciesCode !== args.species) continue;
    if (!g.provenanceId) continue;

    const scrub = scrubGenotype(g);

    // If all rawAliases were M-L-* and there are no anonymized aliases either, drop record.
    const hasAnonAliases = g.aliases && Object.values(g.aliases).some((v) => v);
    if (scrub.rawAliases.length === 0 && !hasAnonAliases) {
      droppedNoSurvivingAliases++;
      continue;
    }

    const provenanceDoc = buildProvenanceDoc(g, scrub);
    provenanceItems.push({ docId: provenanceDoc.provenanceId, data: provenanceDoc });
    aliasItems.push(...buildAliasDocs(provenanceDoc));

    if (args.limit && provenanceItems.length >= args.limit) break;
  }

  console.log(`\nScanned: ${scanned}`);
  console.log(`Provenance records to write: ${provenanceItems.length}`);
  console.log(`Alias docs to write: ${aliasItems.length}`);
  console.log(`Dropped (no surviving aliases): ${droppedNoSurvivingAliases}`);

  if (args.dryRun) {
    console.log('\n(dry run — no writes)');
    console.log('Sample provenance doc:');
    console.log(JSON.stringify(provenanceItems[0]?.data, null, 2));
    console.log('Sample alias doc:');
    console.log(JSON.stringify(aliasItems[0]?.data, null, 2));
    return;
  }

  console.log('\nWriting community_genetics_provenances...');
  await uploadInBatches(db.collection(PROVENANCE_COLLECTION), provenanceItems, false);
  console.log('Writing community_genetics_aliases...');
  await uploadInBatches(db.collection(ALIAS_COLLECTION), aliasItems, false);
  console.log('✓ Seed complete.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  });
