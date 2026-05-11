# SeaFoundry Taxonomy Registry & Organism Architecture

## Overview

SeaFoundry's taxonomy system provides species and provenance management for coral restoration. The `OrganismKind` enum contains only `coral`. This document describes the core taxonomy patterns and architectural decisions.

### Terminology: Provenance vs. Lineage
- **Preferred term**: We now use **provenance** in UI copy, product docs, and new workflows when referring to genetic relationships or stock histories.
- **Legacy types**: Older code, CSV specs, and Firestore exports may still expose `lineage*` fields. Treat lineage/provenance as synonyms during the migration, emit `provenance*` fields in new payloads, and continue accepting `lineage*` inputs until all clients are upgraded.

## Design Principles

1. **One neutral model** - Use neutral constructs (Provenance, Cohort, Holding, ReproductiveEvent) with coral-specific presets
2. **Batch + discrete holdings** - Early life stages tracked in batches (volume/count); later stages as discrete items
3. **Place-based** - Every deployment anchored to geometry and site context
4. **Ecosystem & social outcomes** - Align fields to biodiversity credits, carbon MRV, and CSR metrics from day one

### The Five-Axis Canonical Inventory Model

To deliver on those principles every inventory record is expressed via five neutral axes. This “OrganismRecord” abstraction replaces the legacy coral‑specific DTOs (`HoldingRecord`, `Cohort`, coral inventories) and powers CSV v2, repositories, dialogs, and compliance exports.

| Axis | Description | Source / Notes |
| --- | --- | --- |
| **OrganismKind + SpeciesId** | Existing enum + taxonomy reference. | Already live (`OrganismKind`, `SpeciesRegistry`). |
| **ProvenanceType** | Origin of the stock (`wild`, `sexualCohort`, `graduatedIndividual`, `transfer`, `unknown`). `wild` covers corals of opportunity, founder genotypes, and their fragments/clones. | Backed by new `lib/models/types/provenance_type.dart`. Provenance attributes (sire/dam/cohort IDs, wild method) stay bound to this axis. |
| **LifeStage** | Neutral lifecycle stage with optional subtype (e.g., coral "settled recruit"). | Extends the existing life-stage enum with subtype metadata so reporting distinguishes embryos vs. settled juveniles even when the physical form changes. |
| **PhysicalForm (Form Factor)** | Smallest practical handling unit (fragment, settlement substrate, plug, etc.). | Uses `PhysicalFormInstance` with `formId` string, kept organism-aware via metadata and editable per org via admin tooling. Corals' historic coralType becomes a compatibility wrapper over this axis. |
| **Quantity + SizeSpec** | How many physical form units exist and their size band (XS...XL) plus optional measurement (value + unit). | Size band configurations are defined as hardcoded Dart constants in `lib/services/physical_form_data.dart` (community build). |
| **Lifecycle & Measurement History** | `lifeStageHistory` records every transition (from/to stage, timestamp, optional notes + size snapshot); `measurementHistory` captures biomass/size sampling over time. | Backed by `lib/models/mixins/{life_stage_progression_mixin.dart,measurable_mixin.dart}` and serialized with every `OrganismRecord`, `HoldingRecord`, and `Cohort`. |

All repositories, CSV adapters, and UI layers consume these axes rather than `coralTypeId`/`genetTypeId`. Legacy fields continue to serialize until migrations and UI swaps are complete, but the five-axis DTO is the canonical source of truth.

To avoid duplicating lifecycle/measurement logic, `OrganismRecord`, `HoldingRecord`, and `Cohort` now mix in the reusable helpers from `lib/models/mixins/life_stage_progression_mixin.dart` and `lib/models/mixins/measurable_mixin.dart`. The former exposes guardrails (`canProgressTo`, `progressionRequirements`, `appendLifeStageTransition`) backed by `OrganismConstraintsService`, while the latter centralizes unit conversions, size updates, and the serialized `measurementHistory` snapshots used by audits + CSV exports.

#### Change Tracking & Event Emission

**Critical Requirement**: Every modification to an `OrganismRecord` must emit inventory events that document the change. This ensures a complete audit trail for compliance, data integrity, and operational transparency.

**Immutable Fields** (cannot be changed after record creation):
- **`organismKind`**: The organism type (coral in community build) is fundamental to the record's identity and cannot be modified. Attempts to change this field should be rejected with a clear validation error.
- **`speciesId`**: The species classification is immutable. Changing this would represent a different biological entity and should create a new record instead.

