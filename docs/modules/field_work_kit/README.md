# Field Work Kit Module

Operational planning surface for weather, tides, and site activity.

## Entry Points
- `lib/screens/field_work_kit/field_work_kit_screen.dart`

## Key UI and State
- Map uses `OutplantGoogleMap` with outplant and monitoring overlays.
- Cards and sheets surface weather, tides, and upcoming events.
- Site selection is held in widget state; data comes from repository streams.

## Data and Services
- `SiteRepository`, `EventRepository`, `MonitoringRepository`, `TaskEventRepository`.
- `WeatherServiceAdapter`, `NoaaTideService`, `SpeciesRegistry`.

## Critical Patterns
- Gate access via `FeatureAccessService` with the `monitoring_kml` feature flag.
- Use repository streams for sites, outplants, and monitoring events.
- Keep map overlays derived from repository data, not cached globals.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Staffing manifests should be wired to real data (no placeholders).
- Ensure offline/field workflows preserve provider context safety.

## Related Docs
- `docs/architecture/event_field_conventions.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
