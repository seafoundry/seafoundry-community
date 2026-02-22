# Genetics Module

Tracks genotypes and provenance data plus transfer workflows.

## Entry Points
- `lib/screens/genetics_screen.dart` (drawer: Genetics)
- Views: `lib/widgets/workspaces/genetics_analytics.dart`,
  `lib/widgets/workspaces/genetics_holdings_view.dart`,
  `lib/widgets/workspaces/genetics_events_view.dart`.

## Key UI and State
- Genet creation: `lib/widgets/dialogs/create_genet_dialog.dart`
- Pending transfers: `lib/widgets/dialogs/pending_transfers_dialog.dart`
- Transfers: `lib/widgets/dialogs/transfer/` (see local CLAUDE)
- Spreadsheets: `lib/widgets/spreadsheet/genetics/` and
  `lib/widgets/spreadsheet/genetics_events_table.dart`

## Data and Services
- Models: `Genet`, `ProvenanceRecord`
- Repositories: `GenetRepository`, `OrganismRecordRepository`,
  `EventRepository`
- Cubits: `TransferCountCubit`, genet creation/name validation cubits

## CSV Import and Export
- UI entry: `UniversalCSVDialog` with `CsvTemplateKind.genetics`
- Follows CSV v2 conventions and taxonomy registry.

## Critical Patterns
- Use `UniqueNameValidationService` to normalize genet local IDs.
- Transfers must capture required providers before `showDialog`
  (see `lib/widgets/dialogs/transfer/CLAUDE.md`).
- Event tables should use `EventSpreadsheetShell` for consistency.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Validate transfer workflows for non-coral organisms and holdings panels.
- Ensure transfer manifests preserve canonical provenance metadata.

## Related Docs
- `docs/architecture/taxonomy/README.md`
- `lib/widgets/dialogs/transfer/CLAUDE.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