**Mutable Fields** (changes must emit events):
- **`lifeStage`**: Life stage transitions (e.g., larva → juvenile → adult) must emit `LifeStageTransitionEvent` with old/new stage, transition reason, and validation metadata. Transitions must be validated against `LifeStageTransitionService` rules (time constraints, size thresholds, environmental triggers).
- **`physicalForm`**: Physical form changes (e.g., spat_bag -> tray_cluster) must emit `PhysicalFormChangeEvent` with old/new physical form and transformation details. Changes must be validated against `OrganismConstraintsService` to ensure valid life stage/physical form combinations.
- **`sizeSpec`**: Size changes (size class or measured value) must emit `SizeChangeEvent` with old/new `SizeSpec` values. This includes both size class transitions (XS → S → M) and measured value updates.
- **`measurement` (quantity)**: Population measurement changes must emit `QuantityChangeEvent` (or extend existing `PopulationGainEvent`/`PopulationLossEvent`) with old/new quantities, gain/loss reasons, and mortality/disease metadata when applicable.

Every time one of the above fields changes we also append entries to `lifeStageHistory` or `measurementHistory` via the lifecycle/measurement mixins so downstream services (CSV exports, audit dialogs) can replay context without scraping event streams.

**Implementation Patterns**:

1. **Change Detection**: Use `OrganismRecordChangeService` to detect differences between old and new `OrganismRecord` instances. This service identifies which fields changed and provides structured change metadata.

2. **Repository Methods**: Repository update methods should:
   - Validate immutability constraints (reject organism/species changes)
   - Detect field changes using the change detection service
   - Create appropriate event instances for each changed field
   - Update the record and emit events atomically in a Firestore batch
   - Create before/after snapshots via `SnapshotService` for audit purposes

3. **Generic Update Method**: The `updateOrganismRecord(record, updatedRecord, comment?)` method provides a single entry point that:
   - Validates all constraints
   - Detects all changes
   - Emits appropriate events for each changed field
   - Performs atomic updates

4. **UI Components**: All dialogs and forms that edit `OrganismRecord` fields must:
   - Display organism/species as read-only fields (clearly marked as immutable)
   - Use specialized editor widgets for each mutable field (life stage transition editor, physical form change editor, etc.)
   - Show validation feedback before submission
   - Display event previews so users understand what will be recorded
   - Integrate with repository update methods to ensure events are emitted

5. **Event Types**: Each mutable field has a dedicated event type:
   - `LifeStageTransitionEvent`: Extends `InventoryEvent` with `oldLifeStage`, `newLifeStage`, `transitionReason`, and validation metadata
   - `MorphologyChangeEvent`: Extends `InventoryEvent` with `oldMorphology`, `newMorphology`, and transformation details
   - `SizeChangeEvent`: Extends `InventoryEvent` with `oldSizeSpec`, `newSizeSpec`
   - `QuantityChangeEvent`: Extends existing population change events with `oldMeasurement`, `newMeasurement`, and reason metadata

**Why This Matters**:
- **Compliance**: Reporting standards (AZA, MRV, CSR) demand complete audit trails of organism lifecycle changes
- **Data Integrity**: Event emission ensures all changes are tracked, preventing data loss or undocumented modifications
- **Operational Transparency**: Field operators and facility managers can review the complete history of organism development, transitions, and transformations
- **Analytics**: Event history enables growth analysis, mortality tracking, and operational efficiency metrics

**See Also**:
- Task list: `taxonomy_task_list.md` sections "2.4 Canonical OrganismRecord Adoption" and "4.4 Reusable UI Components"
- Implementation files: `lib/services/organism_record_change_service.dart`, `lib/models/events/{life_stage_transition_event.dart,physical_form_change_event.dart,size_change_event.dart,quantity_change_event.dart}`

#### Ownership & External References

* **Ownership metadata**: `OrganismRecord` inherits `organizationId` from the parent Firestore path. The community fork has no separate owner/manager fields; transfers are a plain document handoff between organizations.
* **Foreign keys & aliases**: External identifiers (Tracks/ZIMS studbook IDs, Animo IDs, Coral Sample Registry IDs, Galaxy STAG accessions, batch/lot IDs, etc.) are stored as tagged aliases. Each alias captures `{sourceSystem, value}` so CSV imports/exports and UI filters can reference familiar IDs, and we enforce uniqueness per source to prevent multiple local IDs from pointing to the same alias. When organizations intentionally share an alias/provenance ID, `AliasUniquenessService.fetchAlias/linkAliasToExistingRecord` plus `GenetRepository.shareAliasesWithExistingRecord` provide the guardrails so the alias index remains consistent while each org retains its own Local ID, and the Genet profile’s `ShareAliasDialog` exposes the same workflow in the UI.
* **Deterministic provenance IDs**: `ProvenanceIdService` manages the per-species counters for provenance IDs. Repositories request IDs through the service, keeping prefixes/counters consistent and enabling organizations to intentionally reference the same provenance ID when they share a tagged alias.
  * The alias registry is materialized in Firestore under `alias_index/{source::value}` via `AliasUniquenessService`, giving repositories/services a single place to reserve, release, and audit alias ownership.
