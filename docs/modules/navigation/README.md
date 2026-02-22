# Navigation Module

Graph-based navigation, routing, and deep link handling.

## Entry Points
- Router: `lib/navigation/simple_router.dart`
- Web routing: `lib/navigation/navigation_router_delegate.dart`,
  `lib/navigation/navigation_route_information_parser.dart`
- Navigation cubits: `lib/cubits/navigation/`
- Graph scaffolds: `lib/navigation/graph_scaffold.dart`,
  `lib/navigation/simple_navigation_widget.dart`

## Key Components
- Graph nodes and URL paths (inventory tree).
- `NavigationCubit` manages navigation stack and path resolution.
- `WrappedNavigator` captures providers for safe navigation.
- `NavigationViewModeCubit` toggles community vs organization view.

## Deep Links and Public Routes
- Deep links: `lib/patterns/navigation/deep_link_handler.dart`
- Public routes: `lib/navigation/public_route.dart` and
  `lib/navigation/public_route_detector.dart`

## Critical Patterns
- Use `GraphNode` objects for navigation, not raw records.
- Use `urlPath` for deep links and navigation state.
- Capture providers before dialogs and when using `WrappedNavigator`.
- Browser back/forward must stay in sync with `NavigationRouterDelegate`.

## Provider Copying with WrappedNavigator

`WrappedNavigator` copies providers from the parent context to child screens during navigation. This enables screens to access repositories and services without re-creating them.

### How It Works

1. **Provider Capture**: When `WrappedNavigator.push()` is called, it captures the current `User` and `Organization` as snapshots.

2. **Registry Integration**: The `_ProviderCopier` attempts to read the `RepositoryRegistry` from context. When available, it uses `registry.isRegistered<T>()` to efficiently check for instantiated types.

3. **Fallback Behavior**: When the parent context becomes unmounted (common during `pushReplacement`), `WrappedNavigator` falls back to creating a fresh `RepositoriesProvider` with the captured snapshots.

### Snapshot Staleness Trade-offs

The `User` and `Organization` values are **snapshots captured at navigation time**, not reactive streams:

- **Pro**: Navigation works reliably even during context transitions
- **Con**: If user/org changes after navigation, child screens won't automatically update
- **Mitigation**: User/org changes typically trigger full app reloads; screens needing reactive updates should use the `CurrentUser` cubit

### Navigation Flow

```
WrappedNavigator.push(context, screen)
        |
        v
Capture User/Organization snapshots
        |
        v
Navigator.push() with _ProviderWrapper
        |
        v
_ProviderWrapper.build()
        |
        v
[Is parent context mounted?]
        |
    +---+---+
    |       |
   Yes      No
    |       |
    v       v
Copy providers from   Create fresh
parent context via    RepositoriesProvider
_ProviderCopier       with snapshots
```

### Adding New Providers

When adding new repositories/services to `RepositoriesProvider`, also add them to `_ProviderCopier`:
- `copyRepositoryProviders()` for `RepositoryProvider<T>`
- `copyProviders()` for `Provider<T>`
- `copyChangeNotifierProviders()` for `ChangeNotifierProvider<T>`

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Summary statistics should remain split into tab components and wired correctly.
- `WrappedNavigator` provider copying is required for safe navigation.

## Related Docs
- `docs/architecture/graph_node_system.md`
- `lib/widgets/tour/README.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
