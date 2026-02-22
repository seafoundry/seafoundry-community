# Sync Conflicts Module (Claude Notes)

## Guardrails
- `SyncConflictCubit` must call `startListening()` after creation.
- Use `SyncConflictResolutionService` for resolution logic.
- Do not write conflict docs directly from UI code.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Conflict resolution flows must use `SyncConflictResolutionService`.
- Verify conflict screens are gated appropriately for org admins.

## Touchpoints
- Screen: `lib/screens/sync_conflicts_screen.dart`
- Repo: `lib/repositories/sync_conflict_repository.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
