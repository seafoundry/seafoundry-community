# Data Field Unification: Single Source of Truth (SOT)

**Status**: 🔄 In Progress
**Priority**: P0 - Data Integrity Critical
**Labels**: `data-model`, `inventory`, `genetics`, `csv`, `firebase`, `breaking-change`

## Summary

Unify duplicate/overlapping data fields to establish a single source of truth for all ID types, creation paths, and dialog flows. This addresses data integrity issues discovered in the organism creation, genet linkage, and CSV import/export systems.

**Context**: Production database will be wiped. No legacy data migration or backwards compatibility required.

## Critical Issues Identified

| Issue | Severity | Status |
|-------|----------|--------|
| `genetId` extension shadows top-level field | **Critical** | Open |
| Outplant allocation stores provenance ID as organism ID | **Critical** | Open |
| `provenanceId` confused with doc ID | High | Open |
| Multiple organism creation paths with different field handling | High | **Resolved** - Wizard is now canonical |
| ~~Health status vs observation dialog overlap~~ | ~~High~~ | Removed in community fork |
| Export uses stale foreign key metadata | Medium | Open |
| Legacy morphologyId/sizeClass in persisted metadata | Medium | In Progress |
| `foreignKeys['genet']` legacy key used in 18+ files | Medium | Open |
| `OutplantAllocation.organismId` stores two different ID types | **Critical** | Open |

### Issue Details

| Issue | Root Cause |
|-------|------------|
| `genetId` extension shadows top-level field | `organism_extensions.dart:295` returns `foreignKeys['genetId']?.id`, ignoring `OrganismRecord.genetId` |
| Outplant allocation stores provenance ID as organism ID | CSV importer stores `organism_provenanceId` directly into `organismId` field |
| `OutplantAllocation.organismId` dual-semantics | Interactive outplanting stores Firestore doc ID; CSV import stores provenance ID in same field |
| `provenanceId` confused with doc ID | `getByProvenance()` compares provenance IDs to genetId (doc IDs) |
| ~~Multiple organism creation paths~~ | ~~`OrganismCollectionDialog` sets `genetId` in metadata, wizard sets top-level~~ **Fixed**: All call sites now use `OrganismCreationWizard.showAndCreate` |
| ~~Health status vs observation dialog overlap~~ | ~~Two paths for "health" with different persistence rules~~ (dialogs removed in community fork) |
| Export uses stale foreign key metadata | `inventory_export_row_source.dart` reads from FK metadata, not genet record |
| Legacy morphologyId/sizeClass in persisted metadata | Multiple fields for physical form identity |
| `foreignKeys['genet']` legacy key | Parallel to `foreignKeys['genetId']` in 18+ files with inconsistent fallback ordering |

## Decisions

- **genetId**: Top-level `OrganismRecord.genetId` is canonical. Remove extension getter that shadows it.
- **foreignKeys['genetId']**: Denormalized copy only. Must be synced at write time; enforce equality.
- **foreignKeys['genet']**: Legacy key. Consolidate to `foreignKeys['genetId']` everywhere. Remove `foreignKeys['genet']` writes; keep reads as temporary fallback during transition, then remove.
- **Provenance ID**: Always a lineage identifier (format: `PID-*` or `SF-*`). Never a Firestore doc ID.
- **Organism ID**: Always a Firestore document ID. Never a provenance/lineage ID.
- **OutplantAllocation.organismId**: Must always be a Firestore doc ID. CSV import must resolve organism by provenance ID and store the doc ID.
- **Field storage**: Remove all legacy fallbacks to `metadata['genetId']`, `metadata['provenanceId']` for new code paths.
- **Physical Form**: Use `physicalFormId` only; fully remove `morphologyId` from all persisted metadata. The word "morphology" in method names and UI strings should be renamed to "physical form" where it refers to the physical form concept. `SizeSpec.sizeClass` is a **canonical field** and is NOT removed.
- **sizeClass scope**: Only remove `metadata['sizeClass']` and `metadata['size']` legacy reads. Do NOT remove `SizeSpec.sizeClass` (canonical) or `SizeSpec.sizeBandId` usage.
- **CSV v1**: Purge all `universal_csv_v1` references from tests, docs, and assets; no v1 compatibility.
- **lineageId**: Remove immediately (Phase 1) since DB will be wiped. No backward compat needed.
- **foreignKeys fallback order**: Always check `genetId` before `genet` (standardize reversed order in `outplanting_service.dart`).

---

## Review Committee Process

After each phase, the review committee (system architect, deep logic specialist, QAQC specialist) reviews the implementation. Implementation teams address ALL findings before proceeding to the next phase.

```
Phase N Implementation
    |
    v
Review Committee (parallel):
  - System Architect: architecture coherence, dependency analysis
  - Deep Logic Specialist: correctness, edge cases, state transitions
  - QAQC Specialist: exhaustive file coverage, test gaps, grep sweeps
    |
    v
Fix Findings
    |
    v
Phase N+1
```

---

## Completed Work

### Legacy CSV v1 Removal (partial)

- [x] Deleted `csv_v1_to_v2_adapter.dart`
- [x] Deleted `inventory_csv_upgrade_service.dart`
- [x] Deleted all CSV v1 adapter tests
- [x] Removed wiring from `csv_import_coordinator.dart`
- [x] Removed `package.json` scripts for organism-record backfill

### Legacy Coral Type Mapper Removal

- [x] Deleted `legacy_coral_type_mapper.dart`
- [x] Deleted legacy coral type mapper tests

### Legacy Migration/Audit Scripts Removal

- [x] Deleted `coral_type_to_axes.ts`
- [x] Deleted `run_organism_record_backfill.js`
- [x] Deleted `organism_record_backfill.plan.json`
- [x] Deleted `audit_cohort_coral_metadata.js`
- [x] Cleaned old backfill report JSONs

### CSV Templates Updated

- [x] `Coral_template.csv` - updated to canonical fields

