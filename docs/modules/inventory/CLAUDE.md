# Inventory Module (Claude Notes)

## Guardrails
- Use `OrganismRecordRepository` or `InventoryRecordRepository` for writes.
- Normalize `localGenetId` and `tagId` via `UniqueNameValidationService` and
  `RecordNameDerived` before persistence.
- Inventory events must include `snapshotData` and use
  `recordModelType: organismRecord`.
- Use `SpreadsheetBase` rather than custom tables.
- Organism creation wizard (`lib/widgets/dialogs/organism_creation_wizard/`) supports provenance autocomplete in NEW genet mode. Uses `ProvenanceSearchMixin` and `PidStatusChip` for PID conflict detection. The wizard returns an `OrganismCreationResult` (type-safe wrapper with `.record` and `.inheritedProvenanceId` fields) — the caller passes `.inheritedProvenanceId` to `GenetRepository.createGenet(inheritedProvenanceId:)`.

## Dialog & Creation Entry Points

### Organism Creation
- **`OrganismCreationWizard.showAndCreate`** is the canonical entry point for
  creating a new organism record. It drives the full multi-step wizard
  (classification, identity, provenance, biometrics, measurements, review) and
  returns an `OrganismCreationResult?` (type-safe wrapper). Callers use
  `.record` for the created organism and `.inheritedProvenanceId` when a
  crosswalk match was selected, passing it to
  `GenetRepository.createGenet(inheritedProvenanceId:)`.

### GenetIdResolver
- All genet ID resolution in inventory code must use
  `GenetIdResolver.resolve(record)` — never access
  `record.foreignKeys['genetRecordId']?.id` directly. This applies to event
  hydration, spreadsheet data, volume calculations, and search integrations.

### Health-Related Observations
- **`UnifiedObservationDialog` with `ObservationDialogType.healthIssue`**:
  Logs a health-related observation WITHOUT changing the organism's health
  status. Use this to record an issue (pest, disease, discoloration, etc.)
  that does not directly alter the organism's status.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Verify coral inventory creation flows (inventory tiles/actions).

## Touchpoints
- Screen: `lib/screens/spreadsheet/module_spreadsheet_screen.dart`
- Holdings view: `lib/widgets/spreadsheet/inventory/inventory_holdings_view.dart`
- Events table: `lib/widgets/spreadsheet/inventory/inventory_events_table.dart`
- Services: `lib/services/inventory/`, `lib/services/export/`

## When Updating
- Keep CSV schema changes aligned with `docs/csv/*` and
  `SeaFoundry_Universal_CSV_v2_spec.json`.

## Ownership & Custody System

### Transfer Ownership Types
Use `TransferOwnershipType` enum (`lib/models/types/transfer_ownership_type.dart`):
- `fullTransfer` - Receiver becomes owner + manager (default)
- `retainedOwnership` - Sender retains ownership, receiver manages
- `thirdPartyTransfer` - Auto-detected when `organism.ownerOrganizationId != currentOrgId`

### Custody Detection
```dart
// In OrganismRecordEditState
bool get isCustodian {
  // True when: owner is set, owner != current org, we are the manager
  return ownerOrgId != null && ownerOrgId != currentOrgId &&
         (managerOrgId == null || managerOrgId == currentOrgId);
}
```

### Key Files
- `lib/models/types/transfer_ownership_type.dart` - Enum
- `lib/cubits/organism_record_edit/organism_record_edit_state.dart` - `isCustodian` getter

### Identity Change Events
Events emitted in `OrganismRecordEditCubit._emitIdentityChangeEvents()`:
- `EventType.recordNameChange` - When `tagId` modified
  (Firestore-persisted id: `event_tag_id_change`)
- `EventType.localIdChange` - When `localGenetId` changed (record-level)
  (Firestore-persisted id: `event_local_genet_id_change`)
- `EventType.genetIdentityChange` - When `localGenetId` changed genet-wide
  (Firestore-persisted id: `event_local_genet_identity_change`)
- `EventType.ownershipChange` - When owner/manager changed (source: 'manualEdit' or 'transfer')

### Custody Edit Rights
When `isCustodian == true`, these widgets disable identity fields:
- `ThisRecordOnlySection` - tagId field
- `LocalIdField` - genet identifier (writes `localGenetId`)
- `OwnershipFields` - owner/manager selectors
- `AliasEditorList` - alias editing

### External Holding Sites
- Site type: `SiteType.externalHolding` (`site_type_external_holding`)
- Fields on Site: `externalHoldingOrganizationId`, `externalHoldingSiteId`, `externalHoldingGroupPath`
- Displayed in: `ExternalHoldingsSection` widget

### Chain of Custody Tracking
Custody history is stored in `OrganismRecord.metadata['custodyHistory']` as an array of entries:

```dart
// Each entry contains:
{
  'ownerOrganizationId': 'org-a',
  'ownerOrganizationName': 'Coral Restoration Foundation',
  'managingOrganizationId': 'org-b',
  'managingOrganizationName': 'Mote Marine Lab',
  'startedAt': '2024-02-15T10:30:00.000Z',
  'transferId': 'transfer-123', // null for original creation
  'transferType': 'retainedOwnership', // null, fullTransfer, retainedOwnership, thirdPartyTransfer
  'note': 'Transferred for management',
}
```

**Key Files:**
- `lib/models/inventory/custody_history_entry.dart` - CustodyHistoryEntry model
- `lib/services/custody_history_service.dart` - Service for managing custody history
- `lib/models/inventory/organism_extensions.dart` - Extension methods on OrganismRecord

**Extension Methods on OrganismRecord:**
- `record.custodyHistory` - Full custody chain
- `record.currentCustody` - Most recent entry
- `record.allCustodyOrganizations` - All org IDs in chain
- `record.hasEverOwned(orgId)` / `hasEverManaged(orgId)` / `hasEverHadCustody(orgId)`

### Known Limitations (Future Work)
1. Multi-owner transfers only capture first owner (validation needed)
2. Chain of custody notifications don't supersede previous holdings
3. Notification handler creates log entries but full site creation requires additional work
4. Third-party owner name may fall back to sender name if not in metadata

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.

## Identity Model (Critical Distinction)

### Four Identity Components
Each organism record has four distinct identity components that MUST NOT be confused. Names are post-rename for parity with `seafoundry_app` upstream.

1. **`localGenetId`** (Genet Identifier — was `localId` prior to rename)
   - Format: `ACER-001`, `APAL-042`, etc.
   - This is the genet/genetic lineage identifier
   - Maps directly to a Provenance ID (PID)
   - Associated with clonalID, alias, accession number via crosswalk
   - Shared by all organism records that belong to the same genet
   - Example: "ACER-001" identifies a specific genetic lineage

2. **`tagId`** (Friendly Distinguishing Adjective — was `recordName` prior to rename)
   - A user-friendly name to distinguish organism record instances
   - Examples: "Fluffy", "Tank 3 Fragment", "Field Colony"
   - Unique per record instance, not shared across genet
   - Should ALWAYS differ from `localGenetId`
   - Used when "show record identifiers" toggle is enabled

3. **`outplantTagId`** (Per-organism outplant tag — was `tagId` prior to rename)
   - Optional. Distinct from `tagId`.
   - Set when an organism is outplanted with a physical tag.

4. **`genetRecordId`** (Foreign-key reference to a Genet doc — was `genetId` prior to rename)
   - Resolved through `GenetIdResolver.resolve(record)`. Never read
     `record.foreignKeys['genetRecordId']?.id` directly.

5. **Record UUID** (`id`)
   - The underlying database UUID for the organism record
   - Immutable and never changes
   - When "show number" toggle is enabled, displays last 8 characters
   - Example: `a1b2c3d4-e5f6-7890-abcd-ef1234567890` → `34567890`

### Edit Identity Dialog Structure
The OrganismRecordEditDialog organizes identity editing into two sections:
- **Section 1: "This Record Only"** - Record UUID (read-only), tagId editing
- **Section 2: "Genet Identity"** - localGenetId editing with scope (this record vs all genet records), PID preview, vouchers & provenance

### Code References
- State: `OrganismRecordEditState` (in `lib/cubits/organism_record_edit/`) has
  `localIdOverride` and `recordNameOverride` field-name carryovers — these
  internal cubit variables map to `organism.localGenetId` /
  `organism.tagId` respectively. Renaming the cubit-internal vars is a
  follow-up that does not affect persisted shape.
- Cubit: `OrganismRecordEditCubit.setLocalId()`, `setLocalIdWithScope()`, `setRecordName()`
- Widget: `LocalIdField` for genet identifier, `ThisRecordOnlySection` for record-specific fields

## Denormalization

`HoldingRecord` and `Cohort` no longer embed a full `OrganismRecord`. Each
stores `organismRecordId` (FK) plus a small set of denormalized display
fields synced at write time:
- `tagId`, `organismKind`, `lifeStage`, `measurement`,
  `ownerOrganizationId`, `managingOrganizationId` (HoldingRecord)
- Cohort denorms `organismKind`, `lifeStage`, `population`

For deep organism data (aliases, physicalForm details, lifeStageHistory),
callers must use `await holding.resolveOrganismRecord(repo)` (returns
`Future<OrganismRecord?>`).

`OrganismRecordRepository.updateRecord` fans out denorm updates to all
referencing holdings/cohorts via `_fanOutDenormFields` so display fields
stay in sync after a rename / life-stage transition / measurement edit /
ownership transfer.
