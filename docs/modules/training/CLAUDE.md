# Training Module (Claude Notes)

## Guardrails
- Always construct repos with `organizationId` + Firestore from `FirebaseService`.
- `TrainingLibraryCubit` is the source of truth for filters and loaded data.
- Training progress writes must use the authenticated UID.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- SOP enforcement navigation should route to training/SOP as expected.
- Training completion gates should be respected in task flows.

## Touchpoints
- Screen: `lib/screens/training/training_library_screen.dart`
- Repos: `lib/repositories/training/`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