### CSV Fixtures Updated

- [x] `coral_inventory_sample.csv`
- [x] `coral_larval_sample.csv`
- [x] `universal_inventory_geometry_sample.csv`

### Import/Export Code

- [x] Removed `coral_type`/`morphology`/`size_class` fallbacks from inventory import
- [x] Updated `sizeSpec` usage in import/export

### Organism Creation Consolidation

**Summary**: `OrganismCreateDialog` removed. All call sites use `OrganismCreationWizard.showAndCreate`.

**Completed**:
- [x] `OrganismCreateDialog` removed entirely
- [x] Wizard supports initial params + additional metadata + persistence callback
- [x] `showAndCreate` persistence flow with validation, capacity check, genet creation
- [x] All 7 call sites migrated to `OrganismCreationWizard.showAndCreate`

---

## Phase 0: Verification of Prior Work

**Must complete before Phase 1.** Verify all tasks marked as completed are actually complete.

### 0.1 Verify File Deletions

- [ ] `csv_v1_to_v2_adapter.dart` deleted
- [ ] `inventory_csv_upgrade_service.dart` deleted
- [ ] `legacy_coral_type_mapper.dart` deleted
- [ ] `coral_type_to_axes.ts` deleted
- [ ] `run_organism_record_backfill.js` deleted
- [ ] `audit_cohort_coral_metadata.js` deleted
- [ ] `organism_create_dialog.dart` deleted

### 0.2 Verify No Legacy References

- [ ] `rg 'CsvV1ToV2Adapter|InventoryCsvUpgradeService' lib/` = zero hits
- [ ] `rg 'LegacyCoralTypeMapper' lib/ test/` = zero hits
- [ ] `rg 'OrganismCreateDialog\.show' lib/` = zero hits
- [ ] `rg 'showAndCreate' lib/widgets/dialogs/organism_creation_wizard/organism_creation_wizard.dart` = found
- [ ] `OrganismCreationResult` has `clonalValue` and `accessionValue` fields

### 0.3 Verify CSV Templates (CORRECTED PATHS)

**Note**: Templates live at `docs/csv/examples/`, NOT `assets/templates/`.

- [ ] Verify template CSVs have `physical_form_id`, no `coral_type`/`morphology` columns
- [ ] Verify fixture CSVs at `docs/csv/fixtures/` use v2 format

### 0.4 Delete Remaining v1 Artifacts

- [ ] Delete `assets/csv/universal_inventory_v1_template.csv` (v1 template still exists)
- [ ] Delete or update `test/unit/widgets/organism_create_dialog_capacity_test.dart` (references deleted class)

### 0.5 Run Static Analysis

- [ ] `flutter analyze` — note errors
- [ ] `flutter test --tags smoke` — verify basics
- [ ] Document any failures

### 0.6 Phase 0 Review Gate

**Review Committee**: Verify Phase 0 completeness before proceeding.

---

## Phase 1: Critical Blocking Fixes + Quick Wins

Serial execution. Must complete before any Phase 2 work.

### 1.1 Fix genetId Extension Shadowing

**Files**:
- `lib/models/inventory/organism_extensions.dart`
- `lib/models/inventory/organism_record.dart`

**Tasks**:
- [ ] Remove extension getter at line 295: `String? get genetId => foreignKeys['genetId']?.id;`
- [ ] Add `resolvedGenetId` getter: `genetId ?? foreignKeys['genetId']?.id`
- [ ] Audit all call sites importing `organism_extensions.dart` that reference `genetId` to determine intended behavior
- [ ] Run `flutter analyze` and fix all breakages
- [ ] Run `flutter test --tags unit`

### 1.2 Create GenetIdResolver Service

**Extracted from Phase 2A.1 to unblock both Team Alpha and Team Beta.**

**Files**:
- `lib/services/genet_id_resolver.dart` (new)

**Tasks**:
- [ ] Create `GenetIdResolver` class with static methods:
  - `static String? resolve(OrganismRecord record)` — canonical: `genetId ?? foreignKeys['genetId']?.id`
  - `static bool isValid(String? genetId)` — format validation
  - `static void assertConsistency(OrganismRecord record)` — throws if top-level != foreignKey
- [ ] Add unit tests in `test/unit/services/genet_id_resolver_test.dart`

### 1.3 Fix Outplant Allocation ID Mismatch

**Files**:
- `lib/services/csv/import/importers/outplant_allocations_csv_importer.dart`
- `lib/constants/csv_schema.dart`
- `lib/models/outplant_allocation.dart` (or wherever the model lives)

**Tasks**:
- [ ] Rename CSV column from `organism_provenanceId` to `organism_id`
- [ ] Add validation: reject values matching provenance ID format (`^(PID|SF)-`)
- [ ] Fix dual-semantics: CSV import must resolve organism by provenance ID lookup, then store the Firestore doc ID
- [ ] Add import error message: "organism_id must be a Firestore document ID, not a provenance ID"
- [ ] Audit all consumers of `OutplantAllocation.organismId` for ID type assumptions

### 1.4 Remove lineageId Immediately

**Since DB will be wiped, no backward compat needed.**

**Files**:
- `lib/models/inventory/holding_record.dart` — remove `lineageId` from `toJson()` and `fromJson()` fallback
- `lib/models/cohort.dart` — same

### 1.5 Phase 1 Review Gate

**Review Committee reviews Phase 1 before proceeding to Phase 2.**

---

## Phase 2: Parallel Team Tracks

After Phase 1 completes AND review gate passes, these tracks run with the following dependency structure:

```
Phase 1 complete
    |
    ├─── Team Alpha (ID Fields) ──┐
    │                              ├── Team Beta (Provenance) depends on Alpha
    ├─── Team Gamma (Dialogs) ────┤
    ├─── Team Delta (CSV) ────────┤
    ├─── Team Foxtrot (Physical Form) ──┤
    │                                    │
    │    [Alpha+Beta complete] ──────────┤
    │                                    │
    └─── Team Echo (Firebase/Scripts) ───┘  (starts after Alpha+Beta)
```

