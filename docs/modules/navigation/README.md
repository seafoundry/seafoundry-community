# Navigation Module

Graph-based navigation, routing, and deep link handling.

## Entry Points
- Router: `lib/navigation/simple_router.dart`
- Web routing: `lib/navigation/navigation_router_delegate.dart`,
  `lib/navigation/navigation_route_information_parser.dart`
- Navigation cubits: `lib/cubits/navigation/`
- Graph scaffolds: `lib/navigation/community_graph_scaffold.dart`,
  `lib/navigation/simple_navigation_widget.dart`

## Key Components
- Graph nodes and URL paths (inventory tree).
- `NavigationCubit` manages navigation stack and path resolution.
- `WrappedNavigator` captures providers for safe navigation.
## Deep Links
- Deep links: `lib/patterns/navigation/deep_link_handler.dart`

## Critical Patterns
- Use `GraphNode` objects for navigation, not raw records.
- Use `urlPath` for deep links and navigation state.
- Capture providers before dialogs.
- Browser back/forward must stay in sync with `NavigationRouterDelegate`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Summary statistics should remain split into tab components and wired correctly.
- Provider context safety is required for safe navigation.

## Related Docs
- `docs/architecture/graph_node_system.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
