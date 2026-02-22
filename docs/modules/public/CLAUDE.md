# Public Screens Module (Claude Notes)

## Guardrails
- Use `PublicReadModelsService` for all public data reads.
- Evaluate preview access with `PublicPreviewAccessService` before loading drafts.
- Keep public screens read-only; no private org writes.
- Wrap public views in `BrandThemeProvider` for consistent styling.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Public impact map data should render or show a clear empty state.
- Public holdings map should continue to log errors via `LoggingService`.

## Touchpoints
- `lib/screens/public/public_org_screen.dart`
- `lib/screens/public/public_node_screen.dart`
- `lib/screens/public/public_holdings_map_screen.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
