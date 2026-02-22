# Mote Marine Laboratory Data Migration Architecture

**Date**: 2025-12-06
**Status**: Design Phase
**Dataset**: Mote APAL History of Genotypes (1,051 genotypes)
**Target**: SeaFoundry Five-Axis Model

---

## Executive Summary

This document outlines the architecture for migrating Mote Marine Laboratory's legacy coral restoration data from a Rails/Heroku database into SeaFoundry's Flutter/Firebase platform. The migration will transform ~1,051 APAL genotypes with associated outplanting/monitoring events into SeaFoundry's five-axis data model while preserving genetic provenance, historical relationships, and linking to the community Provenance ID genetics crosswalk (4,991 Provenance IDs).

**Key Design Principles**:
1. **Preserve Genetic Identity**: Link Mote Universal IDs to community Provenance IDs via existing crosswalk
2. **Maintain Provenance**: Reconstruct genet/cohort relationships from historical data
3. **Five-Axis Compliance**: Map all data to Taxonomy, Provenance, Location, Life Stage, Measurement
4. **Audit Trail**: Create comprehensive import metadata for traceability
5. **Idempotency**: Support re-running migration without data duplication

---

## Source Data Analysis

### Mote HOG CSV Structure (1,051 rows)

**Key Columns**:
- `Mote Universal ID` (e.g., "AP1", "AP2") - Primary identifier
- `Genus`, `Species`, `Name Code` - Taxonomy (all "Acropora palmata", "APAL")
- `Clonal ID` (e.g., "HG0542") - Genetic cluster identifier
- `Founder or SR` - Provenance type (Founder vs Sexual Recruit)
- `Collection Latitude/Longitude` - Geographic origin
- `Collection Date`, `Collection Reef/Site Name` - Temporal/spatial context
- `Currently In Production`, `In Pre-Production`, `Date Dead` - Status tracking
- `Represented in Gene Bank`, `Date transferred to Gene Bank` - Archival status
- `SNP*/2bRAD/Microsatellites` - Genetic analysis metadata
- `Disease Tested`, `Temp Tested`, `OA Tested` - Stress testing data

**Data Characteristics**:
- **1,051 unique genotypes** (APAL only in this CSV, but Mote has ACER, OFAV, etc.)
- **Founder vs SR split**: ~30% founders (wild collection), ~70% sexual recruits (breeding)
- **Clonal grouping**: Multiple Universal IDs may share same Clonal ID (genetic clones)
- **Temporal range**: 2009-2024 (15 years of data)
- **Missing data**: Some rows lack coordinates, collection dates, or clonal IDs

### Community Provenance ID Crosswalk (Existing)

**Location**: `/crc_db/apal_provenance_crosswalk.json`
**Structure**:
```json
{
  "provenanceId": "PROV-APAL-001",
  "species": "Acropora palmata",
  "masterClonalId": "HG0542",
  "moteUniversalIds": ["AP1"],
  "aliases": [
    {"id": "AP1", "org": "Mote", "orgType": "universal_id"},
    {"id": "HG0542", "org": "Mote", "orgType": "clonal_id"},
    {"id": "Apal-025", "org": "CRF", "orgType": "primary"}
  ],
  "metadata": {
    "collectionDate": "12/01/09",
    "collectionLat": 24.54517,
    "collectionLon": -81.40888
  }
}
```

**Coverage**:
- **4,991 total Provenance IDs** across APAL, ACER, OFAV, OANN, OFRA, MFER, DCYL, APRO
- **Cross-organization linking**: Connects Mote, CRF, Reef Renewal, NSU, others
- **Alias resolution**: Maps old names, field IDs, clonal IDs to unified Provenance ID

---

## Target SeaFoundry Schema

### Core Models (Five-Axis)

#### 1. **Genet** (`lib/models/genet.dart`)

**Purpose**: Represents unique genetic identity (individual genotype)

**Key Fields**:
- `id` (Firestore ID, auto-generated)
- `provenanceId` (Community Provenance ID, e.g., "PROV-APAL-001") ⭐ **CRITICAL LINK**
- `clonalId` (Mote Clonal ID, e.g., "HG0542")
- `accessionNumber` (Mote Universal ID, e.g., "AP1")
- `name` (Human-readable, e.g., "AP1 - HG0542")
- `speciesId` (SeaFoundry species registry ID)
- `genetTypeId` (e.g., "genet_type_founder", "genet_type_cohort")
- `organismKind` (OrganismKind.coral)
- `provenanceKind` (ProvenanceKind.genet or ProvenanceKind.cohort)
- `aliases` (List of OrganismAlias - all old Mote names, CRF names, etc.)
- `metadata` (Collection coords, dates, genetic testing history, stress testing)

**Mapping Strategy**:
```
Mote Universal ID → Genet.accessionNumber
Mote Clonal ID → Genet.clonalId
Provenance ID Crosswalk → Genet.provenanceId
"Founder or SR" → Genet.genetTypeId + provenanceKind
Collection Lat/Lon → metadata.collectionCoords
```

#### 2. **Site** (`lib/models/site.dart`)

**Purpose**: Outplanting locations, nursery sites