**Parallelizable**: Alpha, Gamma, Delta, Foxtrot start simultaneously.
**Sequential**: Beta starts after Alpha completes. Echo starts after Alpha+Beta complete.

---

### Team Alpha: ID Field Unification

**Goal**: Single source of truth for all ID fields across models. Consolidate `foreignKeys['genet']` to `foreignKeys['genetId']`.

#### 2A.1 Sync genetId at Write Time

**Files**:
- `lib/repositories/inventory/organism_record_repository_mutations.dart`
- `lib/services/csv/import/importers/inventory/organism/organism_metadata_updater.dart`

**Tasks**:
- [ ] In `createRecord()`: if `genetId` is set, also set `foreignKeys['genetId']`
- [ ] In `updateRecord()`: sync both fields if either changes
- [ ] Wire `GenetIdResolver.assertConsistency()` at write time
- [ ] Remove separate update paths that only set one field

#### 2A.2 Consolidate foreignKeys['genet'] → foreignKeys['genetId']

**This is NEW work identified by the review committee. 18 files use `foreignKeys['genet']`.**

**Files (consumers)**:
- `lib/models/inventory/inventory_export_row.dart`
- `lib/services/transfer_service_validation.dart`
- `lib/services/inventory_events_resolution_service.dart`
- `lib/services/outplanting_service.dart` — also fix reversed priority (check `genetId` before `genet`)
- `lib/services/state_reconstruction_service.dart`
- `lib/services/event_history_service.dart`
- `lib/services/survival_calculation_service.dart`
- `lib/services/metadata_extraction_service.dart`
- `lib/services/inventory_hydration/inventory_event_hydration_service.dart`
- `lib/services/inventory_hydration/inventory_event_hydrator.dart`
- `lib/services/inventory_hydration/general_event_hydrator.dart`
- `lib/services/inventory_hydration/hydration_result.dart`
- `lib/services/export/inventory_snapshot_row_builder.dart`
- `lib/services/inventory/inventory_snapshot_service.dart`
- `lib/repositories/inventory/organism_record_repository_queries.dart`
- `lib/repositories/inventory/organism_record_repository_mutations.dart`
- `lib/services/transfer_service_manifest.dart`

**Additional files with metadata['genetId'] reads:**
- `lib/screens/graph/organism_node_screen.dart`
- `lib/widgets/dialogs/transfer/transfer_initiate_dialog.dart`
- `lib/widgets/spreadsheet/components/organism_quick_action_sheet.dart`

**Tasks**:
- [ ] Replace all `foreignKeys['genet']` reads with `foreignKeys['genetId']`
- [ ] Use `GenetIdResolver.resolve()` where a consolidated resolution is needed
- [ ] Remove `metadata['genetId']` fallback reads (use top-level field)
- [ ] Fix reversed priority in `outplanting_service.dart:129` (check `genetId` before `genet`)
- [ ] Reduce `loadOrganismDocsForGenet` in `transfer_service_validation.dart` from 6 queries to 1-2

#### 2A.3 Standardize localId Location

**Files (all consumers of metadata['localId'])**:
- `lib/models/inventory/organism_record.dart`
- `lib/models/inventory/holding_record.dart`
- `lib/services/export/inventory_snapshot_row_builder.dart`
- `lib/screens/graph/organism_node_screen.dart`
- `lib/services/inventory/inventory_snapshot_service.dart`
- `lib/services/unique_name_validation_service.dart`
- `lib/models/taxonomy/provenance_record.dart`
- `lib/services/transfer_service_manifest.dart`
- `lib/services/transfer_service.dart`
- `lib/repositories/inventory/organism_record_repository_queries.dart`

**Tasks**:
- [ ] Remove all `metadata['localId']` and `metadata['local_id']` fallback reads
- [ ] Top-level `localId` is canonical; no fallbacks
- [ ] Update all sites to use top-level field

#### 2A.4 Standardize siteId/groupId Derivation

**Files**:
- `lib/models/inventory/holding_record.dart`
- `lib/services/export/inventory_holding_row_builder.dart`

**Tasks**:
- [ ] Remove fallback chains in export: use `holding.siteId` directly
- [ ] Add validation at holding creation: derive from organismRecord if not provided

---

### Team Beta: Provenance ID Clarification

**DEPENDS ON Team Alpha completing 2A.1 and 2A.2.**

**Goal**: Clear distinction between lineage IDs (provenance) and document IDs.

#### 2B.1 Fix getByProvenance Query

**Files**:
- `lib/repositories/inventory/organism_record_repository_queries.dart`

**Tasks**:
- [ ] Rename method to `getByGenetProvenanceId()` for clarity
- [ ] Remove lines 338-339 that compare provenance ID to `record.genetId` (doc ID) and `foreignKeyGenetId` (doc ID)
- [ ] Keep only: `foreignKeyProvenanceId == provenanceId` and `legacyMetadataProvenanceId == provenanceId`
- [ ] Add format validation: reject if input doesn't match provenance format

#### 2B.2 Add ID Type Validation Utilities

**Files**:
- `lib/utils/id_type_validator.dart` (new)

**Tasks**:
- [ ] `static bool isProvenanceId(String value)` — matches `^(PID|SF)-[A-Z0-9]{2,4}-[A-Z0-9]{4,}$`
- [ ] `static bool isFirestoreDocId(String value)` — does NOT match provenance format
- [ ] `static IdType classify(String value)` — returns enum `{provenanceId, docId, unknown}`
- [ ] Add unit tests

#### 2B.3 Update Transfer Service Validation

**Files**:
- `lib/services/transfer_service_validation.dart`

