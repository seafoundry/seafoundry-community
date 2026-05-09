# Outplanting Module (Claude Notes)

## Guardrails
- Create and update outplant events via `EventRepository`.
- Always populate `siteId`, `allocations`, and `snapshotData`.
- Use `ZoneRepository` and `SubplotRepository` for hierarchy nodes.
- Monitoring events reference `outplantEventId`; keep it stable.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Keep outplant geometry and event linkage consistent for monitoring integrations.

## Touchpoints
- Screen: `lib/screens/spreadsheet/module_spreadsheet_screen.dart`
- Holdings view: `lib/widgets/spreadsheet/outplanting/outplanting_holdings_view.dart`
- Repos: `lib/repositories/inventory/event_repository.dart`,
  `lib/repositories/inventory/zone_repository.dart`,
  `lib/repositories/outplant/subplot_repository.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