* **Foreign key map**: For integrations that expect structured payloads, `OrganismRecord` exposes a `foreignKeys` map keyed by canonical system IDs. This allows downstream services to sync with external registries without parsing free-form metadata.

#### Morphology Governance + Admin Overrides

* Built-in morphologies for coral come from SME dictionaries (e.g., `fragment`, `microfragment`, `settlementSubstrate`).
* Physical form configurations are defined as hardcoded Dart constants in `lib/services/physical_form_data.dart`.
* `AllowedPairsMatrix` (generated helper) lists valid `(LifeStage, Morphology)` combinations per organism; the validation service ensures dialogs/CSV imports can only select legal pairs.

## Core Architecture

### Organism Classification & Propagation

The taxonomy service (`lib/services/taxonomy_service.dart`) reads canonical `taxonomy_species` and `taxonomy_provenances` collections in Firestore, enabling organism-aware lookups throughout the app.

#### Species Documents (`taxonomy_species/{speciesId}`)

| Field | Type | Purpose |
| --- | --- | --- |
| `organismKind` | string (enum) | Organism category (`coral`) |
| `genus` / `species` | string | Scientific name components |
| `code` | string | Short code (e.g., `AcPa` for Acropora palmata) |
| `commonNames[]` | string[] | Display-friendly names |
| `aliases[]` | string[] | Alternate codes/IDs |
| `classification` | object | Taxonomy hierarchy (`kingdom` → `family`) |
| `propagationModes[]` | string[] | Reproduction strategies (see below) |
| `metadata` | object | Future-proof organism-specific fields |

**Propagation Modes**:
- `asexualFragmentation` - Coral fragging
- `sexualSpawning` - Broadcast spawning (coral)

#### Provenance Documents (`taxonomy_provenances/{provenanceId}`)

| Field | Type | Purpose |
| --- | --- | --- |
| `organismKind` | string | Links to species entry |
| `provenanceKind` | string | Type: `genet`, `cohort` |
| `displayName` | string | Human-readable label |
| `speciesId` | string | Links to `taxonomy_species/{speciesId}` |
| `parentProvenanceId` | string | Optional parent reference |
| `siteId` | string | Optional GraphNode site reference |
| `aliases[]` | string[] | Alternate identifiers |
| `metadata` | object | Provenance notes and other attributes. |

##### Canonical Species Identifiers

- **Document IDs are the source of truth**: every `speciesId` persisted in Firestore (`OrganismRecord`, holdings, cohorts, provenances), emitted by CSV adapters (`speciesId`), or displayed in admin tooling must match the `taxonomy_species/{speciesId}` document ID (e.g., `species_acropora_cervicornis`). These IDs are immutable and give Pod B’s organism-record services consistent lookup keys.
- **Codes are display-only**: `Species.code` exposes the uppercase shorthand (`APAL`, `ACER`, etc.) for human-facing templates (`speciesCode` columns, UI chips). Do not persist shorthand codes where a canonical ID is required.
- **Registry-backed translation**: `SpeciesRegistry` hydrates from `TaxonomyService.listSpecies()` (or explicit seeds/tests) and installs a global map. CSV adapters (`UniversalCsvAdapterV2`) and repositories consult this registry so inputs (scientific names, shorthand codes, aliases) resolve to canonical IDs before validation.
- **Importer enforcement**: `InventoryCsvImporter`, genetics importers, and the organism-record services reject rows/documents whose `speciesId` fields are missing or non-canonical, preventing mixed identifier schemes inside Firestore.

## Architecture Decisions

### ADR-001  Coral Inventory Model

**Current status**
- `OrganismKind` exposes organism metadata (default units, supported structures, default site types) that downstream services can consume.
- `TaxonomyService` resolves species and provenances directly from Firestore (or emulator seeds) so repositories and CSV adapters no longer rely on hard-coded enums. Each environment must seed the taxonomy collections (or tests must install `TestSpeciesCatalog`) before organism-aware flows run.

```dart
// lib/models/types/organism_kind.dart (community build - coral only)
enum OrganismKind {
  coral,
}
```

```10:57:lib/services/taxonomy_service.dart
/// Provides cached access to the canonical species + provenance collections stored
/// in Firestore so repositories, CSV adapters, and dialogs can resolve taxonomy
/// metadata without hard-coding coral-only enums.
class TaxonomyService {
  TaxonomyService({
    required FirebaseFirestore firestore,
    Duration cacheTtl = const Duration(minutes: 30),
  })  : _firestore = firestore,
        _cacheTtl = cacheTtl;
```

