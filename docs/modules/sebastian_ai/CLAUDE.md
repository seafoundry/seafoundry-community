# Sebastian AI Module (Claude Notes)

## Guardrails
- Use `SebastianService` for all requests; do not bypass Cloud Functions.
- Ensure navigation context is provided when available.
- Respect tier gating via `FeatureAccessService`.

## Critical Patterns

### Cloud Function Handlers
- `functions/src/sebastian/function-handlers.ts` contains all Sebastian handler implementations.
- Collection names are referenced directly as string literals (e.g., `'organizations'`, `'users'`, `'events'`) — no indirection through helper functions.
- `isDemoOrganization()` and `getCollectionPath()` have been removed. These were dead code that added unnecessary Firestore reads per request. If you see any reference to these functions, delete it and inline the collection name.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Ensure AI entry points are gated by `FeatureAccessService` and org settings.
- Keep Sebastian panel wiring in sync with monitoring/training contexts.

## Touchpoints
- Screen: `lib/screens/sebastian/sebastian_screen.dart`
- Service: `lib/services/sebastian/sebastian_service.dart`
- Handlers: `functions/src/sebastian/function-handlers.ts`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
