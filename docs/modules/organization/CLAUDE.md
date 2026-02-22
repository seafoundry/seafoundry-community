# Organization Module (Claude Notes)

## Guardrails
- Use `FirebaseService` and `FirestoreCollectionResolver` for all Firestore access.
- Keep taxonomy mutations inside `TaxonomyAdminService` and admin tabs; do not
  inline writes.
- Use `TierGate` and `FeatureAccessService` for gating. Do not hide tabs without
  a gate.
- Sync conflict actions should go through `SyncConflictResolutionService`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Verify onboarding supports non-coral setup and CSV import flows (`lib/screens/onboarding/organization_setup_page.dart`, `lib/screens/onboarding/data_import_page.dart`).
- Billing/tier settings should align with `FeatureAccessService` and `PaymentService`.

## Touchpoints
- Admin UI: `lib/widgets/admin/`
- Taxonomy tabs: `lib/screens/admin/taxonomy/tabs/`
- Organization screen: `lib/screens/admin/organization_structure_screen.dart`

## When Updating
- Update `docs/architecture/taxonomy/README.md` and
  `docs/architecture/firestore_collections.md` if schema or taxonomy rules change.
- Add or update security rules in `firestore.rules` and runbook docs.

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