**Tasks**:
- [ ] Migrate `resolveOrganismGenetId()` (line 947) and `matchesGenetId()` (line 972) to use `GenetIdResolver`
- [ ] Reduce `loadOrganismDocsForGenet()` from 6 Firestore queries to single query on `genetId`
- [ ] Ensure queries use correct ID type for each field
- [ ] Add validation that rejects provenance IDs in doc ID fields

#### 2B.4 Remove metadata['provenanceId'] from FK metadata reads

**Files (all consumers of stale FK metadata)**:
- `lib/services/export/inventory_export_row_source.dart`
- `lib/services/export/inventory_organism_row_builder.dart`
- `lib/services/export/inventory_snapshot_row_builder.dart`
- `lib/models/inventory/inventory_export_row.dart`
- `lib/services/inventory/inventory_snapshot_service.dart`
- `lib/services/transfer_service_manifest.dart`
- `lib/screens/graph/organism_node_screen.dart`
- `lib/repositories/inventory/organism_record_repository_queries.dart`
- `lib/services/transfer_service.dart`

**Tasks**:
- [ ] Load actual `Genet` records for provenance data
- [ ] Remove reliance on `genetRef?.metadata['provenanceId']` (stale FK metadata)
- [ ] Use `genet.provenanceId` directly from loaded record
- [ ] Add batch loading for genet records to avoid N+1 queries

---

### Team Gamma: Dialog Consolidation

**Goal**: Single creation/update path for each data type. Can run parallel to all other teams.

#### 2C.1 Document Dialog Usage

**Files**:
- `docs/modules/inventory/CLAUDE.md`

**Tasks**:
- [ ] Document `OrganismCreationWizard.showAndCreate` as canonical organism creation entry point
- [ ] Document provenance service architecture (CrosswalkService vs LookupService)

#### 2C.2 Align Creation Path Outputs

**Files**:
- `lib/cubits/organism_creation/organism_creation_cubit.dart`

**Tasks**:
- [ ] Ensure wizard field handling sets genetId in top-level, not metadata
- [ ] Add integration test verifying creation path output

---

### Team Delta: CSV/Export Alignment

**Goal**: Consistent column names and ID type handling. Can run parallel to Alpha.

#### 2D.1 Standardize Column Names

**Files**:
- `lib/constants/csv_schema.dart`

**Tasks**:
- [ ] Define canonical column names:
  - `organism_id` → Firestore doc ID
  - `genet_id` → Firestore doc ID
  - `provenance_id` → Lineage ID (Genet.provenanceId)
  - `genet_provenance_id` → Lineage ID (explicit)
  - `holding_id` → Firestore doc ID
- [ ] Remove ambiguous aliases
- [ ] Document expected ID type for each column

#### 2D.2 Add Import Validation

**Files**:
- `lib/services/csv/import/importers/inventory/organism/organism_field_validator.dart`
- `lib/services/csv/import/importers/inventory/inventory_row_parser.dart`

**Tasks**:
- [ ] Reject provenance ID format in `organism_id` column
- [ ] Reject doc ID format in `provenance_id` column
- [ ] Add clear error messages explaining expected format

#### 2D.3 Update Universal CSV Adapter

**Files**:
- `lib/services/csv/adapters/universal_csv_adapter_v2_mapper.dart`
- `lib/services/csv/adapters/universal_csv_adapter_v2.dart`

**Tasks**:
- [ ] Remove fallback that promotes `provenanceId` to `genet_provenanceId`
- [ ] Require explicit `genet_provenance_id` column for genet lineage
- [ ] Add validation for ID type in each column

#### 2D.4 Update Genetics CSV Importer

**Files**:
- `lib/services/csv/import/importers/genetics_csv_importer.dart`

**Tasks**:
- [ ] Remove logic that treats `genet_id` as provenance ID fallback
- [ ] `genet_id` is always a doc ID; `provenance_id` is always a lineage ID

---

### Team Foxtrot: Physical Form & Legacy Field Cleanup

**Goal**: Remove all legacy morphologyId/sizeClass metadata fields; physicalFormId is canonical. `SizeSpec.sizeClass` is a canonical field and is NOT removed.

**SCOPE CLARIFICATION**: The word "morphology" appears in 69 files with 269 occurrences. This includes:
- **Metadata fields** (`metadata['morphologyId']`, `metadata['morphology']`) — REMOVE
- **Method names** (`_suggestMorphologyForOrganism`) — RENAME to physical form equivalent
- **State/cubit fields** (`morphologyEdited`, `selectedMorphology`, `morphologyReason`) — RENAME
- **UI strings** ("Ensure the morphology and size match") — RENAME to "physical form"
- **Config files** — removed in community fork, verify no remaining references

#### 2F.1 Remove morphologyId from Metadata (Services Layer)

**Files**:
- `lib/services/transfer_service.dart` — lines 547-548 writes `metadata['morphologyId']`, MUST remove
- `lib/services/transfer_service_validation.dart`
- `lib/services/transfer_service_manifest.dart` — reads `metadata['morphologyId']`
- `lib/services/transfer_service_initiation.dart` — `morphologyOverride` param
- `lib/services/transfer_service_acceptance.dart` — `morphologyFromMetadata()`, `morphologyOverride`
- `lib/services/manual_transfer_registration_service.dart` — morphology param
- `lib/services/inventory_event_formatter.dart`
- `lib/services/structure_capacity_service.dart`
- `lib/services/taxonomy_admin_service.dart`
- `lib/services/size_mappings_service.dart`
- `lib/services/csv/adapters/universal_csv_adapter_v2_validator.dart`

**Tasks**:
- [ ] Replace all `metadata['morphologyId']` reads/writes with `physicalFormId`
- [ ] Rename `morphologyOverride` params to `physicalFormOverride` across transfer services
- [ ] Rename `morphologyFromMetadata()` to `physicalFormFromMetadata()`
- [ ] Remove any fallback chains checking both morphology and physicalForm

#### 2F.2 Remove morphologyId from Models