**Gaps & next steps**
- `InventoryRecordRepository` still contains coral-specific branching when creating/moving records; neutral holdings will replace this logic once `ProvenanceBase`/`PopulationMeasurement` land.

```49:53:lib/repositories/inventory/inventory_record_repository.dart
    if (fullRecord is Coral && parent is Group) {
      fullRecord =
          fullRecord.copyWith(siteId: parent.siteId, groupId: parent.id) as T;
    }
```

- Core model backlog (ProvenanceBase, LifeStage, MeasurementUnit, cohort/holding adapters) tracks the remaining work.

```9:39:taxonomy_task_list.md
- [ ] **Create ProvenanceBase interface** 
  - File: `lib/models/provenance_base.dart` (NEW)
  - Purpose: Abstract interface for Genet and other provenance types
  - References: ADR-001
- [ ] **Adapt Genet to implement ProvenanceBase**
  - File: `lib/models/genet.dart`
  - Line: Add `implements ProvenanceBase` to class declaration
  - Purpose: Backwards-compatible provenance abstraction
- [ ] **Create LifeStage enum**
  - File: `lib/models/types/life_stage.dart` (NEW)
  - Purpose: Replace CoralType with neutral lifecycle stages
```

### ADR-002  Facility & Structure Enum Governance

**Current status (Community Build)**
- `SiteType` supports `nursery` and `outplanting` (coral-specific).
- `GroupType` provides coral-specific structures (tank, raceway, tree, dome, reebarTable, cradle, aframe, group, patch).
- Legacy site type aliases (`site_type_nursery_ex_situ`, `site_type_nursery_in_situ`) map to the consolidated `nursery` type via `SiteType._legacyAliases`.

```dart
// lib/models/types/site_type.dart (community build)
static final Map<String, SiteType> builtins = {
  nursery.id: nursery,
  outplanting.id: outplanting,
};
```

### ADR-003  Organism-Aware Repositories

**Current status**
- Coral and Genet repositories accept an `OrganismContext`, giving DI a path to swap organism presets.

```16:28:lib/repositories/inventory/genet_repository.dart
  GenetRepository({
    required super.organization,
    required super.user,
    required super.eventRepository,
    super.snapshotService,
    OrganizationRepository? organizationRepository,
    required super.firestore,
    OrganismContext? organismContext,
  }) : super(
         modelType: ModelType.genet,
         organismContext:
             organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       ) {
```

**Gaps & next steps**
- Event repositories still need context threading and organism-aware validation.

```84:109:taxonomy_task_list.md
- [ ] **Update EventRepository base**
  - File: `lib/repositories/inventory/event_repository.dart`
  - Lines: 153-249
  - Task: Thread OrganismContext through event creation methods
```

### ADR-004  Universal CSV v2 Contract

**Current status**
- The code-native CSV v2 spec enumerates organism, MRV, and CSR fields that adapters enforce.
- Inventory fixtures + CSV dialog previews highlight site columns (siteId/siteName, siteJurisdiction, geometry) so compliance metadata is visible.
- `InventorySpreadsheetCubit` feeds coral holdings into inventory exports via the universal CSV template.

```6:13:lib/services/csv/v2/csv_v2_spec.dart
/// Mirrors `SeaFoundry_Universal_CSV_v2_spec.json` so adapters, validators,
/// and UI layers can reason about the new organism-aware schema without
/// duplicating string literals throughout the codebase.
///
/// The data below is sourced from:
/// - `README.md` - Consolidated coral inventory architecture and CSV v2 schema
/// - `SeaFoundry_Universal_CSV_v2_spec.json`
```

**Gaps & next steps**
- Template upgrades, adapter tests, and migration tooling are tracked in the backlog.

```239:247:taxonomy_task_list.md
- [ ] **Firestore migration script**
  - File: `scripts/migrations/add_organism_metadata.ts` (NEW)
  - Task: Backfill existing records with organismKind=coral
- [ ] **CSV template updates**
  - Directory: `docs/csv/examples/`
  - Task: Update all templates to v2 format
  - Add organismKind, measurementUnit fields
```

### ADR-005  Observation Field Registry

