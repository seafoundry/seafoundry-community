# Settings Module

Organization settings dialog focused on public brand profile and links.

## Entry Points
- `lib/screens/admin/edit_organization_profile_dialog.dart`

## Key UI and State
- Brand profile fields (hero image, logo, accent color, social links).
- Image uploads handled via Firebase Storage.

## Data and Services
- `BrandProfileRepository` for profile writes.
- `PublicReadModelsService` for preview reads.
- `FirebaseStorage` for hero and logo uploads.
- `CurrentUser` provides organization context.

## Critical Patterns
- Use `SafeDialogMixin` for async safety.
- Do not write Firestore directly; use `BrandProfileRepository.upsertBrandProfile`.
- Storage paths live under `organizations/{orgId}/brand/`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Community tier only; upgrade surfaces show external URL, no in-app billing.

## Related Docs
- `docs/api/public_read_models.md`
- `lib/widgets/dialogs/components/README.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
