# Organization Administration Module

Manages organization-level configuration, taxonomy, and compliance settings.

## Entry Points
- `lib/screens/admin/organization_structure_screen.dart` (drawer: Organization)
- Related tabs and widgets live under `lib/widgets/admin/` and
  `lib/screens/admin/taxonomy/`.

## Key Capabilities
- Organization profile, billing, and tier settings.
- Taxonomy administration (species, provenance, morphologies, thresholds).
- Facilities configuration (hierarchy, site types, fleet).
- Compliance and deliverables (permits, deliverables, audits).
- Sync conflict review and resolution.

## Data and Services
- Repositories: `OrganizationRepository`, `CustomTypesRepository`,
  `OrganismConfigRepository`, `PermitRepository`, `DeliverableRepository`,
  `VesselRepository`.
- Services: `TaxonomyAdminService`, `ObservationFieldOverrideService`,
  `SyncConflictResolutionService`, `SeedingService`, `PaymentService`.
- Firestore access flows through `FirebaseService` + `FirestoreCollectionResolver`.

## Critical Patterns
- Keep `TabController` lifecycles scoped to the screen state; avoid extra
  StatefulWidgets.
- Use `TierGate`/`FeatureAccessService` for pro or scale gates.
- Taxonomy edits must use canonical IDs from `taxonomy_species` and
  `taxonomy_provenances`.
- When adding collections, update `docs/architecture/firestore_collections.md`
  and rules.
- Use `SafeDialogMixin` or `SafeDialog` for admin dialogs.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Verify onboarding supports non-coral setup and CSV import flows (`lib/screens/onboarding/organization_setup_page.dart`, `lib/screens/onboarding/data_import_page.dart`).
- Billing/tier settings should align with `FeatureAccessService` and `PaymentService`.

## Related Docs
- `docs/architecture/taxonomy/README.md`
- `docs/architecture/firestore_collections.md`
- `docs/architecture/AUTH_ARCHITECTURE.md`
- `docs/FIRESTORE_RULES_DEPLOY_RUNBOOK.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