**Current status**
- `ObservationFieldRegistry` maps `(OrganismKind, RecordType, LifeStage)` scopes to `ObservationDialogDefinition`s, captures `siteCapability.*` flags, and now ingests YAML/JSON overrides through `ObservationFieldOverrideService` so a Firestore doc can reshape dialog fields at runtime.
- `recordTypeId` values in overrides are trimmed + case-insensitive, so `"nurseryHoldings"`, `"NurseryHoldings"`, and `"NURSERYHOLDINGS"` all target the same definition. Invalid YAML no longer wipes existing overrides—the service validates the payload, logs the error, and keeps the previous definitions active until a fixed document lands.
- The override service hydrates default presets on startup before layering organization-specific Firestore docs (stored under `observation_field_overrides/{organizationId}` with either a `yaml` string or raw `overrides[]` payload).
- `ObservationDialogConfig` pulls definitions from the registry, caches them per organism/record type/life stage, and exposes the capability metadata so dialogs, CSV adapters, and action dock gating stay in sync.
- `ObservationTilesBuilder` reads the new metadata and disables tiles when a site’s capabilities (frag/move/outplant/environmental adjustment/monitoring FAB) do not satisfy the registry contract. This prevents users from launching unsupported dialogs while still surfacing guidance inside the action sheet.
- `TaxonomyAdminPanel` includes an **Overrides** tab that loads Firestore YAML, falls back to the bundled defaults, validates payloads locally, surfaces legacy JSON conversions + last updated metadata, exposes a version history timeline (load snapshot, diff vs editor, copy YAML, apply with confirmation), provides inline override audit entries with action/search filters plus drill-down sheets, offers a manual “Reload registry” action, refreshes the in-memory registry after each save, and persists changes on behalf of the signed-in organization with role-aware read-only behavior.

#### CLI Compliance Bundle Exporter

`scripts/overrides/download_compliance_bundle.dart` exposes the same `OverridesComplianceExporter` flow outside the UI so ops/automation can pull zipped CSV+JSON bundles for tickets:

```bash
flutter pub run scripts/overrides/download_compliance_bundle.dart \
  --org=my-org-id \
  --note-token "Ticket-123" \
  --limit 3 \
  --output ~/Downloads/overrides_ticket123.zip \
  --initiated-by "auditor@example.org"
```

- `--history=<id1,id2>` downloads specific snapshots (IDs appear in the Overrides history table and taxonomy audit log).  
- `--note-token` + `--limit` mirror the history filters when you just need the latest ticket-related snapshot.  
- `--output` controls where the zip lands (defaults to the current directory), and `--initiated-by` is recorded in the JSON metadata.  
- An npm alias is available: `npm run overrides:download -- --org=...` so CI/ops scripts can share the same entrypoint.

The script initializes Firebase with `lib/firebase_options.dart`, reuses `ObservationFieldOverrideService.fetchOverrideHistoryByIds` to target rows deterministically, and delegates to `OverridesComplianceExporter`, ensuring CLI bundles match the UI artifacts byte-for-byte.

To queue multiple exports at once, use the plan runner:

```bash
npm run overrides:download:plan -- --plan scripts/overrides/plans/compliance_bundle.plan.json
```

Each plan entry can define an org, filters, history IDs, output directory, and metadata so release engineers can audit multiple tickets in a single run (pass `--dry-run` to see the Flutter commands without executing them).

**Gaps & next steps**
- Extend the overrides tab with Firestore version history (multiple revision diffs + rollback) so admins can safely reason about prior changes, and layer in organization-scoped history so changes can be audited outside of the raw collection viewers.
- Extend action dock messaging with site-specific hints (e.g., capability summaries).

## Organism-Specific Architectures

### Coral
- **Lifecycle**: Recruits, Juveniles, Colonies, Fragments
- **Tracking**: Individual fragments/colonies with `genet` provenance
- **Metrics**: % live tissue, bleaching severity, disease presence
- **Structures**: Tanks, raceways, trees, domes, reebarTables, cradles, aframes, groups, patches

## Data Model Evolution

### Phase 1: Core Abstractions (Current Priority)

#### New Core Types
- `lib/models/types/organism_kind.dart` - Organism enumeration
- `lib/models/types/life_stage.dart` ✅ - Development stages (implemented Jan 14)
- `lib/models/types/measurement_unit.dart` ✅ - Units system with canonical IDs/metadata (implemented Jan 14)
- `lib/models/population_measurement.dart` ✅ - Value + unit wrapper for batch holdings (implemented Jan 14)
- `lib/models/provenance_base.dart` ✅ - Interface for all provenances (implemented Jan 14)
- `lib/models/inventory/holding_record.dart` ✅ - Neutral holding abstraction w/ coral migration helper (implemented Jan 14)
- `lib/models/inventory/holding_attributes.dart` ✅ - Typed species/geometry metadata for holdings/CSV DTOs
- `lib/models/cohort.dart` ✅ - Cohort DTO built on PopulationMeasurement (implemented Jan 14)

#### Batch Holdings
- `lib/models/cohort.dart` - General batch tracking

#### Repository Evolution  
- `OrganismContext` injection throughout repositories
- Factory pattern in `RepositoriesProvider`
- Backwards-compatible Genet → ProvenanceBase adapters

### Phase 2: Service Layer

