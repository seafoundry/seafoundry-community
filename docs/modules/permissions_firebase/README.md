# Permissions and Firebase Module

Auth, security rules, and Firebase infrastructure.

## Entry Points
- Service: `lib/services/firebase_service.dart`
- Rules: `firestore.rules`, `storage.rules`
- Firebase config: `firebase.json`, `firebase.community.json`
- Cloud Functions: `functions/`

## Identity and Permissions
- UID-based identity, org membership subcollection, role-based access.
- Authorization enforced in Firestore rules with `isMemberByUid`.
- UI gating via `FeatureAccessService` and `TierGate`.

## Operations and Tooling
- Emulator scripts: `dev-emulator.sh`, `seed_emulator.sh`
- CI setup: `docs/CI_FIREBASE_SETUP.md`
- Rules deploy runbook: `docs/FIRESTORE_RULES_DEPLOY_RUNBOOK.md`

## Critical Patterns
- Never use email as canonical ID; use UID.
- Use `FirestoreCollectionResolver` for nested vs root collections.
- Update rules and `docs/architecture/firestore_collections.md` when adding
  collections.
- Use Cloud Functions for privileged operations (exports, AI, taxonomy admin).

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Tier/feature gating should be consistent (FeatureAccessService + tier flags).
- Firestore rules must align with new feature access paths.

## Related Docs
- `docs/architecture/AUTH_ARCHITECTURE.md`
- `docs/architecture/firestore_collections.md`
- `docs/migration/RULES_MIGRATION_RUNBOOK.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
