# Outplanting Module

Plan and record outplant events, track holdings by site, and visualize map data.

## Entry Points
- `lib/screens/outplanting_screen.dart` (drawer: Outplanting)
- Views: `lib/widgets/workspaces/outplanting_events_view.dart`,
  `lib/widgets/workspaces/outplanting_holdings_view.dart`,
  `lib/widgets/workspaces/outplanting_analytics.dart`.

## Key UI and State
- Map tab uses `PublicHoldingsMapScreen` in preview mode.
- Site creation uses `StructureDialog` with `StructureType.site`.
- Outplanting events and holdings are spreadsheets in `lib/widgets/spreadsheet/`.

## Data and Services
- Events: `OutplantEvent` in `EventRepository`
- Geometry: `OutplantGeometry` for site shapes
- Repositories: `EventRepository`, `ZoneRepository`, `SubplotRepository`,
  `DeliverableRepository`
- Services: `OutplantingService` for allocation and validation logic

## CSV Import and Export
- UI entry: `UniversalCSVDialog` with `CsvTemplateKind.outplanting`

## Critical Patterns
- Use repository methods to create outplant events so `snapshotData`,
  `allocations`, and geometry are stored consistently.
- Keep `outplantEventId` and geometry in sync for monitoring links.
- Outplant hierarchy is Site -> Zone -> Subplot -> Tag (use the
  zone and subplot repositories).

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Verify non-coral outplant batch workflows and tag persistence (`lib/services/outplanting_service.dart`).
- Keep outplant geometry and event linkage consistent for monitoring integrations.

## Related Docs
- `docs/architecture/event_field_conventions.md`
- `docs/architecture/graph_node_system.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