**Files**:
- `lib/models/inventory/organism_record.dart`
- `lib/models/inventory/organism_extensions.dart`
- `lib/models/events/collection_event.dart`
- `lib/models/types/types.dart`
- `lib/models/types/inventory_event_type.dart`
- `lib/models/taxonomy/organism_classification.dart`
- `lib/models/mixins/life_stage_progression_mixin.dart`

**Tasks**:
- [ ] Replace all `morphologyId` metadata reads with `physicalFormId`
- [ ] Replace all `morphology` metadata reads with `physicalForm`
- [ ] Update `InventoryEventType` morphology references

#### 2F.3 Rename morphology in Cubits/BLoCs

**Files**:
- `lib/cubits/organism_creation/organism_creation_cubit.dart` — `morphologyChanged` method
- `lib/cubits/organism_creation/organism_creation_state.dart` — `morphology` field (7 refs)
- `lib/cubits/transfer/transfer_initiate_cubit.dart` — `morphologyOverride` (4 refs)
- `lib/blocs/organism_record_edit/organism_record_edit_state.dart` — `morphologyReason` (15 refs)
- `lib/blocs/organism_record_edit/organism_record_edit_cubit.dart` — `morphologyReason` writes (6 refs)

**Tasks**:
- [ ] Rename `morphology*` fields/methods to `physicalForm*` equivalents
- [ ] Rename `morphologyReason` to `physicalFormChangeReason`
- [ ] Update all state class `props` lists

#### 2F.4 Rename morphology in Widgets/Dialogs

**Files**:
- `lib/widgets/dialogs/transfer/transfer_initiate_dialog.dart` (5 refs)
- `lib/widgets/dialogs/transfer/transfer_manual_register_dialog.dart` (5 refs)
- `lib/widgets/dialogs/holdings/generic_holding_dialog.dart` (4 refs)
- `lib/widgets/dialogs/holdings/holding_dialog_configs.dart`
- `lib/widgets/dialogs/components/csv_import_results_panel.dart` (3 refs)
- `lib/widgets/dialogs/components/csv_import_preview.dart` (2 refs)
- `lib/widgets/spreadsheet/genetics/genetics_events_table.dart` (14 refs)
- `lib/widgets/common/five_axis_editor.dart` (14 refs)
- `lib/widgets/onboarding/five_axis_education_widget.dart`
- `lib/widgets/graph_node/actions/organism_inventory_action_registry.dart` (2 refs)
- `lib/widgets/spreadsheet/genetics_spreadsheet_helper.dart` — also has 3 `coral_type` refs

**Tasks**:
- [ ] Rename all `morphology` variable names to `physicalForm`
- [ ] Update UI strings from "morphology" to "physical form"
- [ ] Remove `coral_type` references in `genetics_spreadsheet_helper.dart`
- [ ] Update holding config description strings

#### 2F.5 Remove sizeClass/measured_value/measured_unit from Metadata

**SCOPE**: Only remove `metadata['sizeClass']`, `metadata['size']`, `metadata['measured_value']`, `metadata['measured_unit']` legacy reads. Do NOT remove `SizeSpec.sizeClass` (canonical field) or `SizeSpec.sizeBandId`.

**Note**: The monitoring cubits, spreadsheets, and growth services that previously contained these references have been removed in the community fork. Verify no remaining files reference these legacy metadata keys.

**Tasks**:
- [ ] Remove `metadata['sizeClass']`/`metadata['size']` legacy reads
- [ ] Remove `measured_value`/`measured_unit` metadata reads
- [ ] Use `SizeSpec` consistently for all size data
- [ ] Keep `SizeSpec.sizeClass` — this is canonical, not legacy

#### 2F.6 Update Config Files

**Note**: `config/tier_fields.yaml`, `config/structure_capacity.defaults.yaml`, `config/life_stage_constraints.yaml`, and `config/seed_data/training/` files have all been removed in the community fork. No config file updates are needed.

**Tasks**:
- [ ] Verify no remaining config files reference legacy field names (morphologyId, sizeClass, coral_type)

#### 2F.7 Update CSV Templates & Fixtures (CORRECTED PATHS)

**Note**: Only coral templates remain in the community fork.

**Fixtures** (at `docs/csv/fixtures/`, NOT `test/fixtures/csv/`):
- `docs/csv/fixtures/universal_inventory_identity_conflict.csv`
- `docs/csv/fixtures/v2/*.csv`

**Tasks**:
- [ ] Remove any `morphology`, `size_class`, `coral_type` columns from coral templates
- [ ] Convert identity conflict fixture to v2 format
- [ ] Verify v2 fixtures use canonical field names

#### 2F.8 Update Documentation

**Note**: `docs/api/multi_organism_api.md`, `docs/user_guides/multi_organism_guide.md`, `docs/migrations/MOTE_MIGRATION_ARCHITECTURE.md`, `docs/migrations/MOTE_MIGRATION_FLOW.md`, `docs/reference/seafoundry_18_month_roadmaps.md`, and `docs/modules/genetics/CLAUDE.md` have been removed in the community fork.

**Files**:
- `schemas/SeaFoundry_Universal_CSV_v2_spec.json`
- `docs/csv/csv_v2_migration.md` — remove v1 references
- `docs/csv/examples/notes.md` (NOT `docs/csv/notes.md`)
- `docs/architecture/MANAGEMENT_DIALOG_ARCHITECTURE.md` — `morphology`
- `docs/architecture/taxonomy/README.md` — `coral_type`, `csv_v1`
- `docs/api/README.md` — `csv_v1`

**Tasks**:
- [ ] Remove all v1 references
- [ ] Document `physicalFormId` as the only physical form identifier
- [ ] Update all doc paths that reference removed/renamed fields

#### 2F.9 Update Tests (COMPREHENSIVE LIST)