#### Key Services
- `ObservationFieldRegistry` - Dynamic field configuration by organism/stage with automatic cache invalidation for dialogs
- `SiteBaselineService` - Environmental baseline management (writes server timestamps + `updatedBy` so audits are trustworthy across clients)
- `ReproductiveEventRepository` - Sexual/asexual reproduction tracking
- `SyncManager` - Offline queue + registry sync coordinator; replays now include conflict detection (writing rows to `sync_conflicts/{operationId}` + local `SyncConflictEntry`s) and wrap move/event creation in `EventRepository.withTimestampOverride` so snapshots retain the original offline timestamp. The paired `SyncConflictResolutionService` powers UI/CLI flows for replaying or dismissing conflicts with audit metadata.

### Resolving Offline Conflicts

- **Admin UI**: `Settings > Taxonomy Admin > Conflicts` lists both remote (`sync_conflicts`) and on-device conflicts. Use the filters (organization, record type, reason, resolution) plus the Replay/Dismiss buttons to act on each entry. Replay queues the original payload back into the offline queue; Dismiss records resolution notes for future audits.
- **CLI**: `npm run conflicts:resolve -- --id=<conflictId> --action=export --export=/tmp/conflict.json` dumps the persisted payload for editing, and a follow-up `npm run conflicts:resolve -- --id=<conflictId> --action=replay --payload=/tmp/conflict.json --user=<uid> [--metadata=/tmp/meta.json] [--notes="context"]` replays the edited payload (use `--action=dismiss` to acknowledge without replaying). The script reads/writes `sync_conflicts/{id}` so Firestore stays authoritative.

## CSV v2 Schema

The universal CSV v2 format uses canonical fields:

```
organismKind, species, provenanceId, cohortId, lifeStage, measurementUnit, quantity,
siteId, enclosure, inSituRow, inSituCol, geometry, eventType, eventDate, habitatType,
protectedAreaFlag, carbonPool.*, stock_tCO2e, flux_tCO2e_yr, uncertaintyPct,
permanenceRiskScore, volunteerHours, trainingHours, credentialId, irisMetricIds[],
sdgTargets[]
```

**Key Features**:
- Coral-specific validation rules
- Measurement unit enforcement
- Geometry support (point/multipoint/polyline)
- MRV/CSR field capture
- Five-axis inventory columns (`provenanceType`, `lifeStage`, `lifeStageSubtype`, `physicalFormId`, `quantity`, `sizeBandId`, `sizeClass`) derived from the canonical `OrganismRecord`.
- Backwards compatibility via v1→v2 adapter

## Environmental & Compliance Integration

### Environmental Baselines
- Site-level parameters with history tracking
- Monitoring events can update baselines
- Key parameters for coral:
  - Marine: temperature, salinity, DO, pH, nutrients
  - Benthic: substrate type, depth, light penetration
- Baseline data is stored in Firestore `site_baselines/{siteId__organism}` docs with caching, CRUD helpers, fallback-to-site logic (when organism-specific baselines are absent), and live streams so dialogs can read/write baselines without duplicating Firestore code.
- Baseline exports: `UniversalCSVDialog` exposes the Site Baselines template so organizations can download the canonical CSV (`CsvTemplateKind.siteBaselines`) via `ExportService.exportSiteBaselineCSV`.
- Species registry hydration: `RepositoriesProvider` loads Firestore taxonomy data at startup and feeds it into `Species.replaceAll`, so every legacy species lookup now sees live taxonomy entries without any coral-only fallback. If the taxonomy collections are empty the registry remains empty, making taxonomy seeding a required setup step.
- Site metadata: `Site` documents carry a `supportedOrganismKinds` whitelist (defaulting to the site type’s capability matrix) so GraphNode actions + `SiteCapabilityGuard` can gate workflows appropriately.
- Graph action dock: `GraphNodeActions` reads the active organism context and injects it into FAB categories.
- Structure capacity overrides: Organization admins can author YAML-equivalent overrides in Settings → “Structure Capacity Overrides.” Child-structure rules are enforced immediately; occupant rules will be wired into holding/cohort repositories next so bag/pen/pond density limits trigger the same guards in-app.

### Taxonomy Seeding
- The community build seeds taxonomy data for coral species (APAL/ACER).
- See `scripts/seed-demo.js` for the community demo seeding workflow.

### Taxonomy Admin Tooling Roadmap

| Capability | Description | Status |
| --- | --- | --- |
| Species/Provenance listing | Search/filter Firestore taxonomy collections, view organism/species metadata, and hydrate local emulators | ✅ Tabbed listing UI with filtering |
| Species CRUD | Create/update/delete species with validation (unique IDs/codes, organism constraints) and audit logs | In Progress |
| Provenance CRUD | Manage provenance parents, site links, organism-specific metadata, and alias labels | In Progress |
| Role gating & audit trail | Restrict UI/service entry points to admin roles and capture immutable audit docs | ✅ Read-only gating, provenance metadata locking, and audit drill-down sheets landed |

