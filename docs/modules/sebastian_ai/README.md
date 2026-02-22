# Sebastian AI Module

AI assistant for natural language queries and guided workflows.

## Entry Points
- `lib/screens/sebastian/sebastian_screen.dart` (drawer: Sebastian AI)
- Embedded panel: `lib/widgets/sebastian/sebastian_panel_wrapper.dart`

## Key UI and State
- Cubit: `SebastianChatCubit`
- Widgets: `SebastianChatPanel`, `SebastianPanelWrapper`

## Data and Services
- Service: `SebastianService` (Cloud Functions + streaming)
- Models: `SebastianMessage`, `SebastianContext`

## Critical Patterns
- Always pass `organizationId`, `userId`, and `tier`.
- Use `SebastianPanelWrapper` to wire navigation context when embedded.
- LLM calls happen server-side via Cloud Functions; avoid direct API calls.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Ensure AI entry points are gated by `FeatureAccessService` and org settings.
- Keep Sebastian panel wiring in sync with monitoring/training contexts.

## Related Docs
- `docs/architecture/sebastian_ai.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
