# Organization Administration Module

Manages organization-level configuration, taxonomy, and compliance settings.

## Entry Points
- Organization node screen: `lib/screens/graph/organization_node_screen.dart`
- Profile dialog: `lib/screens/admin/edit_organization_profile_dialog.dart`

## Key Capabilities
- Organization profile and settings (community tier only, no billing).
- Taxonomy administration (species, provenance, morphologies, thresholds).
- Facilities configuration (hierarchy, site types).
- Compliance and deliverables (permits, deliverables, audits).
- Sync conflict review and resolution.

## Data and Services
- Repositories: `OrganizationRepository`, `CustomTypesRepository`,
  `OrganismConfigRepository`, `PermitRepository`, `DeliverableRepository`,
  `SiteRepository`.
- Services: `TaxonomyService`, `ProvenanceIdService`, `AliasUniquenessService`,
  `SiteLimitsService`.
- Firestore access flows through `FirebaseService` + `FirestoreCollectionResolver`.

## Critical Patterns
- Keep `TabController` lifecycles scoped to the screen state; avoid extra
  StatefulWidgets.
- Tier handling is community-only (`Tier.fromString` normalizes legacy values).
- Taxonomy edits must use canonical IDs from `taxonomy_species` and
  `taxonomy_provenances`.
- When adding collections, update `docs/architecture/firestore_collections.md`
  and rules.
- Use `SafeDialogMixin` or `SafeDialog` for admin dialogs.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Verify onboarding supports coral setup and CSV import flows.
- Community tier only; no billing/payment features.

## Related Docs
- `docs/architecture/taxonomy/README.md`
- `docs/architecture/firestore_collections.md`
- `docs/architecture/AUTH_ARCHITECTURE.md`
- `docs/FIRESTORE_RULES_DEPLOY_RUNBOOK.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
