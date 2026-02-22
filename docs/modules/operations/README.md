# Operations Hub Module

Plans missions, tasks, calendars, insights, and fleet operations.

## Entry Points
- `lib/screens/mission_center/operations_hub_screen.dart` (drawer: Operations)

## Key UI and State
- Planning: `MissionEditDialog`, `MissionDetailsScreen`
- Tasks and calendar reuse husbandry task widgets
- Insights uses `ReportingDashboardTab`
- Fleet uses `VesselManagementDialog`

## Data and Services
- Repositories: `MissionRepository`, `VesselRepository`,
  `OrganismRecordRepository`, `SiteRepository`
- Cubits: `ReportDataCubit`, `ReportFilterCubit`, `HusbandryTasksTabCubit`

## Critical Patterns
- Keep `TabController` lifecycle in the screen state.
- Gate the module with `FeatureAccessService` and `UpgradeCta`.
- Use repository streams for missions and vessels; avoid direct Firestore.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Operations hub billing/upgrade surfaces should use PaymentService and tier flags.
- Keep admin dialogs aligned with SafeDialog patterns.

## Related Docs
- `docs/REPORTING_ANALYTICS_DASHBOARD.md`
- `lib/widgets/dialogs/components/README.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