**Test files needing morphology/sizeClass/coral_type updates (22+ files)**:
- `test/unit/services/structure_capacity_service_test.dart`
- `test/unit/services/export/inventory_export_row_formatter_test.dart`
- `test/unit/services/csv/inventory_csv_importer_test.dart`
- `test/widget/spreadsheet/monitoring_spreadsheet_test.dart`
- `test/helpers/recording_transfer_service.dart`
- `test/unit/services/transfer_service_test.dart`
- `test/unit/services/validation_rule_registry_test.dart`
- `test/unit/services/organism_record_change_service_test.dart`
- `test/unit/repositories/organism_record_update_test.dart`
- `test/unit/models/events/size_change_event_test.dart`
- `test/unit/models/inventory/size_interpretation_test.dart`
- `test/unit/services/organism_validation_service_test.dart`
- `test/unit/models/inventory/organism_record_serialization_test.dart`
- `test/unit/models/inventory/inventory_export_row_test.dart`
- `test/blocs/inventory_event/inventory_event_creation_bloc_test.dart`
- `test/helpers/test_data_factory.dart`
- `test/unit/cubits/inventory_holding_row_builder_test.dart`
- `test/widget/dialogs/transfer_dialog_manual_register_test.dart`
- `test/unit/cubits/organism_creation/organism_creation_cubit_test.dart`
**Test files needing coral_type updates:**
- `test/unit/services/csv/universal_csv_adapter_v2_test.dart`

**Test files needing universal_csv_v1 removal:**
- `test/unit/services/csv/csv_translation_pipeline_test.dart`
- `test/widget/dialogs/components/csv_translation_issues_panel_test.dart`

**Tasks**:
- [ ] Update all test files with morphology → physicalForm renames
- [ ] Remove `coral_type` references in test data
- [ ] Remove `universal_csv_v1` references in test assertions
- [ ] Run full test suite

#### 2F.10 Final Sweep

**Tasks**:
- [ ] `rg 'morphologyId' lib/` = zero hits
- [ ] `rg 'morphology' lib/` = only canonical PhysicalFormChangeReason (was morphologyReason) and possibly a few legitimate uses
- [ ] `rg 'coral_type' lib/` = zero hits
- [ ] `rg 'csv_v1|universal_csv_v1' .` = zero hits (excluding archived scripts)
- [ ] `rg 'measured_value|measured_unit' lib/` = zero hits
- [ ] Document any intentional exceptions

### Phase 2 Review Gate

**Review Committee reviews ALL Phase 2 team outputs before proceeding to Phase 3.**

---

### Team Echo: Firebase & Infrastructure

**STARTS AFTER Team Alpha + Beta complete** (needs final field structure for seed data).

#### 2E.1 Review Firestore Rules

**Files**:
- `firestore.rules`

**Tasks**:
- [ ] Audit rules for hardcoded field names that changed
- [ ] Verify rules handle `genetId` at top level
- [ ] Remove any rules referencing `lineageId` (removed in Phase 1.4)
- [ ] Verify organism creation rules match new field structure

#### 2E.2 Review Firestore Indexes

**Files**:
- `firestore.indexes.json`

**Tasks**:
- [ ] Audit `genetId` indexes (lines 178, 200, 912) — keep valid top-level indexes
- [ ] Remove indexes on `foreignKeys.genetId` if redundant after unification
- [ ] Remove indexes on `metadata.genetId`, `metadata.provenanceId`
- [ ] Remove indexes on `morphologyId`, `sizeClass`, `coral_type` if present
- [ ] Verify composite indexes match new query patterns

#### 2E.3 Review Storage Rules

**Files**:
- `storage.rules`

**Tasks**:
- [ ] Verify storage paths don't reference deprecated fields

#### 2E.4 Update Seed Scripts

**Note**: `scripts/seed-non-coral-holdings.js` and `scripts/import-mote-phase2.js` have been removed in the community fork.

**Files**:
- `scripts/seed-demo.js`
- `scripts/seed-emulator.js`
- `scripts/seed-coral-inventory.js`
- `scripts/reset_and_seed_inventory.dart` — **MISSING FROM ORIGINAL PLAN**: writes `sizeClass` at line 2091

**Tasks**:
- [ ] Update organism creation to set `genetId` at top level
- [ ] Sync `foreignKeys['genetId']` with top-level `genetId`
- [ ] Remove `foreignKeys['genet']` writes
- [ ] Remove any `metadata['genetId']` or `metadata['provenanceId']` writes
- [ ] Remove `sizeClass` writes, use `SizeSpec` format
- [ ] Remove `morphologyId` writes, use `physicalFormId`
- [ ] Use `provenance_id` for lineage, `genet_id` for doc IDs
- [ ] Verify seeded data passes new validation rules

#### 2E.5 Update Import & Utility Scripts

**Note**: `scripts/import-mote-hog.js` has been removed in the community fork.

**Files**:
- `scripts/constants.js`
- `scripts/generate-pid-crosswalk.js`
- `scripts/build-species-crosswalk.js`
- `scripts/export_pid_aliases.js`
- `scripts/normalize-provenanceid.js`
- `scripts/verify-demo-setup.js`
- `scripts/reset-production-data.js`
- `scripts/firestore/seed_taxonomy_data.ts`

**Tasks**:
- [ ] Update to use canonical column names
- [ ] Ensure organisms have consistent field structure
- [ ] Remove legacy field handling
- [ ] Mark `scripts/archive/` contents as intentionally excluded from cleanup

---

## Phase 3: Integration & Validation

After all Phase 2 tracks complete AND Phase 2 review gate passes. Serial execution.

### 3.1 Cross-Team Integration Testing

**Tasks**:
- [ ] Run full CSV import/export roundtrip tests
- [ ] Verify all organism creation paths produce identical `OrganismRecord` structures
- [ ] Test genet lookup by both doc ID and provenance ID (separate methods)
- [ ] Test `OutplantAllocation.organismId` is always a Firestore doc ID in both paths
- [ ] Run `flutter analyze` — zero errors
- [ ] Run `flutter test` — all tests pass

### 3.2 Firebase Emulator Validation

