# Settings Module (Claude Notes)

## Guardrails
- Build settings dialogs with `SafeDialogMixin` and mounted checks.
- Persist brand profile updates via `BrandProfileRepository` only.
- Fetch previews with `PublicReadModelsService` instead of direct Firestore reads.
- Use `FirebaseStorage` for uploads and keep storage paths consistent.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Community tier only; upgrade surfaces show external URL, no in-app billing.

## Touchpoints
- `lib/screens/admin/edit_organization_profile_dialog.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
