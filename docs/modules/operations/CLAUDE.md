# Operations Hub Module (Claude Notes)

## Guardrails
- `TabController` length must match the tabs and `TabBarView`.
- Missions should use `MissionRepository.watchMissionsForOrg`.
- Fleet management uses `VesselRepository` and `VesselAvailabilityService`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Operations hub billing/upgrade surfaces should use PaymentService and tier flags.
- Keep admin dialogs aligned with SafeDialog patterns.

## Touchpoints
- Screen: `lib/screens/mission_center/operations_hub_screen.dart`
- Dialogs: `lib/widgets/dialogs/mission_edit_dialog.dart`,
  `lib/widgets/dialogs/vessel_management_dialog.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
