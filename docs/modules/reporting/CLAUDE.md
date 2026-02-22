# Reporting Module (Claude Notes)

## Guardrails
- Use repositories for all data; avoid direct Firestore queries in widgets.
- When adding a tab, update TabController length and `TabBarView` order together.
- Keep pro gates consistent with `FeatureAccessService`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Confirm Funder ROI export is enabled (`lib/screens/reporting/funder_roi_dashboard_screen.dart`).
- Keep CSV export schemas aligned with CSV v2 adapters.

## Touchpoints
- Screen: `lib/screens/reporting/reporting_hub_screen.dart`
- Hub widgets: `lib/widgets/reporting_hub/`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
