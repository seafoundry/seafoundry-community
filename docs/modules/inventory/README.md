# Inventory Module

Inventory is the core holdings system for organisms, events, and analytics.

## Entry Points
- Module spreadsheet screen: `lib/screens/spreadsheet/module_spreadsheet_screen.dart`
- Holdings view: `lib/widgets/spreadsheet/inventory/inventory_holdings_view.dart`

## Key UI and State
- Holdings view: `lib/widgets/spreadsheet/inventory/inventory_holdings_view.dart`
  - Toggle between Table (spreadsheet) and Map views
- Inventory events table:
  `lib/widgets/spreadsheet/inventory/inventory_events_table.dart`
- Base spreadsheet helpers: `lib/widgets/spreadsheet/spreadsheet_base.dart`
- Creation wizard: `lib/widgets/dialogs/organism_creation_wizard/`

## Data and Services
- Models: `OrganismRecord`, `InventoryRecord`, `InventoryEvent`
- Repositories: `OrganismRecordRepository`, `InventoryRecordRepository`,
  `EventRepository`, `HoldingRepository` (and per-type inventory repositories)
- Services: `InventoryDataOrchestrator`, `InventorySnapshotService`,
  `InventorySummaryService`, `InventoryEditingService`

## CSV Import and Export
- UI entry: `UniversalCSVDialog` with `CsvTemplateKind.inventory`
- Importer: `lib/services/csv/import/importers/inventory_csv_importer.dart`
- Export service: `lib/services/export/export_service.dart`

## Critical Patterns
- `recordName` and `localId` are normalized. Use
  `UniqueNameValidationService.normalizeLocalId` and
  `RecordNameDerived.fromLocalId` when generating fallbacks.
- All inventory edits must emit events with `snapshotData` and
  `recordModelType: organismRecord` (see event conventions).
- Use `SpreadsheetBase` for
  paginated grids to keep filtering and navigation protection consistent.
- Firestore access belongs in repositories, not widgets.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Verify coral inventory creation flows (inventory tiles/actions).

## Ownership

The community fork tracks ownership only via the inherited `organizationId`
on each record (matching the Firestore path `organizations/{orgId}/...`).
There are no separate owner/manager fields, custody chain, or external
holding sites - transfers are a plain document handoff between orgs.

## Identity Change Events
The system emits events when identity fields are modified:
- `recordNameChange` - Record name modified
- `localIdChange` - Genet identifier changed (single record)
- `genetIdentityChange` - Genet-wide identity update

## Related Docs
- `docs/architecture/taxonomy/README.md`
- `docs/architecture/event_field_conventions.md`
- `docs/csv/csv_v2_migration.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
