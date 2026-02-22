# Community Feed Module

Community view that combines the public holdings map with a cross-org event feed.

## Entry Points
- `lib/screens/community/community_page_screen.dart`
- `lib/screens/community/community_sidebar.dart`
- `lib/widgets/community/community_event_feed.dart`
- `lib/widgets/community/community_holdings_map.dart`

## Key UI and State
- Channels are loaded by `CommunityChannelCubit` from `CommunityChannelRepository`.
- Channel management uses `ChannelManagementDialog` with `ChannelType.community`.
- `NavigationViewModeCubit` toggles community vs organization views.

## Data and Services
- `CommunityChannelRepository` for channel CRUD and selections.
- `PublicReadModelsService` for map data via `PublicHoldingsMapScreen`.

## Critical Patterns
- Use `CommunityHoldingsMap` to embed `PublicHoldingsMapScreen` with
  `orgId: 'community'`.
- Keep channel selection in the cubit, not widget state.
- Community view should not query org-scoped repositories directly.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Channels/chat actions (DMs, settings, members, pins, attachments) should be enabled where intended.
- Comments UI should honor tier gating.

## Related Docs
- `docs/api/public_read_models.md`
- `docs/architecture/community_vs_pro_rfc.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
