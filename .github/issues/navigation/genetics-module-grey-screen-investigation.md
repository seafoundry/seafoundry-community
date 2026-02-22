# Genetics Module Grey Screen Investigation

**Status**: In Progress (Pending Deployment with Diagnostics)
**Priority**: P1
**Date**: 2026-01-15

## Issue Summary

When navigating to an organism record in the genetics module (e.g., clicking on an organism from the graph), the screen shows a grey unresponsive state instead of rendering the organism details.

## Console Output Observed

```
CacheManager: Removing pending load
GraphNode.awaitLoaded START: demo_org_pro_demo_recent_prod_1 (organismRecord)
...
Navigation completing successfully
RepositoriesProvider: disposing (Navigation Reset Risk)
```

## Root Cause Analysis

The `RepositoriesProvider` is being disposed **after** navigation completes successfully. This causes:
1. All repositories to become unavailable
2. `NavigationCubit` to be inaccessible
3. `SimpleNavigationWidget` falls back to showing a loading indicator (grey screen)

### Investigation Findings

#### 1. RepositoriesProviderWrapper BuildWhen Logic
- Location: `lib/widgets/repositories/repositories_provider_wrapper.dart:22-78`
- The `buildWhen` predicate correctly guards against rebuilding for:
  - `CurrentUserLoaded` → `CurrentUserError` (returns false)
  - `CurrentUserLoaded` → `CurrentUserLoading` (falls through to false)
- However, something is triggering a rebuild after navigation completes

#### 2. CurrentUser Stream Updates
- Location: `lib/cubits/current_user/current_user_cubit.dart:32-74`
- The cubit listens to Firestore streams for user and organization changes
- `_updateState()` at lines 76-119 has guards to prevent state downgrades
- But stream errors emit `CurrentUserError` directly

#### 3. OrganismNodeScreen Dependencies
- Location: `lib/screens/graph/organism_node_screen.dart`
- Uses multiple `context.read<T>()` calls:
  - `OrganismRecordRepository` (lines 253, 305, 364)
  - `CurrentUser` (lines 254, 365, 417)
  - `FeatureAccessService` (line 485 - with try/catch)
- Unlike `SiteNodeScreen`, lacks `BrandThemeProvider` wrapper

#### 4. Seeding Data Analysis
- Location: `scripts/seed-demo.js:3510-3580`
- Recent production organisms are correctly structured with all required fields
- `OrganismRecord.fromJson` handles missing `organismKind` (defaults to coral)
- `lifeStageId` string format is properly parsed via `_parseLifeStage()`

### Diagnostic Logging Added

**File: `lib/widgets/repositories/repositories_provider.dart` (lines 248-255)**
```dart
@override
void dispose() {
  debugPrint('RepositoriesProvider: disposing (Navigation Reset Risk)');
  // Capture stack trace to diagnose unexpected disposal
  debugPrint('RepositoriesProvider: disposal stack trace:');
  debugPrint(StackTrace.current.toString().split('\n').take(15).join('\n'));
  _disposeRepositories();
  super.dispose();
}
```

**File: `lib/widgets/repositories/repositories_provider_wrapper.dart` (line 23)**
```dart
buildWhen: (previous, current) {
  debugPrint('RepositoriesProviderWrapper.buildWhen: ${previous.runtimeType} -> ${current.runtimeType}');
  // ... existing logic
}
```

## Hypotheses

1. **Stream Error During Navigation**: A Firestore stream (user or organization) emits an error that triggers `CurrentUserError`, but the error happens before `CurrentUserLoaded` is set as `previous` state.

2. **Race Condition**: Multiple state transitions happen in quick succession during navigation, causing the `buildWhen` guards to be bypassed.

3. **Organism-Specific Trigger**: Something unique to organism node loading (vs site/group) triggers a CurrentUser state change.

## Next Steps

1. **Deploy with diagnostics** - The stack trace capture will show exactly what triggers the disposal
2. **Reproduce issue** - Navigate to organism and capture console output
3. **Analyze stack trace** - Identify the call chain leading to disposal
4. **Implement fix** based on findings

## Files Involved

| File | Relevance |
|------|-----------|
| `lib/widgets/repositories/repositories_provider.dart` | Disposal point with diagnostics |
| `lib/widgets/repositories/repositories_provider_wrapper.dart` | BuildWhen logic for rebuilds |
| `lib/cubits/current_user/current_user_cubit.dart` | Stream listeners that may trigger state changes |
| `lib/screens/graph/organism_node_screen.dart` | Target screen that fails to render |
| `lib/navigation/simple_navigation_widget.dart` | Falls back to loading on provider unavailable |
| `lib/cubits/navigation/navigation_cubit.dart` | Navigation flow logging |

## Related Issues

- Architecture Review Plan: `.claude/plans/iridescent-splashing-cocoa.md`
- Event Stream Pagination: `docs/architecture/EVENT_STREAM_PAGINATION.md`