**Tasks**:
- [ ] Start emulator: `./dev-emulator.sh`
- [ ] Run seed scripts against emulator
- [ ] Verify seeded data structure in Firestore emulator UI
- [ ] Test all CRUD operations via app
- [ ] Test CSV import/export flows

### 3.3 Update Documentation

**Files**:
- `CLAUDE.md` (root) — remove stale `LegacyCoralTypeMapper` reference, update `foreignKeys` docs
- `README.md` — update physical form chain docs
- `docs/modules/inventory/CLAUDE.md`

**Tasks**:
- [ ] Document canonical field locations for all ID types
- [ ] Document ID type distinctions (provenance vs doc ID)
- [ ] Update "Critical Patterns" section in `CLAUDE.md`
- [ ] Remove references to legacy fallback patterns
- [ ] Remove `LegacyCoralTypeMapper` reference from `CLAUDE.md`

### 3.4 Final Legacy Cleanup

**Tasks**:
- [ ] Verify `metadata['coralTypeId']` fallbacks all removed
- [ ] Verify `metadata['morphologyId']` fallbacks all removed
- [ ] Verify `metadata['genetId']` fallbacks all removed
- [ ] Verify `metadata['provenanceId']` fallbacks all removed
- [ ] Verify `foreignKeys['genet']` fully consolidated to `foreignKeys['genetId']`
- [ ] Final verification: no legacy field references remain

### Phase 3 Review Gate

**Review Committee performs FINAL comprehensive review of ALL implementation.**

---

## File Reference Index

### Models
- `lib/models/inventory/organism_record.dart`
- `lib/models/inventory/organism_extensions.dart`
- `lib/models/inventory/holding_record.dart`
- `lib/models/cohort.dart`
- `lib/models/genet.dart`
- `lib/models/events/collection_event.dart`
- `lib/models/types/types.dart`
- `lib/models/types/inventory_event_type.dart`
- `lib/models/taxonomy/organism_classification.dart`
- `lib/models/taxonomy/provenance_record.dart`
- `lib/models/mixins/life_stage_progression_mixin.dart`

### Repositories
- `lib/repositories/inventory/organism_record_repository_mutations.dart`
- `lib/repositories/inventory/organism_record_repository_queries.dart`
- `lib/repositories/inventory/organism_record_repository_status.dart`

### Services
- `lib/services/transfer_service.dart`
- `lib/services/transfer_service_validation.dart`
- `lib/services/transfer_service_manifest.dart`
- `lib/services/transfer_service_initiation.dart`
- `lib/services/transfer_service_acceptance.dart`
- `lib/services/manual_transfer_registration_service.dart`
- `lib/services/inventory_event_formatter.dart`
- `lib/services/structure_capacity_service.dart`
- `lib/services/taxonomy_admin_service.dart`
- `lib/services/size_mappings_service.dart`
- `lib/services/outplanting_service.dart`
- `lib/services/outplanting_analytics_service.dart`
- `lib/services/state_reconstruction_service.dart`
- `lib/services/event_history_service.dart`
- `lib/services/survival_calculation_service.dart`
- `lib/services/metadata_extraction_service.dart`
- `lib/services/unique_name_validation_service.dart`
- `lib/services/genet_id_resolver.dart` (new)

### Inventory Hydration
- `lib/services/inventory_hydration/inventory_event_hydration_service.dart`
- `lib/services/inventory_hydration/inventory_event_hydrator.dart`
- `lib/services/inventory_hydration/general_event_hydrator.dart`
- `lib/services/inventory_hydration/hydration_result.dart`

### CSV/Import/Export
- `lib/services/csv/import/importers/outplant_allocations_csv_importer.dart`
- `lib/services/csv/import/importers/inventory/organism/organism_field_validator.dart`
- `lib/services/csv/import/importers/inventory/organism/organism_metadata_updater.dart`
- `lib/services/csv/import/importers/genetics_csv_importer.dart`
- `lib/services/csv/adapters/universal_csv_adapter_v2_mapper.dart`
- `lib/services/csv/adapters/universal_csv_adapter_v2.dart`
- `lib/services/csv/adapters/universal_csv_adapter_v2_validator.dart`
- `lib/services/export/inventory_export_row_source.dart`
- `lib/services/export/inventory_organism_row_builder.dart`
- `lib/services/export/inventory_snapshot_row_builder.dart`
- `lib/services/inventory/inventory_snapshot_service.dart`
- `lib/constants/csv_schema.dart`

### Cubits/BLoCs
- `lib/cubits/organism_creation/organism_creation_cubit.dart`
- `lib/cubits/organism_creation/organism_creation_state.dart`
- `lib/cubits/transfer/transfer_initiate_cubit.dart`
- `lib/blocs/organism_record_edit/organism_record_edit_state.dart`
- `lib/blocs/organism_record_edit/organism_record_edit_cubit.dart`

### Dialogs & Widgets
- `lib/widgets/dialogs/organism_creation_wizard/organism_creation_wizard.dart`
- `lib/widgets/dialogs/transfer/transfer_initiate_dialog.dart`
- `lib/widgets/dialogs/transfer/transfer_manual_register_dialog.dart`
- `lib/widgets/dialogs/holdings/generic_holding_dialog.dart`
- `lib/widgets/dialogs/holdings/holding_dialog_configs.dart`
- `lib/widgets/dialogs/components/csv_import_results_panel.dart`
- `lib/widgets/dialogs/components/csv_import_preview.dart`
- `lib/widgets/spreadsheet/genetics/genetics_events_table.dart`
- `lib/widgets/spreadsheet/genetics_spreadsheet_helper.dart`
- `lib/widgets/common/five_axis_editor.dart`
- `lib/widgets/onboarding/five_axis_education_widget.dart`
- `lib/widgets/graph_node/actions/organism_inventory_action_registry.dart`
- `lib/screens/graph/organism_node_screen.dart`
- `lib/widgets/spreadsheet/components/organism_quick_action_sheet.dart`

