# Organization Module (Claude Notes)

## Guardrails
- Use `FirebaseService` and `FirestoreCollectionResolver` for all Firestore access.
- Keep taxonomy mutations inside `TaxonomyAdminService` and admin tabs; do not
  inline writes.
- Tier handling is community-only (`Tier.fromString` normalizes legacy values).

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Verify onboarding supports coral setup and CSV import flows.
- Community tier only; no billing/payment features.

## Touchpoints
- Organization node screen: `lib/screens/graph/organization_node_screen.dart`
- Profile dialog: `lib/screens/admin/edit_organization_profile_dialog.dart`

## When Updating
- Update `docs/architecture/taxonomy/README.md` and
  `docs/architecture/firestore_collections.md` if schema or taxonomy rules change.
- Add or update security rules in `firestore.rules` and runbook docs.

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
