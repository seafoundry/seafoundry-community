# Husbandry Module (Claude Notes)

## Guardrails
- Initialize tab cubits with organism filters from `OrganismContext`.
- Keep husbandry UI behind `FeatureAccessService` gating.
- Use dialog safety helpers for observation dialogs.

## Critical Patterns

### EventTaxonomy (Consolidated)
- `EventTaxonomy` and `HusbandryEventTaxonomyResolver` live in a single canonical file: `lib/widgets/spreadsheet/husbandry/husbandry_event_taxonomy.dart`.
- `EventTaxonomy` includes `lifeStageId`, `provenanceType`, and `buildProvenanceSelection()` logic.
- Do NOT create duplicate taxonomy classes in other files (e.g., `husbandry_logged_spreadsheet.dart`). Import from the canonical location.

### GenetIdResolver
- All genet ID lookups in husbandry code must use `GenetIdResolver.resolve(record)` — never `record.foreignKeys['genetId']?.id` directly.
- This applies to taxonomy resolution, task filtering, and spreadsheet data population.

### camelCase Map Keys
- All map keys in spreadsheet row data, filter maps, and serialized data must use camelCase.
- Examples: `eventId`, `eventType`, `physicalFormId`, `structurePath`, `taskType`, `issueTypeId`, `completionTime`, `genetTypeId`.
- No snake_case keys (`event_id`, `task_type`, etc.) are permitted.

### Task Enums
- Use `TaskPriority.medium.id` (not `'medium'`) for priority values.
- Use `EventType.task.id` (not `'event_task'`) for event type discrimination.
- Priority display: use `TaskPriority` enum values in switch statements, not string matching.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Ensure non-coral husbandry/observation flows render correct holdings panels.
- Task workflows should respect SOP enforcement gates.

## Touchpoints
- Screen: `lib/screens/husbandry_observations_screen.dart`
- Cubits: `lib/cubits/husbandry_tasks_tab/`, `lib/cubits/husbandry_logged_tab/`
- Taxonomy: `lib/widgets/spreadsheet/husbandry/husbandry_event_taxonomy.dart`
- Task filter: `lib/services/husbandry_task_filter_service.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
