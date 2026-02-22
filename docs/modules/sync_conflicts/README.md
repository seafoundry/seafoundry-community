# Sync Conflicts Module

UI for resolving offline sync conflicts.

## Entry Points
- `lib/screens/sync_conflicts_screen.dart` (drawer: Sync Issues)
- List widget: `lib/widgets/sync_conflicts_list.dart`

## Data and Services
- Cubit: `SyncConflictCubit`
- Repository: `SyncConflictRepository`
- Resolution: `SyncConflictResolutionService`
- Models: `SyncConflictEntry`, `SyncConflictPage`

## Critical Patterns
- Call `startListening()` on the cubit when created.
- Use repository methods for accept local/server and dismiss actions.
- Keep conflict filters in sync with admin conflict tooling.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Conflict resolution flows must use `SyncConflictResolutionService`.
- Verify conflict screens are gated appropriately for org admins.

## Related Docs
- `docs/architecture/firestore_collections.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
