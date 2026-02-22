# Mote Migration Data Flow Diagram

**Visual Reference**: Entity relationships and migration sequence

---

## Migration Sequence Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                   MOTE HOG CSV (1,051 rows)                     │
│  Columns: Mote Universal ID, Clonal ID, Founder/SR, etc.       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              Provenance ID CROSSWALK (4,991 Provenance IDs)                       │
│  {                                                              │
│    "provenanceId": "PROV-APAL-001",                                     │
│    "moteUniversalIds": ["AP1"],                                 │
│    "masterClonalId": "HG0542",                                  │
│    "aliases": [...]                                             │
│  }                                                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌─────────────────┐            ┌──────────────────┐
│  Organization   │            │  Species Registry│
│  (Mote)         │            │  (APAL)          │
└────────┬────────┘            └────────┬─────────┘
         │                              │
         ▼                              │
┌─────────────────────────────────────┐ │
│         Sites (50 total)            │ │
│  • mote_production_nursery          │ │
│  • mote_gene_bank                   │ │
│  • Looe Key (24.54, -81.40)         │ │
│  • Elbow Reef (coords...)           │ │
│  • ...                              │ │
└────────┬────────────────────────────┘ │
         │                              │
         ▼                              │
┌─────────────────────────────────────┐ │
│       Genets (1,051 total)          │◄┘
│  ┌─────────────────────────────┐   │
│  │ id: auto-generated           │   │
│  │ provenanceId: PROV-APAL-001         │   │
│  │ accessionNumber: AP1        │   │
│  │ clonalId: HG0542            │   │
│  │ speciesId: apal_species_001 │   │
│  │ genetTypeId: genet_type_... │   │
│  │ aliases: [...]              │   │
│  │ metadata: {                 │   │
│  │   collectionCoords: {...}   │   │
│  │   inProduction: true,       │   │
│  │   inGeneBank: false,        │   │
│  │   deathDate: null           │   │
│  │ }                           │   │
│  └─────────────────────────────┘   │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  OrganismRecords (412 total)        │
│  ┌─────────────────────────────┐   │
│  │ Five-Axis:                  │   │
│  │ • Taxonomy: coral, APAL     │   │
│  │ • Provenance: wild/cohort   │   │
│  │ • Location: siteId          │   │
│  │ • Life Stage: colony        │   │
│  │ • Measurement: 1 count      │   │
│  │                             │   │
│  │ foreignKeys: {              │   │
│  │   genetId: <genet_id>       │   │
│  │ }                           │   │
│  └─────────────────────────────┘   │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│    Events (147 total)                │
│  • Gene bank transfers               │
│  • (Future: outplants, monitoring)   │
└──────────────────────────────────────┘
```

---

## Five-Axis Data Model Mapping

### Input: Mote CSV Row
```csv
Mote Universal ID: AP1
Genus: Acropora
Species: palmata
Clonal ID: HG0542
Founder or SR: Founder
Collection Latitude: 24.54517
Collection Longitude: -81.40888
Collection Reef/Site Name: Looe Key
Currently In Production: Y
```

### Output: SeaFoundry Models

#### 1. Genet (Provenance Axis)
```javascript
{
  id: "genet_001",
  provenanceId: "PROV-APAL-001",              // From crosswalk
  accessionNumber: "AP1",             // Mote Universal ID
  clonalId: "HG0542",                 // Clonal cluster
  name: "AP1 - HG0542",

  // Taxonomy
  organismKind: "coral",
  speciesId: "apal_species_001",

  // Provenance
  genetTypeId: "genet_type_founder",  // From "Founder or SR"
  provenanceKind: "genet",

  // Aliases (all old names)
  aliases: [
    { value: "AP1", sourceSystem: "mote", label: "Mote Universal ID" },
    { value: "HG0542", sourceSystem: "mote", label: "Clonal ID" },
    { value: "ML-LK11", sourceSystem: "mote_old" },
    { value: "Apal-025", sourceSystem: "CRF" }
  ],

  // Metadata (location/testing history)
  metadata: {
    collectionCoords: { lat: 24.54517, lon: -81.40888 },
    collectionSite: "Looe Key",
    collectionRegion: "Lower Keys",
    collectionDate: "12/01/09",
    inProduction: true,
    genotyped: true,
    geneticAnalyses: { snp: [...], twobraD: "..." }
  }
}
```

#### 2. Site (Location Axis)
```javascript
{
  id: "site_looe_key",
  organizationId: "mote_marine_lab",
  name: "Looe Key",
  siteTypeId: "site_type_outplanting",

  // Location
  latitude: 24.54517,
  longitude: -81.40888,

  supportedOrganismKinds: ["coral"],
  metadata: {
    collectionRegion: "Lower Keys",
    collectionCountry: "U.S"
  }
}
```

#### 3. OrganismRecord (Five-Axis Snapshot)
```javascript
{
  id: "organism_record_001",
  organizationId: "mote_marine_lab",

  // Axis 1: Taxonomy
  organismKind: "coral",
  speciesId: "apal_species_001",

  // Axis 2: Provenance
  provenanceType: "wild_collected",
  provenanceAttributes: {
    isAliquoted: false
  },

  // Axis 3: Location
  siteId: "site_mote_production_nursery",
  groupId: null,

  // Axis 4: Life Stage
  lifeStage: {
    stage: "colony",        // Inferred from age
    subtype: null
  },

  // Axis 5: Measurement
  measurement: {
    value: 1,
    unit: "count"
  },

  // Foreign Keys (link to Genet)
  foreignKeys: {
    genetId: {
      id: "genet_001",
      collection: "genets"
    }
  },

  // Aliases (reference Mote IDs)
  aliases: [
    { value: "AP1", sourceSystem: "mote" },
    { value: "HG0542", sourceSystem: "mote" }
  ]
}
```

#### 4. Event (Gene Bank Transfer)
```javascript
{
  id: "event_001",
  eventTypeId: "event_type_transfer",
  organizationId: "mote_marine_lab",
  recordId: "organism_record_001",
  recordModelType: "organismRecord",

  createdAt: "2021-02-19T00:00:00Z",  // Date transferred to Gene Bank

  comment: "Transferred to Mote Gene Bank (imported from HOG)",
  metadata: {
    destinationSite: "mote_gene_bank",
    importMeta: {
      source: "mote_hog_gene_bank_transfer"
    }
  }
}
```

---

## ID Crosswalk Strategy

### Legacy IDs → SeaFoundry IDs

```
┌─────────────────────────────────────┐
│      Mote Legacy IDs (CSV)          │
├─────────────────────────────────────┤
│ • Mote Universal ID: "AP1"          │
│ • Clonal ID: "HG0542"               │
│ • Old Names: "ML-LK11", "AP-15"     │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│     Provenance ID Crosswalk (Lookup)         │
├─────────────────────────────────────┤
│ Input: "AP1"                        │
│ Output: "PROV-APAL-001"             │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│    SeaFoundry Firestore IDs         │
├─────────────────────────────────────┤
│ • Genet ID: <auto-generated>        │
│ • Genet.provenanceId: "PROV-APAL-001"       │
│ • Genet.accessionNumber: "AP1"      │
│ • Genet.clonalId: "HG0542"          │
└─────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│    Search/Lookup Strategies         │
├─────────────────────────────────────┤
│ • Search "AP1" → Genet (exact)      │
│ • Search "PROV-APAL-001" → Genet    │
│ • Search "HG0542" → All clones      │
│ • Search "ML-LK11" → Genet (alias)  │
└─────────────────────────────────────┘
```

### Unmatched Genet Flow

```
┌─────────────────────────────────────┐
│   CSV Row: "AP999" (not in Provenance ID)   │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│   Try Clonal ID Lookup: "HG9999"   │
└────────────┬────────────────────────┘
             │
             ▼
         No Match
             │
             ▼
