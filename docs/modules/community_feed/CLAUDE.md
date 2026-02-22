# Community Feed Module (Claude Notes)

## Guardrails
- Use `CommunityChannelRepository` and `CommunityChannelCubit` for channels.
- Use `CommunityHoldingsMap` to render the map and wire `PublicReadModelsService`.
- Switch views through `NavigationViewModeCubit`, not manual route changes.
- Channel creation and edits must go through `ChannelManagementDialog`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Channels/chat actions (DMs, settings, members, pins, attachments) should be enabled where intended.
- Comments UI should honor tier gating.

## Touchpoints
- `lib/screens/community/community_page_screen.dart`
- `lib/widgets/community/community_event_feed.dart`
- `lib/widgets/community/community_holdings_map.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
