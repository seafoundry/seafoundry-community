# Training Library Module

Library of training media and SOPs with progress tracking.

## Entry Points
- `lib/screens/training/training_library_screen.dart` (drawer: Training)
- Viewer: `lib/screens/training/sop_viewer_screen.dart`

## Key UI and State
- Cubits: `TrainingLibraryCubit`, `SOPViewerCubit`
- Widgets: `TrainingMediaCard`, `SOPManagementDialog`,
  `TrainingMediaManagementDialog`

## Data and Services
- Repositories: `TrainingMediaRepository`, `SOPRepository`,
  `TrainingProgressRepository`, `SOPCompletionRepository`
- Uses `FirebaseService` to build repositories per org.

## Critical Patterns
- Resolve `userId` from `AuthBloc` for progress writes.
- Keep training media scoped to `organizationId`.
- Use `WrappedNavigator` for navigation into viewer screens when needed.
- Dialogs should follow `SafeDialogMixin`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- SOP enforcement navigation should route to training/SOP as expected.
- Training completion gates should be respected in task flows.

## Related Docs
- `docs/architecture/AUTH_ARCHITECTURE.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