- **Service layer**: `TaxonomyAdminService` provides fetch/upsert/delete helpers, now emitting `taxonomy_audit` documents for every mutation.
- **UI shell**: `TaxonomyAdminPanel` exposes tabbed species/provenance lists with search/filter controls, alias/notes inputs, parent/site selectors, and an audit log tab powered by `taxonomy_audit` data.
- **Emulator prep**: `npm run seed:taxonomy:emulator` hydrates `FakeFirebaseFirestore`/emulator instances before running widget/integration suites so taxonomy-driven flows function offline.
- **Next steps**: Extend provenance/site linking (site lookup widgets, parent selectors) now that role gating and audit drilldowns are in place.

### Migration & Bundle Tooling

The `migrationplanv2` automation (`build_seafoundry_bundle.py`) produces a reference bundle that includes:

- Generated Dart scaffolds for the five-axis enums, `OrganismRecord`, CSV spec extensions, validation matrices, and a size-mapping service stub.
- TypeScript migration helpers (e.g., `scripts/migrations/coral_type_to_axes.ts`) that backfill legacy coral documents with `lifeStage`, `physicalFormId`, `sizeClass`, and `provenanceType` based on the official crosswalk (gamete -> vial/gamelike, fragment -> juvenile/fragment, etc.).
- Documentation snapshots (`docs/data_dictionary.md`, `docs/reference_notes_full.md`) summarizing the schema, organism lifecycles, CSV requirements, compliance hooks, and the 18‑month roadmap.

We treat the bundle as an accelerator: the generated files are merged into the existing modules (instead of living under a separate bundle tree) and any gaps are filled by our real services (`OrganismContext`, repositories, CSV adapters).

### MRV & Carbon Accounting
- Blue carbon pools: biomass, soil, dissolved
- Stock & flux measurements with uncertainty
- Permanence risk scoring
- Verifier metadata for credits

### CSR & Social Impact
- Volunteer hours tracking
- Training credentials
- Local hiring metrics
- IRIS+ indicator alignment

## Implementation Strategy

### Immediate Actions (Coral Sustainment)
1. Add measurement units to existing coral forms
2. Begin CSV v2 spec development
3. Implement neutral types in parallel

### Foundation Building
1. Deploy OrganismKind throughout codebase
2. Create Genet → ProvenanceBase adapters
3. Add batch holding types
4. Seed taxonomy collections

### Critical Dependencies
- CSV v2 must include all canonical fields
- Firestore indexes for organism queries
- Offline queue v1/v2 compatibility
- Feature flags per organization

## Testing Strategy

### Integration Tests
- Coral inventory workflows
- CSV import/export flows

### Regression Tests
- Coral workflows unchanged
- CSV v1 imports compatible
- Offline queue mixed versions

## Architecture Patterns
1. **Trait-Based Composition** - Mix PropagationCapable, EnvironmentSensitive
2. **Registry Pattern** - ObservationFieldRegistry, MeasurementUnitRegistry
3. **Strategy Pattern** - PropagationStrategy, MonitoringStrategy
4. **Adapter Pattern** - Legacy model → neutral interface migrations

## Code Reuse & Extension Patterns

### Registry Pattern
The `ObservationFieldRegistry` demonstrates a proven pattern for scoped configurations that can be extended to other domains:

**Key Characteristics**:
- Scoped entries keyed by `(OrganismKind, RecordType?, LifeStage?)`
- Runtime registration with YAML/JSON override support
- Listener notifications for cache invalidation
- Scope matching with fallback resolution

**Applications**:
- `ValidationRuleRegistry` - Size ranges, density limits, physical form constraints
- `MortalityCauseRegistry` - Mortality reasons

**Benefits**:
- Centralizes configuration, supports runtime overrides
- Enables admin tooling without code changes
- Consistent patterns across services reduce cognitive load

#### YAML Publishing Workflow
- The **Taxonomy Admin Panel** now hosts dedicated tabs for Morphologies, Environmental Thresholds, Husbandry Schedules, Validation Rules, and Mortality Causes. Each tab loads the bundled defaults, validates edits, previews parsed registries, persists overrides in `taxonomy_overrides/{docId}`, and queues the matching `SyncManager` task so Supabase/org exports stay aligned with Firestore overrides.
- After updating YAML files in `config/*.defaults.yaml`, run `npm run sync:taxonomy-configs -- --updatedBy=<userId>` (Node-based Firebase Admin CLI; add `--dry-run` to preview) to copy those defaults into Firestore. The script relies on `TaxonomyAdminService`, so the same validation/audit path is used whether changes originate from the UI or CLI.
- Automation hooks should run `scripts/sync_taxonomy_configs.dart` (or `npm run sync:taxonomy-configs`) whenever environments are reset, guaranteeing that seed data, registries, and CSV exports reference the latest YAML without manual intervention.

