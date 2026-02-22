# Husbandry and Observations Module

Tracks husbandry tasks, observations, and health analytics.

## Entry Points
- `lib/screens/husbandry_observations_screen.dart` (drawer: Husbandry)
- Tabs: `HusbandryObservationsTab`, `HusbandryCalendarTab`,
  `HusbandryTasksListTab`, `HusbandryLoggedTab`, `HusbandryHealthAnalyticsView`.

## Key UI and State
- Task and logged lists are driven by `HusbandryTasksTabCubit` and
  `HusbandryLoggedTabCubit`.
- Uses `OrganismContext` to filter by organism kind.

## Data and Services
- Repository access through `RecordRepository`.
- Event types include feeding, cleaning, treatments, and observations.

## CSV
- Template download uses `CsvTemplateKind.husbandryObservations`.

## Critical Patterns
- Gate access with `FeatureAccessService` and `ProGate`.
- Use `SafeDialogMixin` for observation dialogs and async actions.
- Align event payloads with `docs/architecture/event_field_conventions.md`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Ensure non-coral husbandry/observation flows render correct holdings panels.
- Task workflows should respect SOP enforcement gates.

## Related Docs
- `docs/architecture/event_field_conventions.md`
- `lib/widgets/dialogs/components/README.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
