# Permissions and Firebase Module (Claude Notes)

## Guardrails
- All Firestore access goes through repositories or `FirebaseService`.
- Keep rules, indexes, and collection docs in sync with schema changes.
- Membership checks must use UID-based docs under
  `organizations/{orgId}/members`.

## Critical Patterns

### UID-Based Identity (No Email-as-Key)
- User documents: `/users/{uid}` — keyed by Firebase Auth UID, never by email.
- Membership: `organizations/{orgId}/members/{uid}` — UID-keyed subcollection.
- Firestore rules: `isOrgMemberOf(orgId)` / `isMemberByUid(orgId)` are the only valid membership check functions. Never check membership by email.
- User lookups by email: query `.where("email", "==", email).limit(1).get()` — never `doc(email)`.

### Comment Authorization
- The `authorUid` field stores the Firebase Auth UID of the comment author (renamed from the legacy `authorEmail`).
- Firestore rules validate `request.resource.data.authorUid == getAuthUid()` on write.
- `CommentTargetType` enum with values `event`, `organismRecord`, `post` replaces string literals for `targetType`.

### Cloud Function Patterns
- Collection names are inlined directly (e.g., `'organizations'`, `'users'`). No helper functions like `isDemoOrganization()` or `getCollectionPath()`.
- **No demo routing**: All `demo_users`, `demo_organizations` references and dual-path routing have been removed. Functions operate on real collections only.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Tier constraints should remain community-only and explicit in services/rules.
- Firestore rules must align with new feature access paths.

## Touchpoints
- Rules: `firestore.rules`, `storage.rules`
- Functions: `functions/`
- Auth: `docs/architecture/AUTH_ARCHITECTURE.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