### Base Class Extensions
Instead of creating new repository/service patterns, extend existing infrastructure:

**Repository Pattern**:
- Extend `InventoryRecordRepository` for new holding types
- Use `OrganismContext` injection consistently
- Leverage existing CRUD operations and stream management

**Dialog Pattern**:
- Extend `BaseAsyncDialog` for async operations
- Use `BaseSearchDialog` for entity selection
- Apply `DialogLifecycleMixin` for lifecycle management
- Extend `UserAwareDialogBase` for user/org context

**Service Extension**:
- Add methods to existing services as needed
- Use dependency injection for context-aware behavior
- Leverage existing validation and error handling

### Mixin Patterns
Create reusable mixins for common behaviors:

**LifeStageProgressionMixin** (`lib/models/mixins/life_stage_progression_mixin.dart`):
- Shared helper for `OrganismRecord`, `HoldingRecord`, and `Cohort`
- Methods: `canProgressTo()`, `timeUntilNextStage()`, `progressionRequirements()`, `appendLifeStageTransition()`
- Persists `lifeStageHistory` entries with timestamps/notes/size snapshots and validates transitions via `OrganismConstraintsService`

**MeasurableMixin** (`lib/models/mixins/measurable_mixin.dart`):
- Normalizes measurement math (unit conversion, delta application, scaling) and `SizeSpec` updates
- Provides `appendMeasurementSnapshot()` so repositories/events can record biomass sampling tied to metadata
- Backed by canonical measurement + size spec on `OrganismRecord`, reused by holdings/cohorts without duplicating conversions

### Composition Over Inheritance
Prefer composition strategies for flexible behavior:

**Strategy Pattern for Behaviors**:
```dart
abstract class GrowthStrategy {
  double calculateGrowth(OrganismRecord organism, Duration period);
}

class CoralGrowthStrategy implements GrowthStrategy { }
```

**Builder Pattern for Complex Objects**:
```dart
class OrganismRecordBuilder {
  OrganismRecordBuilder withLifeStage(LifeStage stage);
  OrganismRecordBuilder withMorphology(Morphology morph);
  OrganismRecordBuilder withMeasurement(PopulationMeasurement measurement);
  OrganismRecord build();
}
```

## Husbandry Workflow Patterns

### Batch Management Workflows
- **Splitting**: Dividing cohorts based on size grading or density reduction
- **Combining**: Merging compatible cohorts (same provenance, age, conditions)
- **Graduation**: Transitioning between life stages with physical form changes
- **Culling**: Recording mortality events with cause tracking

### Life Stage Progression Rules
- Enforce valid transitions (e.g., larvae cannot skip to adult)
- Time-based constraints (minimum days between stages)
- Environmental triggers (temperature for spawning readiness)

### Morphology Transitions
- Valid transformations (spat_bag → tray_cluster requires grading event)
- Size class progression (XS→S→M requires growth monitoring)
- Density-based splits (overcrowded bags trigger split workflow)

## Environmental Integration & Thresholds

### Critical Parameters (Coral)

| Organism | Critical Parameters | Alert Thresholds | Response Actions |
|----------|-------------------|------------------|------------------|
| Coral | Temperature, Light | >30°C, PAR <200 | Shade, relocate |

### Threshold Monitoring
- Real-time parameter tracking against configured limits
- Alert generation with suggested response actions
- Historical trend visualization for pattern detection
- Integration with SiteBaselineService for baseline comparisons

## Migration Path

### Phase 0: Current State ✅
- Taxonomy service infrastructure deployed
- CSV v2 spec drafted
- Organism context plumbing started
- ADRs documented

### Phase 1: In Progress 🔄
- Thread OrganismContext through repositories
- Complete CSV v2 import/export
- Seed taxonomy collections
- Update all CSV templates

### Phase 2: Upcoming 📅
- Implement batch holdings
- Add environmental baselines
- Create coral-specific presets

### Phase 3: Future 🔮
- Enhanced coral analytics
- Pilot deployments

## References

### Standards & Protocols
- GHG Protocol (Land & Removals)
- ISSB IFRS S2, TNFD v1, GRI 101
- Verra VM0033 (Blue Carbon)
### Restoration Guidance
- NOAA Restoration Center
- Reef Resilience Network

### Data Standards
- Darwin Core (biodiversity)
- OBIS-ENV (marine observations)
- CF Conventions (climate/forecast)

---

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
