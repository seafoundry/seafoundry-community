# Field Work Kit Module (Claude Notes)

## Guardrails
- Check `FeatureAccessService.isFeatureEnabled('monitoring_kml')` before loading.
- Use repository streams: `SiteRepository.streamAll`,
  `EventRepository.streamOutplantEvents`, `MonitoringRepository.streamAll`.
- Wrap weather and tide calls with mounted checks and error handling.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Staffing manifests should be wired to real data (no placeholders).
- Ensure offline/field workflows preserve provider context safety.

## Touchpoints
- `lib/screens/field_work_kit/field_work_kit_screen.dart`
- `lib/widgets/map/outplant_google_map.dart`
- `lib/widgets/dashboard/org_calendar_widget.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