┌─────────────────────────────────────┐
│   Assign Temp Provenance ID:                 │
│   "PROV-APAL-TEMP-AP999"            │
│                                     │
│   Flag: metadata.provenanceIdStatus =       │
│         "pending_resolution"        │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│   Export to CSV for manual review:  │
│   mote_unmatched_provenance_ids.csv          │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│   Admin assigns canonical Provenance ID      │
│   via admin tool or script          │
└─────────────────────────────────────┘
```

---

## Status Decision Tree (OrganismRecord Creation)

```
┌─────────────────────────────────────┐
│        Mote CSV Row                 │
└────────────┬────────────────────────┘
             │
             ▼
        ┌────────────┐
        │ Date Dead? │
        └─────┬──────┘
              │
      ┌───────┴───────┐
      │               │
     YES             NO
      │               │
      ▼               ▼
 ┌─────────┐   ┌──────────────┐
 │  SKIP   │   │ Check Status │
 │ (record │   │    Flags     │
 │  death  │   └──────┬───────┘
 │  in     │          │
 │ Genet   │          ▼
 │metadata)│   ┌──────────────┐
 └─────────┘   │ In Gene Bank?│
               └──────┬───────┘
                      │
              ┌───────┴───────┐
              │               │
             YES             NO
              │               │
              ▼               ▼
       ┌─────────────┐  ┌──────────────┐
       │   CREATE    │  │ In Production?│
       │OrganismRec  │  └──────┬───────┘
       │             │         │
       │siteId:      │  ┌──────┴──────┐
       │gene_bank    │  │             │
       │             │ YES           NO
       │lifeStage:   │  │             │
       │broodstock   │  ▼             ▼
       └─────────────┘┌─────────┐ ┌──────────┐
                      │ CREATE  │ │In Pre-   │
                      │OrganismR│ │Production│
                      │         │ └────┬─────┘
                      │siteId:  │      │
                      │prod_nurs│ ┌────┴────┐
                      │         │ │         │
                      │lifeStage│YES       NO
                      │colony   │ │         │
                      └─────────┘ ▼         ▼
                           ┌─────────┐ ┌────────┐
                           │ CREATE  │ │  SKIP  │
                           │OrganismR│ │ (no    │
                           │         │ │current │
                           │siteId:  │ │status) │
                           │pre_prod │ └────────┘
                           │         │
                           │lifeStage│
                           │juvenile │
                           └─────────┘
