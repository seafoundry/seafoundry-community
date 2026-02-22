# Reporting Module

Unified reporting hub for exports, permits, funders, deliverables, and analytics.

## Entry Points
- `lib/screens/reporting/reporting_hub_screen.dart` (drawer: Reporting)
- Tabs in `lib/widgets/reporting_hub/`.

## Key Capabilities
- Data export shortcuts into module holdings.
- Permit management and compliance tracking.
- Funders and deliverables with progress rollups.
- Analytics for deliverable performance.

## Data and Services
- Repositories: `DeliverableRepository`, `PermitRepository`,
  `OrganismRecordRepository`.
- Uses `FeatureAccessService` for tier gating.

## Critical Patterns
- Data export tab uses `WrappedNavigator` to open module holdings.
- Deliverable analytics pull inventory snapshots; keep this lightweight.
- Gate pro-only tabs using `FeatureAccessService` and `UpgradeCta`.
- Use event conventions for deliverable-linked outplant events.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Confirm Funder ROI export is enabled (`lib/screens/reporting/funder_roi_dashboard_screen.dart`).
- Keep CSV export schemas aligned with CSV v2 adapters.

## Related Docs
- `docs/REPORTING_ANALYTICS_DASHBOARD.md`
- `docs/architecture/event_field_conventions.md`
- `docs/architecture/firestore_collections.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