**Key Fields**:
- `id`, `name`, `siteTypeId`
- `latitude`, `longitude`, `geometry`
- `supportedOrganismKinds` ([OrganismKind.coral])
- `organizationId` (Mote's org ID)

**Mapping Strategy**:
- Create sites from `Collection Reef/Site Name`
- If coordinates exist, use `Collection Latitude/Longitude`
- Default to `site_type_outplanting` unless marked "Gene Bank"

#### 3. **OrganismRecord** (`lib/models/inventory/organism_record.dart`)

**Purpose**: Holdings/inventory snapshots (five-axis payload)

**Key Fields** (Five-Axis):
1. **Taxonomy**: `organismKind` (coral), `speciesId` (APAL registry ID)
2. **Provenance**: `provenanceType`, `provenanceAttributes` (links to genet)
3. **Location**: `siteId`, `groupId`
4. **Life Stage**: `lifeStage` (LifeStageSpec with stage/subtype)
5. **Measurement**: `measurement` (PopulationMeasurement with value/unit)

**Additional Fields**:
- `foreignKeys.genetId` - Link to Genet record
- `aliases` - Cross-references to Mote IDs
- `metadata` - Status flags (inProduction, inGeneBank, isDead)

**Mapping Strategy**:
```
Currently In Production → OrganismRecord (siteId = nursery)
In Pre-Production → OrganismRecord (siteId = pre-production tank)
Represented in Gene Bank → OrganismRecord (siteId = gene bank, metadata.archived=true)
Date Dead → No OrganismRecord (record in metadata.deathDate for audit)
```

#### 4. **OutplantActionEvent** / **MonitoringEventRecord**

**Purpose**: Historical outplanting and monitoring observations

**Mapping Strategy** (Limited - Phase 2):
- Mote CSV doesn't have detailed outplant/monitoring events
- May have external datasets (Heroku DB exports?) to correlate
- For now: Create placeholder "Gene Bank Transfer Event" if `Date transferred to Gene Bank` exists

---

## Migration Architecture

### Phase 1: Foundation (Entities in Dependency Order)

```
1. Organization (Mote Marine Laboratory)
   ↓
2. Species Registry (APAL mapping)
   ↓
3. Sites (Collection sites, nursery, gene bank)
   ↓
4. Genets (1,051 genotypes with Provenance ID linking)
   ↓
5. OrganismRecords (Current holdings status)
   ↓
6. Events (Gene bank transfers, status changes)
```

### Phase 2: ID Crosswalk Strategy

**Problem**: Legacy Mote IDs → New SeaFoundry Firestore IDs

**Solution**: Maintain ID mapping tables during migration

**Crosswalk Tables** (in-memory during script execution):
```javascript
const idMap = {
  moteUniversalId: new Map(), // "AP1" → genet Firestore ID
  clonalId: new Map(),        // "HG0542" → [genet IDs]
  provenanceId: new Map(),            // "PROV-APAL-001" → genet ID
  siteNames: new Map(),       // "Looe Key" → site Firestore ID
};
```

**Persistence**:
- Store mapping in `metadata.importMeta.legacyIds` on each record
- Create `historical_crosswalk` collection for post-migration queries

### Phase 3: Five-Axis Mapping Rules

#### Taxonomy Mapping
```javascript
// All rows are APAL in this CSV
const taxonomyMap = {
  organismKind: OrganismKind.coral,
  genus: row['Genus'],          // "Acropora"
  species: row['Species'],      // "palmata"
  speciesId: APAL_SPECIES_ID,   // Lookup from SeaFoundry species registry
};
```

#### Provenance Mapping
```javascript
const provenanceMap = {
  // Founder = wild-collected genet
  isFounder: row['Founder or SR'] === 'Founder',

  // SR = sexual recruit (cohort-based)
  isSR: row['Founder or SR'] === 'SR',

  // Determine provenance type
  provenanceType: row['Founder or SR'] === 'Founder'
    ? ProvenanceType.wildCollected
    : ProvenanceType.sexualCohort,

  // Determine genet type
  genetTypeId: row['Founder or SR'] === 'Founder'
    ? 'genet_type_founder'
    : 'genet_type_cohort',

  // Cohort information (if SR)
  sourceCohortId: row['If SR, Cohort Information'],

  // Collection method
  wildCollectionMethod: row['Type (collection, COO or rescue)'],
};
```

#### Location Mapping
```javascript
const locationMap = {
  // Collection origin (create Site if coordinates exist)
  collectionSite: row['Collection Reef/Site Name'],
  collectionLat: parseFloat(row['Collection Latitude']),
  collectionLon: parseFloat(row['Collection Longitude']),
  collectionRegion: row['Collection Region'],

  // Current location (infer from status flags)
  currentSite: inferCurrentSite(row),
};

function inferCurrentSite(row) {
  if (row['Date Dead (If known)']) return null; // Dead, no current site
  if (row['Represented in Gene Bank'] === 'Y') return 'mote_gene_bank';
  if (row['In Pre-Production'] === 'Y') return 'mote_pre_production';
  if (row['Currently In Production'] === 'Y') return 'mote_production_nursery';
  return 'mote_holdings'; // Default fallback
}
```

#### Life Stage Mapping
```javascript
const lifeStageMap = {
  // Infer from status and age
  stage: inferLifeStage(row),
};

function inferLifeStage(row) {
  const collectionDate = parseDate(row['Collection Date (MM/DD/YYYY)']);
  const now = new Date();
  const ageYears = (now - collectionDate) / (365.25 * 24 * 60 * 60 * 1000);

  if (row['Date Dead (If known)']) return null; // No life stage if dead
  if (row['Represented in Gene Bank']) return LifeStage.broodstock;
  if (ageYears > 3) return LifeStage.colony;
  if (ageYears > 1) return LifeStage.juvenile;
  return LifeStage.fragment;
}
```

#### Measurement Mapping
```javascript
const measurementMap = {
  // Default to 1 genet = 1 count (no quantity in CSV)
  value: 1,
  unit: MeasurementUnit.count,

  // Additional size metadata (if available from external datasets)
  sizeSpec: {
    sizeClass: null, // Not in CSV
    measuredDimension: null,
    dimensionUnit: null,
  },
};
```

### Phase 4: Provenance ID Linking Logic

**Goal**: Link Mote Universal IDs to Community Provenance IDs

**Algorithm**:
```javascript
async function linkToProvenanceId(moteUniversalId, clonalId, row) {
  // 1. Direct lookup by Mote Universal ID
  const crosswalk = apalCrosswalk.find(entry =>
    entry.moteUniversalIds.includes(moteUniversalId)
  );

  if (crosswalk) {
    return crosswalk.provenanceId; // Found direct match
  }

  // 2. Fallback: Lookup by Clonal ID
  const byClonal = apalCrosswalk.find(entry =>
    entry.masterClonalId === clonalId
  );

  if (byClonal) {
    console.warn(`⚠️  Matched ${moteUniversalId} via clonal ID ${clonalId} → ${byClonal.provenanceId}`);
    return byClonal.provenanceId;
  }

  // 3. No match: Log for manual resolution
  console.error(`❌ No Provenance ID match for ${moteUniversalId} (Clonal: ${clonalId})`);
  unmatchedGenets.push({ moteUniversalId, clonalId, row });
  return null; // Will need manual Provenance ID assignment
}
```

**Handling Unmatched Genets**:
- Generate temporary Provenance ID: `PROV-APAL-TEMP-{index}`
- Flag in metadata: `metadata.provenanceIdStatus = 'pending_resolution'`
- Export unmatched list to CSV for manual review
- Post-migration: Admin tool to assign canonical Provenance IDs

### Phase 5: Genet Creation Logic

**Input**: Mote HOG CSV row
**Output**: Genet Firestore document

```javascript
async function createGenet(row, crosswalk) {
  const moteId = row['Mote Universal ID'];
  const clonalId = row['Clonal ID'];
  const provenanceId = await linkToProvenanceId(moteId, clonalId, row);

  // Parse aliases (old names, partner names)
  const aliases = parseAliases(row);

  // Build Genet payload
  const genet = {
    id: db.collection('genets').doc().id, // Auto-generate
    organizationId: MOTE_ORG_ID,
    createdAt: new Date().toISOString(),
    createdById: MIGRATION_USER_ID,
    updatedAt: new Date().toISOString(),
    updatedById: MIGRATION_USER_ID,

    // Core fields
    name: `${moteId}${clonalId ? ` - ${clonalId}` : ''}`,
    provenanceId: provenanceId || `PROV-APAL-TEMP-${moteId}`,
    clonalId: clonalId || null,
    accessionNumber: moteId,
    speciesId: APAL_SPECIES_ID,
    organismKind: 'coral',
    genetTypeId: row['Founder or SR'] === 'Founder'
      ? 'genet_type_founder'
      : 'genet_type_cohort',
    provenanceKind: row['Founder or SR'] === 'Founder'
      ? 'genet'
      : 'cohort',

    // Aliases
    aliases: aliases,

    // Provenance metadata
    metadata: {
      collectionDate: row['Collection Date (MM/DD/YYYY)'],
      collectionCoords: {
        lat: parseFloat(row['Collection Latitude']),
        lon: parseFloat(row['Collection Longitude']),
      },
      collectionSite: row['Collection Reef/Site Name'],
      collectionRegion: row['Collection Region'],
      collectionCountry: row['Collection Country'],

      // Status flags
      inProduction: row['Currently In Production'] === 'Y',
      inPreProduction: row['In Pre-Production'] === 'Y',
      inGeneBank: row['Represented in Gene Bank'] === 'Y',
      geneBankTransferDate: row['Date transferred to Gene Bank'],
      deathDate: row['Date Dead (If known)'],

      // Genetic testing
      genotyped: row['Genotyped'] === 'Y',
      geneticAnalyses: {
        twobraD: row['2bRAD- Staff, Year'],
        microsatellites: row['Microsatellites- Staff, Year'],
        snp: parseSNPColumns(row),
      },

      // Stress testing
      diseaseTested: row['Disease Tested'],
      tempTested: row['Temp Tested'],
      oaTested: row['OA Tested'],

      // Import audit
      importMeta: {
        source: 'mote_hog_apal_csv',
        importDate: new Date().toISOString(),
        legacyIds: {
          moteUniversalId: moteId,
          clonalId: clonalId,
        },
      },
    },

    // Graph paths
    urlPath: `${MOTE_ORG_ID}/genets/${moteId}`,
    internalPath: `${MOTE_ORG_ID}/genets/${moteId}`,
    slug: moteId,
  };

  return genet;
}
```

### Phase 6: Site Creation Logic

**Strategy**: Create sites for unique collection locations + standard Mote facilities

**Standard Sites** (created first):
```javascript
const MOTE_STANDARD_SITES = [
  {
    id: 'mote_production_nursery',
    name: 'Mote Production Nursery',
    siteTypeId: 'site_type_nursery_ex_situ',
    description: 'Primary production nursery for coral propagation',
  },
  {
    id: 'mote_pre_production',
    name: 'Mote Pre-Production',
    siteTypeId: 'site_type_nursery_ex_situ',
    description: 'Pre-production conditioning facility',
  },
  {
    id: 'mote_gene_bank',
    name: 'Mote Gene Bank',
    siteTypeId: 'site_type_gene_bank',
    description: 'Cryopreservation and genetic archive',
    latitude: 27.4817, // Mote HQ coords
    longitude: -82.5694,
  },
];
```

**Collection Sites** (dynamic from CSV):
```javascript
async function createCollectionSites(rows) {
  const uniqueSites = new Map();

  for (const row of rows) {
    const siteName = row['Collection Reef/Site Name'];
    const lat = parseFloat(row['Collection Latitude']);
    const lon = parseFloat(row['Collection Longitude']);

    if (!siteName || uniqueSites.has(siteName)) continue;
    if (!lat || !lon || (lat === 0 && lon === 0)) continue; // Invalid coords

    uniqueSites.set(siteName, {
      id: db.collection('sites').doc().id,
      organizationId: MOTE_ORG_ID,
      name: siteName,
      siteTypeId: 'site_type_outplanting',
      latitude: lat,
      longitude: lon,
      description: `Wild collection site - ${row['Collection Region']}`,
      groupIdHierarchy: [],
      supportedOrganismKinds: ['coral'],
      metadata: {
        collectionRegion: row['Collection Region'],
        collectionCountry: row['Collection Country'],
        importMeta: {
          source: 'mote_hog_collection_sites',
        },
      },
    });
  }

  return Array.from(uniqueSites.values());
}
```

### Phase 7: OrganismRecord Creation Logic

**Strategy**: Create OrganismRecords only for **living, current holdings**

**Decision Tree**:
```
Is Date Dead populated?
├─ YES → Skip OrganismRecord (record death in Genet metadata only)
└─ NO  → Check status flags
    ├─ "Represented in Gene Bank" = Y → Create OrganismRecord (siteId=gene_bank)
    ├─ "Currently In Production" = Y → Create OrganismRecord (siteId=production_nursery)
    ├─ "In Pre-Production" = Y → Create OrganismRecord (siteId=pre_production)
    └─ All NO → Skip (historical/unknown status)
```

**Example**:
```javascript
async function createOrganismRecord(genet, row, siteMap) {
  // Skip if dead
  if (row['Date Dead (If known)']) return null;

  // Determine current site
  let siteId = null;
  let lifeStage = LifeStage.colony; // Default

  if (row['Represented in Gene Bank'] === 'Y') {
    siteId = siteMap.get('mote_gene_bank');
    lifeStage = LifeStage.broodstock;
  } else if (row['Currently In Production'] === 'Y') {
    siteId = siteMap.get('mote_production_nursery');
    lifeStage = LifeStage.colony;
  } else if (row['In Pre-Production'] === 'Y') {
    siteId = siteMap.get('mote_pre_production');
    lifeStage = LifeStage.juvenile;
  } else {
    return null; // No current site
  }

  return {
    id: db.collection('organism_records').doc().id,
    organizationId: MOTE_ORG_ID,
    createdAt: new Date().toISOString(),
    createdById: MIGRATION_USER_ID,
    updatedAt: new Date().toISOString(),
    updatedById: MIGRATION_USER_ID,

    // Five-Axis
    organismKind: 'coral',
    speciesId: APAL_SPECIES_ID,
    provenanceType: genet.genetTypeId === 'genet_type_founder'
      ? 'wild_collected'
      : 'sexual_cohort',
    provenanceAttributes: {
      isAliquoted: false,
    },
    lifeStage: {
      stage: lifeStage,
      subtype: null,
    },
    measurement: {
      value: 1, // Default: 1 genet = 1 count
      unit: 'count',
    },

    // Location
    siteId: siteId,
    groupId: null, // No group info in CSV

    // Foreign keys
    foreignKeys: {
      genetId: {
        id: genet.id,
        collection: 'genets',
      },
    },

    // Aliases (reference Mote IDs)
    aliases: [
      { value: genet.accessionNumber, sourceSystem: 'mote', label: 'Mote Universal ID' },
      { value: genet.clonalId, sourceSystem: 'mote', label: 'Clonal ID' },
    ],

    // Graph paths
    urlPath: `${MOTE_ORG_ID}/organism_records/${genet.accessionNumber}`,
    internalPath: `${MOTE_ORG_ID}/organism_records/${genet.accessionNumber}`,
    slug: genet.accessionNumber,
  };
}
```

### Phase 8: Event Migration (Limited Scope)

**Available Event Data** (from CSV):
- Gene bank transfer date: `Date transferred to Gene Bank`
- Death date: `Date Dead (If known)`

**Event Creation** (Gene Bank Transfers only):
```javascript
async function createGeneBankTransferEvent(genet, organismRecord, transferDate) {
  if (!transferDate || !organismRecord) return null;

  return {
    id: db.collection('events').doc().id,
    eventTypeId: 'event_type_transfer',
    organizationId: MOTE_ORG_ID,
    createdAt: new Date(transferDate).toISOString(),
    createdById: MIGRATION_USER_ID,
    updatedAt: new Date().toISOString(),
    updatedById: MIGRATION_USER_ID,

    recordId: organismRecord.id,
    recordModelType: 'organismRecord',

    comment: `Transferred to Mote Gene Bank (imported from HOG)`,
    metadata: {
      destinationSite: 'mote_gene_bank',
      importMeta: {
        source: 'mote_hog_gene_bank_transfer',
      },
    },

    urlPath: `${MOTE_ORG_ID}/events/${genet.accessionNumber}_gene_bank`,
    internalPath: `${MOTE_ORG_ID}/events/${genet.accessionNumber}_gene_bank`,
    slug: `${genet.accessionNumber}_gene_bank`,
  };
}
```

**Death Events**: NOT created (would clutter event log). Instead:
- Set `metadata.deathDate` on Genet
- Do NOT create OrganismRecord for dead genets

---

## Implementation Plan

### Script Structure: `scripts/import-mote-hog.js`

**Dependencies**:
- `firebase-admin` (Firestore SDK)
- `csv-parser` (CSV parsing)
- Existing crosswalk: `/crc_db/apal_provenance_crosswalk.json`

**CLI Interface**:
```bash
# Dry run (validate, no writes)
node scripts/import-mote-hog.js --dry-run --csv="History of Genotypes (HOG) - APAL.csv"

# Execute migration
node scripts/import-mote-hog.js --execute --project=seafoundry-dev --csv="History of Genotypes (HOG) - APAL.csv"

# Rollback (delete imported records)
node scripts/import-mote-hog.js --rollback --import-id=mote_hog_2025_12_06
```

**Migration Phases**:
1. **Validate**: Check CSV format, crosswalk availability, Firestore connection
2. **Load Crosswalk**: Parse Provenance ID JSON, build lookup maps
3. **Create Organization**: Ensure Mote org exists
4. **Create Species**: Ensure APAL species exists in registry
5. **Create Sites**: Standard Mote sites + collection sites
6. **Create Genets**: Process all 1,051 rows, link to Provenance IDs
7. **Create OrganismRecords**: For living genets only
8. **Create Events**: Gene bank transfers
9. **Generate Report**: Summary stats, unmatched genets, warnings

### Batch Processing Strategy

**Goal**: Avoid Firestore write limits (500 writes/batch)

**Implementation**:
```javascript
async function batchWrite(collection, records, batchSize = 400) {
  const batches = [];
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = db.batch();
    const chunk = records.slice(i, i + batchSize);

    for (const record of chunk) {
      const ref = db.collection(collection).doc(record.id);
      batch.set(ref, record);
    }

    batches.push(batch.commit());
  }

  await Promise.all(batches);
  console.log(`✅ Wrote ${records.length} ${collection} in ${batches.length} batches`);
}
```

### Error Handling & Rollback

**Atomic Migration ID**:
```javascript
const MIGRATION_ID = `mote_hog_${new Date().toISOString().split('T')[0]}`;

// Tag all records with migration ID
metadata.importMeta.migrationId = MIGRATION_ID;
```

**Rollback Script**:
```javascript
async function rollback(migrationId) {
  const collections = ['genets', 'organism_records', 'sites', 'events'];

  for (const col of collections) {
    const snapshot = await db.collection(col)
      .where('metadata.importMeta.migrationId', '==', migrationId)
      .get();

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    console.log(`🗑️  Deleted ${snapshot.size} ${col}`);
  }
}
```

### Validation & Verification

**Pre-Migration Checks**:
- [ ] CSV file exists and is readable
- [ ] Provenance ID crosswalk JSON exists
- [ ] Mote organization exists in Firestore
- [ ] APAL species exists in species registry
- [ ] Firebase credentials valid

**Post-Migration Verification**:
```javascript
async function verifyMigration() {
  const stats = {
    genetCount: await db.collection('genets')
      .where('metadata.importMeta.source', '==', 'mote_hog_apal_csv')
      .count().get(),

    provenanceIdMatched: await db.collection('genets')
      .where('provenanceId', '>=', 'PROV-APAL-')
      .where('provenanceId', '<=', 'PROV-APAL-~')
      .count().get(),

    provenanceIdUnmatched: await db.collection('genets')
      .where('provenanceId', '>=', 'PROV-APAL-TEMP')
      .count().get(),

    organismRecords: await db.collection('organism_records')
      .where('metadata.importMeta.source', '==', 'mote_hog_organism_record')
      .count().get(),
  };

  console.log('📊 Migration Stats:');
  console.log(`   Genets created: ${stats.genetCount.data().count}`);
  console.log(`   Provenance ID matched: ${stats.provenanceIdMatched.data().count}`);
  console.log(`   Provenance ID unmatched: ${stats.provenanceIdUnmatched.data().count}`);
  console.log(`   Organism records: ${stats.organismRecords.data().count}`);

  // Warn if high unmatch rate
  const unmatchRate = stats.provenanceIdUnmatched.data().count / stats.genetCount.data().count;
  if (unmatchRate > 0.1) {
    console.warn(`⚠️  High unmatch rate: ${(unmatchRate * 100).toFixed(1)}%`);
  }
}
```

---

## Data Integrity & Quality Checks

### Duplicate Detection

**Clonal ID Grouping**:
- Multiple Mote IDs may share same Clonal ID (intentional - genetic clones)
- Each gets separate Genet record, linked by `clonalId` field
- UI can group/filter by clonal ID for clone management

**Duplicate Prevention**:
```javascript
// Check for existing Genet with same accessionNumber
const existing = await db.collection('genets')
  .where('accessionNumber', '==', moteId)
  .where('organizationId', '==', MOTE_ORG_ID)
  .limit(1)
  .get();

if (!existing.empty) {
  console.warn(`⚠️  Duplicate detected: ${moteId} already exists`);
  return existing.docs[0].id; // Return existing ID instead of creating new
}
```

### Coordinate Validation

**Invalid Coordinates**:
- Filter out (0, 0) coordinates (missing data)
- Validate lat/lon ranges: lat ∈ [-90, 90], lon ∈ [-180, 180]
- Warn if coordinates far from Florida Keys (expected region)

```javascript
function validateCoords(lat, lon, siteName) {
  if (!lat || !lon || (lat === 0 && lon === 0)) {
    console.warn(`⚠️  Invalid coords for ${siteName}: (${lat}, ${lon})`);
    return false;
  }

  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    console.error(`❌ Out-of-range coords for ${siteName}: (${lat}, ${lon})`);
    return false;
  }

  // Florida Keys bounding box: ~24-26°N, ~80-82°W
  const inKeys = lat >= 24 && lat <= 26 && lon >= -82 && lon <= -80;
  if (!inKeys) {
    console.info(`ℹ️  Non-Keys coords for ${siteName}: (${lat}, ${lon})`);
  }

  return true;
}
```

### Provenance ID Match Reporting

**Unmatched Genets CSV Export**:
```javascript
async function exportUnmatched(unmatchedGenets) {
  const csv = [
    'Mote Universal ID,Clonal ID,Species,Founder/SR,Collection Site,Suggested Provenance ID',
    ...unmatchedGenets.map(u =>
      `${u.moteUniversalId},${u.clonalId},APAL,${u.row['Founder or SR']},${u.row['Collection Reef/Site Name']},PROV-APAL-TEMP-${u.moteUniversalId}`
    ),
  ].join('\n');

  fs.writeFileSync('mote_unmatched_provenance_ids.csv', csv);
  console.log(`📄 Exported ${unmatchedGenets.length} unmatched genets to mote_unmatched_provenance_ids.csv`);
}
```

---

## Post-Migration Tasks

### Admin Review & Provenance ID Assignment

**Unmatched Genets**:
1. Review `mote_unmatched_provenance_ids.csv`
2. Cross-reference with CRC database, genetic analysis records
3. Assign canonical Provenance IDs or create new community Provenance IDs
4. Update Genet records via admin tool or script

**Admin Tool Requirements**:
- Search genets by accessionNumber, clonalId, provenanceId
- Bulk Provenance ID assignment interface
- Alias editor (add/remove cross-org aliases)

### Data Enrichment (Phase 2)

**External Datasets to Integrate**:
1. **Mote Heroku DB Export**: Detailed outplant/monitoring events
2. **CRC Outplant Events**: Cross-org outplanting data (already have import script)
3. **Genetic Analysis Results**: Link SNP/microsatellite results to genets
4. **Stress Testing Results**: Disease, temperature, OA test outcomes

**Enrichment Script**:
```bash
# After base migration, enrich with external datasets
node scripts/enrich-mote-outplants.js --source=mote_heroku_export.csv
node scripts/enrich-mote-genetics.js --source=mote_snp_results.csv
```

### Quality Metrics Dashboard

**Key Metrics**:
- **Genet Coverage**: % with Provenance ID match
- **Spatial Coverage**: Sites with valid coordinates
- **Temporal Coverage**: Genets by collection year
- **Status Distribution**: In production vs gene bank vs dead
- **Genetic Testing Coverage**: % genotyped, by method
- **Stress Testing Coverage**: % with disease/temp/OA data

**Dashboard Query Examples**:
```javascript
// Genets by collection year
const byYear = await db.collection('genets')
  .where('metadata.importMeta.source', '==', 'mote_hog_apal_csv')
  .get()
  .then(snapshot => {
    const counts = {};
    snapshot.forEach(doc => {
      const year = doc.data().metadata.collectionDate?.split('/')[2];
      counts[year] = (counts[year] || 0) + 1;
    });
    return counts;
  });

// Stress testing coverage
const stressTested = await db.collection('genets')
  .where('metadata.diseaseTested', '!=', null)
  .count().get();
```

---

## Timeline & Resource Estimates

### Development Phases

**Phase 1: Script Development** (3-5 days)
- CSV parsing & validation
- Provenance ID crosswalk integration
- Genet creation logic
- Site creation logic
- OrganismRecord creation logic
- Dry-run testing

**Phase 2: Testing & Validation** (2-3 days)
- Test migration on dev environment
- Verify data integrity
- Fix edge cases (missing coords, null values)
- Performance testing (1,051 records)

**Phase 3: Production Migration** (1 day)
- Backup production Firestore
- Execute migration on staging
- Verify staging data
- Execute migration on production
- Post-migration verification

**Phase 4: Admin Review** (1-2 weeks)
- Review unmatched Provenance IDs
- Manual Provenance ID assignment
- Alias corrections
- Data enrichment from external sources

### Rollback Strategy

**If Migration Fails**:
1. Stop execution immediately
2. Run rollback script with migration ID
3. Verify all imported records deleted
4. Restore Firestore backup (if necessary)
5. Fix script bugs
6. Re-run migration

**Partial Rollback**:
- Delete only specific collections (e.g., just events)
- Preserve genets/sites if valid
- Re-run only failed phases

---

## Security & Access Control

### Migration User

**Create Service Account**:
```javascript
const MIGRATION_USER_ID = 'migration_mote_hog';

// Create user document (if doesn't exist)
await db.collection('users').doc(MIGRATION_USER_ID).set({
  id: MIGRATION_USER_ID,
  email: 'migration+mote@seafoundry.com',
  name: 'Mote HOG Migration Script',
  role: 'admin',  // Admin status computed from role == 'admin'
  createdAt: new Date().toISOString(),
});
```

**All imported records attributed to this user**:
- `createdById: MIGRATION_USER_ID`
- `updatedById: MIGRATION_USER_ID`

### Firestore Security Rules

**Ensure migration user has write access**:
```javascript
// firestore.rules
match /genets/{genetId} {
  allow write: if request.auth != null &&
    (request.auth.token.admin == true ||
     request.auth.uid == 'migration_mote_hog');
}
```

---

## Appendix A: Field Mapping Reference

### Mote CSV → SeaFoundry Genet

| Mote HOG Column | SeaFoundry Genet Field | Notes |
|----------------|------------------------|-------|
| Mote Universal ID | `accessionNumber` | Primary Mote identifier |
| Clonal ID | `clonalId` | Genetic cluster ID |
| (via crosswalk) | `provenanceId` | Community Provenance ID |
| Genus + Species | `speciesId` | Lookup in species registry |
| Name Code | (derived) | Used for validation (should be "APAL") |
| Founder or SR | `genetTypeId`, `provenanceKind` | Founder vs cohort |
| Collection Latitude | `metadata.collectionCoords.lat` | May be null |
| Collection Longitude | `metadata.collectionCoords.lon` | May be null |
| Collection Date | `metadata.collectionDate` | MM/DD/YYYY format |
| Collection Reef/Site Name | `metadata.collectionSite` | Used to create Site records |
| Currently In Production | `metadata.inProduction` | Boolean flag |
| In Pre-Production | `metadata.inPreProduction` | Boolean flag |
| Represented in Gene Bank | `metadata.inGeneBank` | Boolean flag |
| Date Dead (If known) | `metadata.deathDate` | No OrganismRecord created if dead |
| Other/Old Names (Mote) | `aliases[]` | Parse semicolon-separated list |
| Other/Old Names (Other Organizations) | `aliases[]` | Parse + tag with org |
| 2bRAD- Staff, Year | `metadata.geneticAnalyses.twobraD` | Genetic testing metadata |
| Microsatellites- Staff, Year | `metadata.geneticAnalyses.microsatellites` | Genetic testing metadata |
| SNP (various columns) | `metadata.geneticAnalyses.snp[]` | Array of SNP analysis records |
| Disease Tested | `metadata.diseaseTested` | Stress testing flag |
| Temp Tested | `metadata.tempTested` | Stress testing flag |
| OA Tested | `metadata.oaTested` | Stress testing flag |

### Mote CSV → SeaFoundry OrganismRecord

| Mote HOG Column | SeaFoundry OrganismRecord Field | Notes |
|----------------|--------------------------------|-------|
| (derived from Genet) | `organismKind` | Always "coral" |
| (derived from Genet) | `speciesId` | APAL species ID |
| (inferred from status) | `siteId` | Production, gene bank, or pre-production |
| (inferred from status) | `lifeStage` | Colony, broodstock, or juvenile |
| (default) | `measurement` | { value: 1, unit: "count" } |
| Mote Universal ID | `foreignKeys.genetId` | Link to Genet record |
| (from Genet) | `aliases[]` | Copy from Genet |

---

## Appendix B: Example Migration Output

### Dry Run Report

```
🔍 MOTE HOG MIGRATION - DRY RUN
═══════════════════════════════════════════════════════════════

📄 CSV File: History of Genotypes (HOG) - APAL.csv
📊 Rows: 1,051
🗂️  Crosswalk: /crc_db/apal_provenance_crosswalk.json (4,991 Provenance IDs)

PHASE 1: VALIDATION
───────────────────
✅ CSV parsed successfully (1,051 rows)
✅ Provenance ID crosswalk loaded (4,991 entries)
✅ Mote organization exists (ID: mote_marine_lab)
✅ APAL species exists (ID: apal_species_001)

PHASE 2: SITE CREATION (Dry Run)
─────────────────────────────────
Would create 3 standard sites:
  • mote_production_nursery (Mote Production Nursery)
  • mote_pre_production (Mote Pre-Production)
  • mote_gene_bank (Mote Gene Bank)

Would create 47 collection sites from CSV:
  • Looe Key - west end (near 17/18?) (24.54517, -81.40888)
  • Elbow/Horseshoe/Sand Island (coordinates missing - SKIPPED)
  • ...

⚠️  Skipped 12 sites due to missing/invalid coordinates

PHASE 3: GENET CREATION (Dry Run)
──────────────────────────────────
Would create 1,051 genets:
  • 314 founders (30%)
  • 737 sexual recruits (70%)

Provenance ID Matching:
  ✅ 987 matched via Mote Universal ID (94%)
  ✅ 42 matched via Clonal ID (4%)
  ❌ 22 UNMATCHED (2%)

Would export unmatched list to: mote_unmatched_provenance_ids.csv

PHASE 4: ORGANISM RECORD CREATION (Dry Run)
────────────────────────────────────────────
Would create 412 organism records:
  • 198 in production nursery
  • 67 in pre-production
  • 147 in gene bank

Would SKIP 639 records:
  • 542 dead (Date Dead populated)
  • 97 unknown status (no status flags)

PHASE 5: EVENT CREATION (Dry Run)
──────────────────────────────────
Would create 147 gene bank transfer events

SUMMARY
───────
Total records to create:
  • Sites: 50
  • Genets: 1,051
  • OrganismRecords: 412
  • Events: 147

Data quality warnings:
  ⚠️  22 genets without Provenance ID match (2%)
  ⚠️  12 collection sites without coordinates (20%)
  ⚠️  542 genets marked dead (52%)

Ready to migrate? Run with --execute flag.
```

### Execution Success Report

```
🚀 MOTE HOG MIGRATION - EXECUTION
═══════════════════════════════════════════════════════════════

Migration ID: mote_hog_2025_12_06_143052
User: migration_mote_hog

PHASE 1: SITES
──────────────
✅ Created 3 standard sites (0.2s)
✅ Created 35 collection sites in 1 batch (1.4s)

PHASE 2: GENETS
───────────────
✅ Created 1,051 genets in 3 batches (4.8s)
   • 987 with matched Provenance IDs
   • 64 with temporary Provenance IDs

PHASE 3: ORGANISM RECORDS
──────────────────────────
✅ Created 412 organism records in 2 batches (2.1s)

PHASE 4: EVENTS
───────────────
✅ Created 147 gene bank transfer events in 1 batch (0.9s)

VERIFICATION
────────────
✅ Genets: 1,051 (expected 1,051)
✅ Provenance ID matched: 987 (94%)
✅ OrganismRecords: 412 (expected 412)
✅ Events: 147 (expected 147)

UNMATCHED PROVENANCE IDS
───────────────
📄 Exported 64 unmatched genets to: mote_unmatched_provenance_ids.csv

MIGRATION COMPLETE ✅
Total time: 9.4s
Records created: 1,660

Next steps:
1. Review mote_unmatched_provenance_ids.csv
2. Assign canonical Provenance IDs via admin tool
3. Enrich with external datasets (outplants, monitoring)
```

---

## Appendix C: Open Questions & Decisions Needed

### Data Source Completeness
**Q**: Does Mote have external datasets beyond this CSV?
**A**: Need to confirm if Heroku DB exports include detailed outplant/monitoring events

### Provenance ID Assignment Strategy
**Q**: How to handle the 22+ unmatched genets?
**Options**:
1. Auto-assign new Provenance IDs (`PROV-APAL-1001` onwards)
2. Manual review + assignment by Mote/CRC admins
3. Hybrid: Auto-assign with `pending_review` flag

**Recommendation**: Manual review for data quality (Option 2)

### Clonal ID Handling
**Q**: Should clones (same Clonal ID) be grouped under single Genet or separate?
**Current Design**: Separate Genets, linked by `clonalId` field
**Rationale**: Preserves individual tracking while allowing clone queries

### Dead Genets
**Q**: Should we create historical OrganismRecords for dead genets?
**Current Design**: No OrganismRecords, only Genet with `metadata.deathDate`
**Rationale**: Reduces clutter, but loses historical holdings timeline

**Alternative**: Create "archived" OrganismRecords with `archived: true` flag

### Outplant/Monitoring Events
**Q**: Scope of event migration in Phase 1?
**Current Design**: Gene bank transfers only (minimal)
**Phase 2**: Import detailed events from Heroku DB export

---

## Appendix D: Testing Checklist

### Pre-Migration Testing
- [ ] CSV parsing handles quoted fields, multi-line cells
- [ ] Provenance ID crosswalk lookup works for all 1,051 rows
- [ ] Coordinate validation filters invalid (0,0) and out-of-range values
- [ ] Duplicate detection prevents creating same genet twice
- [ ] Batch write handles 1,051 genets without hitting limits
- [ ] Dry run produces accurate count/summary report

### Post-Migration Testing
- [ ] All 1,051 genets created in Firestore
- [ ] Provenance ID match rate > 90%
- [ ] All living genets have OrganismRecord
- [ ] Dead genets do NOT have OrganismRecord
- [ ] Sites have valid coordinates (except where expected to be missing)
- [ ] Aliases include all old names from CSV
- [ ] Metadata includes all genetic testing/stress testing data
- [ ] Graph paths (urlPath, internalPath) are valid
- [ ] Migration can be rolled back cleanly

### Integration Testing
- [ ] Genets visible in SeaFoundry UI (genet list, search)
- [ ] OrganismRecords linked to correct sites
- [ ] Aliases searchable (search "AP1" finds genet)
- [ ] Provenance ID crosswalk links work (search "PROV-APAL-001" finds genet)
- [ ] Site map shows collection sites with coordinates
- [ ] Gene bank filter shows correct genets

---

**End of Migration Architecture Document**

*For questions or implementation support, contact SeaFoundry development team.*
