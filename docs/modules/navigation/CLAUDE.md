# Navigation Module (Claude Notes)

## Guardrails
- `NavigationCubit` is the source of truth for app navigation state.
- Use `WrappedNavigator` when pushing screens that rely on providers.
- Add new deep link patterns in `DeepLinkHandler` and update public routes if
  needed.
- Keep router delegate, parser, and `SimpleRouter` flows consistent.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Summary statistics should remain split into tab components and wired correctly.
- `WrappedNavigator` provider copying is required for safe navigation.

## Touchpoints
- `lib/navigation/`
- `lib/cubits/navigation/`
- `lib/patterns/navigation/deep_link_handler.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
