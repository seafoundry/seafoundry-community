# Inventory Module

Inventory is the core holdings system for organisms, events, and analytics.

## Entry Points
- `lib/screens/inventory_screen.dart` (drawer: Inventory)
- Views: `lib/widgets/workspaces/inventory_analytics.dart`,
  `lib/widgets/workspaces/inventory_holdings_view.dart`,
  `lib/widgets/workspaces/inventory_events_view.dart`.

## Key UI and State
- Holdings view: `lib/widgets/workspaces/inventory_holdings_view.dart`
  - Toggle between Table (spreadsheet) and Map views
  - Map view uses `SimplifiedOperationsMap` for site visualization
- Holdings spreadsheet: `lib/widgets/spreadsheet/holdings/holdings_spreadsheet.dart`
- Holdings map: `lib/widgets/map/simplified_operations_map.dart`
- Inventory events spreadsheet:
  `lib/widgets/spreadsheet/inventory/inventory_events_spreadsheet.dart`
- Base spreadsheet helpers: `lib/widgets/spreadsheet/spreadsheet_base.dart`,
  `lib/widgets/spreadsheet/event/event_spreadsheet_shell.dart`
- Creation dialogs: `lib/widgets/dialogs/organism_create_dialog.dart`,
  `lib/widgets/dialogs/base/base_inventory_event_dialog.dart`

## Data and Services
- Models: `OrganismRecord`, `InventoryRecord`, `InventoryEvent`
- Repositories: `OrganismRecordRepository`, `InventoryRecordRepository`,
  `EventRepository`, `HoldingRepository` (and per-type inventory repositories)
- Services: `InventoryDataOrchestrator`, `InventorySnapshotService`,
  `InventorySummaryService`, `InventoryEditingService`

## CSV Import and Export
- UI entry: `UniversalCSVDialog` with `CsvTemplateKind.inventory`
- Importer: `lib/services/csv/import/importers/inventory_csv_importer.dart`
- Upgrade path: `lib/services/csv/v2/inventory_csv_upgrade_service.dart`
- Export job: `lib/services/export/inventory_export_job.dart`

## Critical Patterns
- `recordName` and `localId` are normalized. Use
  `UniqueNameValidationService.normalizeLocalId` and
  `RecordNameDerived.fromLocalId` when generating fallbacks.
- All inventory edits must emit events with `snapshotData` and
  `recordModelType: organismRecord` (see event conventions).
- Use `EventSpreadsheetShell` for event tables and `SpreadsheetBase` for
  paginated grids to keep filtering and navigation protection consistent.
- Firestore access belongs in repositories, not widgets.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Ensure bulk action executors are implemented (`lib/widgets/graph_node/actions/bulk_action_executors.dart`).
- Verify non-coral inventory creation flows (inventory tiles/actions).

## Ownership & Custody Model

Organism records support cross-organization ownership and custody tracking.

### Ownership Fields
- `ownerOrganizationId` - Organization that owns the organism
- `managingOrganizationId` - Organization currently managing/caring for the organism

### Transfer Ownership Types
When transferring organisms between organizations, three ownership models are supported:

| Type | Owner | Manager | Use Case |
|------|-------|---------|----------|
| **Full Transfer** | Receiver | Receiver | Complete ownership transfer (default) |
| **Retained Ownership** | Sender | Receiver | Loan/temporary custody; sender keeps ownership |
| **Third-Party** | Original Owner | Receiver | Auto-detected when sender is not the owner |

### Custody Edit Rights
When an organization is a custodian (managing but not owning):
- **Can edit**: Location (site/group), quantity, life stage, physical form
- **Cannot edit**: recordName, localId, ownership, provenance/genetics

### External Holdings Display
Organizations that retain ownership see their externally-held organisms in:
- "Externally Held Organisms" section in inventory
- Mirror sites showing where organisms are located

### Chain of Custody
Each organism record maintains a full custody history in metadata, tracking:
- Every organization that has owned or managed the organism
- When each custody period started
- The transfer that caused each custody change
- Whether it was a full transfer, retained ownership, or third-party transfer

Query methods: `record.custodyHistory`, `record.hasEverOwned(orgId)`, `record.hasEverHadCustody(orgId)`

### UI Indicators
- **Custody chip** (orange): "You manage this organism on behalf of another organization"
- **External chip** (blue): "You own this organism but it is held by another organization"

## Identity Change Events
The system emits events when identity fields are modified:
- `recordNameChange` - Record name modified
- `localIdChange` - Genet identifier changed (single record)
- `genetIdentityChange` - Genet-wide identity update
- `ownershipChange` - Ownership or management changed

## Related Docs
- `docs/architecture/taxonomy/README.md`
- `docs/architecture/event_field_conventions.md`
- `docs/csv/csv_v2_migration.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
