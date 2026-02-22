# SOP Builder Module

Create and edit SOPs for training workflows.

## Entry Points
- `lib/screens/training/sop_builder_screen.dart` (drawer: SOP Builder)

## Key UI and State
- `SOPBuilderCubit` manages draft, save, publish, and archive state.
- Step editing uses `SOPStepEditor` and `SOPStep` models.

## Data and Services
- Repositories: `SOPRepository`
- Models: `SOP`, `SOPStep`

## Critical Patterns
- Always call `SOPBuilderCubit.createNew` or `loadExisting` once.
- Use `organizationId` and `userId` from the caller when creating a SOP.
- Handle `SOPBuilderSaved` and `SOPBuilderError` states in the UI.
- Keep preview mode state local; do not mutate `SOP` directly.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- SOP edits must stay compatible with training enforcement requirements.
- Verify navigation from tasks to SOP builder/editor.

## Related Docs
- `lib/widgets/dialogs/components/README.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
