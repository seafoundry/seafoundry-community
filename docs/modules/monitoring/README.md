# Monitoring Module

Captures monitoring events, map overlays, and analytics.

## Entry Points
- `lib/screens/monitoring_screen.dart` (drawer: Monitoring)
- Map: `lib/screens/monitoring/monitoring_map_screen.dart`
- Views: `lib/widgets/workspaces/monitoring_events_view.dart`,
  `lib/widgets/workspaces/monitoring_analytics.dart`

## Key UI and State
- Monitoring events spreadsheet:
  `lib/widgets/spreadsheet/monitoring_events_spreadsheet.dart`
- Monitoring entries spreadsheet:
  `lib/widgets/spreadsheet/monitoring_spreadsheet.dart`
- Uses `SebastianPanelWrapper` when AI is enabled.

## Data and Services
- Repositories: `MonitoringRepository`, `MonitoringEventRepository`,
  `EventRepository`
- Models: `MonitoringEvent`, `OutplantGeometry`
- Cubits: `MonitoringEntriesSpreadsheetCubit`

## CSV Import and Export
- UI entry: `UniversalCSVDialog` with `CsvTemplateKind.monitoring`
- Site baseline export uses `CsvTemplateKind.siteBaselines`

## Critical Patterns
- Monitoring events often link to outplant events via `outplantEventId`.
  Use repository helpers to fetch geometry and metadata.
- Follow event field conventions (`snapshotData`, `recordModelType`).
- Use `EventSpreadsheetShell` for event tables and keep filters in cubits.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Monitoring workspace must remain gated (FeatureAccessService + `config/tier_features.yaml`).
- Verify monitoring exports and non-coral monitoring dialog flows.

## Related Docs
- `docs/architecture/event_field_conventions.md`
- `docs/architecture/graph_node_system.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
