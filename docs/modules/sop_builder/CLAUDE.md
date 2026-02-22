# SOP Builder Module (Claude Notes)

## Guardrails
- The cubit owns SOP state; do not edit models outside the cubit.
- Text controllers must stay in sync with cubit state and be disposed.
- Publish/archive actions go through `SOPBuilderCubit`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- SOP edits must stay compatible with training enforcement requirements.
- Verify navigation from tasks to SOP builder/editor.

## Touchpoints
- Screen: `lib/screens/training/sop_builder_screen.dart`
- Cubit: `lib/cubits/training/sop_builder_cubit.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
