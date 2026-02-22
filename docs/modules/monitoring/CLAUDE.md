# Monitoring Module (Claude Notes)

## Guardrails
- Use `MonitoringRepository` or `MonitoringEventRepository` for writes.
- Populate `outplantEventId` and geometry when monitoring outplant sites.
- Keep `MonitoringEntriesSpreadsheetCubit` as the source of truth for filters.
- CSV templates use `UniversalCSVDialog` only.
- Observation dialogs support optional task linking for disease, pest,
  biofouling, discoloration, maintenance required, and thermal stress.
- Observation activity feed cards rely on propagated event parameters to
  surface disease/severity and related details.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Monitoring workspace must remain gated (FeatureAccessService + `config/tier_features.yaml`).
- Verify monitoring exports and non-coral monitoring dialog flows.

## Touchpoints
- Screen: `lib/screens/monitoring_screen.dart`
- Map: `lib/screens/monitoring/monitoring_map_screen.dart`
- Spreadsheets: `lib/widgets/spreadsheet/monitoring_*`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