### Firebase
- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`

### Scripts
- `scripts/seed-demo.js`
- `scripts/seed-emulator.js`
- `scripts/seed-coral-inventory.js`
- `scripts/reset_and_seed_inventory.dart`
- `scripts/constants.js`
- `scripts/generate-pid-crosswalk.js`
- `scripts/build-species-crosswalk.js`
- `scripts/export_pid_aliases.js`
- `scripts/normalize-provenanceid.js`
- `scripts/verify-demo-setup.js`
- `scripts/reset-production-data.js`
- `scripts/firestore/seed_taxonomy_data.ts`

### Templates & Fixtures (CORRECTED PATHS)
- `docs/csv/examples/notes.md`
- `docs/csv/fixtures/universal_inventory_identity_conflict.csv`
- `docs/csv/fixtures/v2/*.csv`

### Documentation (CORRECTED PATHS)
- `schemas/SeaFoundry_Universal_CSV_v2_spec.json`
- `docs/csv/csv_v2_migration.md`
- `docs/architecture/MANAGEMENT_DIALOG_ARCHITECTURE.md`
- `docs/architecture/taxonomy/README.md`
- `docs/api/README.md`
- `CLAUDE.md` (root)

### Assets to Delete
- `assets/csv/universal_inventory_v1_template.csv`

### Intentional Exclusions
- `scripts/archive/deprecated/*` — archived, not maintained
- `scripts/archive/migrations/*` — archived migration scripts

---

## Success Criteria

### ID Field Unification
- [ ] `organism.genetId` returns consistent value regardless of access method
- [ ] No extension shadowing of `genetId`
- [ ] `foreignKeys['genet']` fully consolidated to `foreignKeys['genetId']`
- [ ] `getByGenetProvenanceId()` only compares provenance IDs, never doc IDs
- [ ] All organism creation paths produce identical `OrganismRecord` structures
- [ ] CSV import rejects provenance IDs in doc ID columns with clear error messages
- [ ] Export provenance values come from actual genet records, not stale FK metadata
- [ ] `OutplantAllocation.organismId` is always a Firestore doc ID

### Dialog Consolidation
- [x] ~~Health status updates vs observations are clearly distinguished in code and UI~~ (health/observation dialogs removed in community fork)

### Physical Form Cleanup
- [ ] `rg 'morphologyId' lib/` = zero hits
- [ ] `rg 'coral_type' lib/` = zero hits
- [ ] `rg 'csv_v1|universal_csv_v1' .` = zero hits (excluding `scripts/archive/`)
- [ ] `rg 'measured_value|measured_unit' lib/` = zero hits
- [ ] `metadata['sizeClass']` and `metadata['size']` reads removed (but `SizeSpec.sizeClass` retained)
- [ ] All CSV templates use v2 format with `physical_form_id`

### Validation
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes with zero failures
- [ ] Firebase emulator seed + app test cycle completes successfully

---

## Implementation Order Summary

```
Phase 0: Verification + v1 artifact cleanup
    |
    v [Review Gate]
    |
Phase 1: Critical fixes (serial)
  1.1 Fix genetId extension shadowing
  1.2 Create GenetIdResolver service
  1.3 Fix OutplantAllocation ID mismatch
  1.4 Remove lineageId
    |
    v [Review Gate]
    |
Phase 2: Parallel team tracks
  ┌─── Alpha (ID Fields: 2A.1-2A.4) ──────────┐
  │                                              │
  │    Alpha completes ──► Beta (Provenance: 2B.1-2B.4)
  │                                              │
  ├─── Gamma (Dialogs: 2C.1-2C.2) ─────────────┤
  ├─── Delta (CSV: 2D.1-2D.4) ─────────────────┤
  ├─── Foxtrot (Physical Form: 2F.1-2F.10) ────┤
  │                                              │
  │    Alpha+Beta complete ──► Echo (Firebase: 2E.1-2E.5)
  └──────────────────────────────────────────────┘
    |
    v [Review Gate]
    |
Phase 3: Integration & validation (serial)
  3.1 Cross-team integration testing
  3.2 Firebase emulator validation
  3.3 Documentation update
  3.4 Final legacy cleanup
    |
    v [FINAL Review Gate - Comprehensive]
```

---

## Review Committee Findings (incorporated above)

### System Architect Review
- **C1**: Alpha/Beta dependency identified — resolved by extracting GenetIdResolver to Phase 1.2
- **C2**: `foreignKeys['genet']` in 18 files — added as Task 2A.2
- **C3**: `sizeClass` scope clarification — added to Decisions section
- **M1-M8**: Missing files, metadata patterns, test gaps — all added to team scopes

### Deep Logic Architect Review
- **C1**: genetId extension shadowing confirmed — Phase 1.1
- **C2**: OutplantAllocation dual-semantics — expanded Phase 1.3
- **C3**: getByProvenance mixing ID types — Phase 2B.1
- **M1-M4**: TransferService resolvers, loadOrganismDocsForGenet — added to team scopes (GeneBankMetrics removed in community fork)
- **L1**: lineageId removal moved to Phase 1.4 since DB wiped
- **L2**: transfer_service.dart writes morphologyId — added to 2F.1
- **L3**: Reversed FK priority in outplanting_service.dart — added to 2A.2

### QAQC Specialist Review
- **C1**: Morphology scope 8→69 files — fully expanded in 2F.1-2F.4
- **C2**: Template/fixture paths wrong — corrected throughout
- **C3**: v1 template still exists — added to Phase 0.4
- **C4**: Orphaned test references deleted dialog — added to Phase 0.4
- **M1-M7**: Test files, scripts, docs gaps — all added to scopes
- **L1-L6**: Config files, training SOPs, archived scripts — added

---

## Related Issues

- [RecordName + LocalId Normalization](./recordname-localid-normalization.md)
- [Dialog Provider Pattern](./dialog-provider-pattern-january-2026.md)
