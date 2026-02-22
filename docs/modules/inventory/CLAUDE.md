# Inventory Module (Claude Notes)

## Guardrails
- Use `OrganismRecordRepository` or `InventoryRecordRepository` for writes.
- Normalize `localId` and `recordName` via `UniqueNameValidationService` and
  `RecordNameDerived` before persistence.
- Inventory events must include `snapshotData` and use
  `recordModelType: organismRecord`.
- Use `EventSpreadsheetShell` or `SpreadsheetBase` rather than custom tables.
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
  `record.foreignKeys['genetId']?.id` directly. This applies to event
  hydration, spreadsheet data, volume calculations, and search integrations.

### Health-Related Dialogs
- **`HealthStatusDialog`** (`lib/widgets/dialogs/health_status_dialog.dart`):
  Mutates the organism's canonical `healthStatus` field AND logs an observation.
  Use this when the user explicitly changes an organism's health status (e.g.,
  healthy -> stressed).
- **`UnifiedObservationDialog` with `ObservationDialogType.healthIssue`**:
  Logs a health-related observation WITHOUT changing the organism's health
  status. Use this to record an issue (pest, disease, discoloration, etc.)
  that does not directly alter the organism's status.

### Field Collection
- **`OrganismCollectionDialog`** (`lib/widgets/dialogs/organism_collection_dialog.dart`):
  Records a wild-collection event. Creates both a `Genet` and an
  `OrganismRecord`, then logs a `CollectionEvent` activity. Captures five-axis
  data, GPS, permit metadata, and health status at time of collection.
  `genetId` is passed as a top-level field on `OrganismRecord.create`,
  consistent with the wizard output (aligned in 2C.3).

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Ensure bulk action executors are implemented (`lib/widgets/graph_node/actions/bulk_action_executors.dart`).
- Verify non-coral inventory creation flows (inventory tiles/actions).

## Touchpoints
- Screen: `lib/screens/inventory_screen.dart`
- Spreadsheets: `lib/widgets/spreadsheet/holdings/holdings_spreadsheet.dart`,
  `lib/widgets/spreadsheet/inventory/inventory_events_spreadsheet.dart`
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
- `lib/services/external_holding_service.dart` - Cross-org notifications
- `lib/services/external_holding_notification_handler.dart` - Notification processing
- `lib/blocs/organism_record_edit/organism_record_edit_state.dart` - `isCustodian` getter
- `lib/widgets/common/ownership_indicator.dart` - Custody/External chips
- `lib/widgets/common/custody_info_banner.dart` - Info banners

### Identity Change Events
Events emitted in `OrganismRecordEditCubit._emitIdentityChangeEvents()`:
- `EventType.recordNameChange` - When `recordName` modified
- `EventType.localIdChange` - When `localId` changed (record-level)
- `EventType.genetIdentityChange` - When `localId` changed genet-wide
- `EventType.ownershipChange` - When owner/manager changed (source: 'manualEdit' or 'transfer')

### Custody Edit Rights
When `isCustodian == true`, these widgets disable identity fields:
- `ThisRecordOnlySection` - recordName field
- `LocalIdField` - genet identifier
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

### Three Identity Components
Each organism record has three distinct identity components that MUST NOT be confused:

1. **`localId`** (Genet Identifier)
   - Format: `ACER-001`, `APAL-042`, etc.
   - This is the genet/genetic lineage identifier
   - Maps directly to a Provenance ID (PID)
   - Associated with clonalID, alias, accession number via crosswalk
   - Shared by all organism records that belong to the same genet
   - Example: "ACER-001" identifies a specific genetic lineage

2. **`recordName`** (Friendly Distinguishing Adjective)
   - A user-friendly name to distinguish organism record instances
   - Examples: "Fluffy", "Tank 3 Fragment", "Field Colony"
   - Unique per record instance, not shared across genet
   - Should ALWAYS differ from `localId`
   - Used when "show record identifiers" toggle is enabled

3. **Record UUID** (`id`)
   - The underlying database UUID for the organism record
   - Immutable and never changes
   - When "show number" toggle is enabled, displays last 8 characters
   - Example: `a1b2c3d4-e5f6-7890-abcd-ef1234567890` → `34567890`

### Edit Identity Dialog Structure
The OrganismRecordEditDialog organizes identity editing into two sections:
- **Section 1: "This Record Only"** - Record UUID (read-only), recordName editing
- **Section 2: "Genet Identity"** - localId editing with scope (this record vs all genet records), PID preview, vouchers & provenance

### Code References
- State: `OrganismRecordEditState` has `localIdOverride` and `recordNameOverride`
- Cubit: `OrganismRecordEditCubit.setLocalId()`, `setLocalIdWithScope()`, `setRecordName()`
- Widget: `LocalIdField` for genet identifier, `ThisRecordOnlySection` for record-specific fields
