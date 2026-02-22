# Public Screens Module

Public-facing org pages, playlists, and holdings map.

## Entry Points
- `lib/screens/public/public_org_screen.dart`
- `lib/screens/public/public_node_screen.dart`
- `lib/screens/public/public_holdings_map_screen.dart`
- `lib/screens/public/kiosk_entry.dart`

## Key UI and State
- Uses `BrandThemeProvider` to apply brand colors and assets.
- Preview gating via `PublicPreviewAccessService`.
- Public map supports impact points and CRC historical overlays.

## Data and Services
- `PublicReadModelsService` for brand, media, playlists, and impact points.
- `HistoricalDataService` and `ProvenanceCrosswalkService` for CRC datasets.
- `PublicRoute` and `PublicRouteDetector` for routing.

## Critical Patterns
- Never read private org collections from public screens.
- Use `PublicReadModelsService` and preview gating for unpublished assets.
- Keep sign-in actions routed to `AuthScreen`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Public impact map data should render or show a clear empty state.
- Public holdings map should continue to log errors via `LoggingService`.

## Related Docs
- `docs/api/public_read_models.md`
- `docs/architecture/community_vs_pro_rfc.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