```

---

## Entity Relationship Diagram

```
┌──────────────┐
│Organization  │
│(Mote)        │
└──────┬───────┘
       │
       │ 1:N
       │
       ▼
┌──────────────┐         ┌──────────────┐
│   Sites      │◄────────│Species Reg   │
│  (50 total)  │         │(APAL)        │
└──────┬───────┘         └──────┬───────┘
       │                        │
       │ 1:N                    │ 1:N
       │                        │
       ▼                        ▼
┌──────────────┐         ┌──────────────┐
│ Genets       │◄────────│Provenance ID Crosswalk│
│(1,051 total) │         │(4,991 Provenance IDs) │
└──────┬───────┘         └──────────────┘
       │
       │ 1:N
       │
       ▼
┌──────────────┐
│OrganismRec   │
│(412 total)   │
└──────┬───────┘
       │
       │ 1:N
       │
       ▼
┌──────────────┐
│  Events      │
│(147 total)   │
└──────────────┘
```

**Relationships**:
- Organization 1:N Sites (Mote owns 50 sites)
- Sites 1:N OrganismRecords (each record at one site)
- Species 1:N Genets (all genets are APAL)
- Genets 1:N OrganismRecords (one genet can have multiple holdings snapshots)
- OrganismRecords 1:N Events (events link to organism records)
- Provenance ID Crosswalk → Genets (external lookup, not stored relationship)

---

## Migration Error Handling Flow

```
┌─────────────────────────────────────┐
│   Start Migration (Batch Mode)     │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│   Process Row 1-400 (Batch 1)      │
└────────────┬────────────────────────┘
             │
             ▼
        ┌────────────┐
        │   Error?   │
        └─────┬──────┘
              │
      ┌───────┴───────┐
      │               │
     YES             NO
      │               │
      ▼               ▼
 ┌─────────┐   ┌──────────────┐
 │  Log    │   │  Continue    │
 │ Error   │   │  Next Batch  │
 │         │   └──────┬───────┘
 │Retry    │          │
 │Once?    │          ▼
 └────┬────┘   ┌──────────────┐
      │        │Process Batch 2│
      ▼        └──────┬───────┘
 ┌─────────┐         │
 │Success? │         ▼
 └────┬────┘   ┌──────────────┐
      │        │   Complete   │
 ┌────┴────┐   └──────────────┘
 │         │
YES       NO
 │         │
 ▼         ▼
Continue  ┌─────────┐
          │ Fatal   │
          │ Error   │
          │         │
          │Rollback?│
          └─────────┘
```

**Error Types**:
- **Recoverable**: Missing field (use default), invalid coord (skip site)
- **Warning**: Provenance ID mismatch (use temp), duplicate site (reuse existing)
- **Fatal**: Firestore quota exceeded, invalid Firebase credentials

---

## Rollback Flow

```
┌─────────────────────────────────────┐
│  Migration Executed                 │
│  (migrationId: mote_hog_2025_12_06) │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Critical Issue Detected            │
│  (e.g., wrong Provenance ID assignment)      │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Run Rollback Script                │
│  --rollback --migration-id=...      │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Query All Collections for          │
│  metadata.importMeta.migrationId    │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Batch Delete:                      │
│  • Events (147 records)             │
│  • OrganismRecords (412 records)    │
│  • Genets (1,051 records)           │
│  • Sites (50 records)               │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Verify Deletion                    │
│  (count should be 0)                │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Rollback Complete                  │
│  (database restored to pre-migration)│
└─────────────────────────────────────┘
```

---

**End of Migration Flow Diagrams**

*For detailed implementation steps, see `MOTE_MIGRATION_ARCHITECTURE.md`*
