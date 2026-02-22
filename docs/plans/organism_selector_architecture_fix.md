# OrganismSelector Architecture Fix - Consolidated Implementation Plan

## Executive Summary

This plan addresses the architectural shortcoming where `allowedKinds: OrganismKind.values` is used as a workaround in 9 files. The proper fix involves:
1. Adding defensive validation to `OrganismSelector._resolveKinds()`
2. Ensuring `EnabledOrganismsCubit` is always available where needed
3. Removing the workarounds once proper provider availability is confirmed

## Key Finding

**Critical Discovery**: All 9 workaround sites are actually inside `RepositoriesProvider` context where `EnabledOrganismsCubit` should already be available. The workarounds were likely added because:
- The cubit was added later and these widgets weren't updated
- Developers were unsure if the cubit would be available
- The fallback behavior wasn't well documented

## Implementation Phases

### Phase 1: Defensive Validation (Priority: HIGH, Effort: 2 hours)

**File**: `lib/widgets/common/organism_selector.dart`

Add comprehensive logging and assertions to detect misconfiguration early:

```dart
// Add at top of file
enum _OrganismResolutionSource {
  explicitAllowedKinds,
  enabledOrganismsCubit,
  organizationFallback,
  ultimateFallback,
}

class _ResolutionResult {
  final List<OrganismKind> kinds;
  final _OrganismResolutionSource source;
  final String? diagnosticMessage;

  const _ResolutionResult({
    required this.kinds,
    required this.source,
    this.diagnosticMessage,
  });

  bool get shouldWarn =>
    source == _OrganismResolutionSource.organizationFallback ||
    source == _OrganismResolutionSource.ultimateFallback ||
    kinds.isEmpty;
}
```

**Key Validation Points:**
1. Assert when `EnabledOrganismsCubit` is not found in widget tree
2. Assert when cubit returns empty `enabledOrganisms`
3. Log warning when falling back to `Organization.supportedOrganismKinds`
4. Log error when ultimate fallback (`[OrganismKind.coral]`) is triggered
5. Log debug when selected `value` is not in resolved kinds

### Phase 2: Remove Workarounds (Priority: HIGH, Effort: 1-2 hours)

Remove `allowedKinds: OrganismKind.values` from these 9 files (in order of risk):

| Order | File | Line | Risk |
|-------|------|------|------|
| 1 | `lib/widgets/spreadsheet/inventory/inventory_filter_bar.dart` | 99 | Low |
| 2 | `lib/widgets/spreadsheet/husbandry_tasks_spreadsheet.dart` | 178 | Low |
| 3 | `lib/widgets/spreadsheet/husbandry_logged_spreadsheet.dart` | 637 | Low |
| 4 | `lib/widgets/spreadsheet/holdings/holdings_spreadsheet.dart` | 349 | Low |
| 5 | `lib/widgets/spreadsheet/holdings/genetics_holdings_spreadsheet.dart` | 339 | Low |
| 6 | `lib/widgets/spreadsheet/outplant/outplant_holdings_spreadsheet.dart` | 288 | Low |
| 7 | `lib/widgets/workspaces/genetics_analytics.dart` | 72 | Low |
| 8 | `lib/widgets/dialogs/monitoring/monitoring_site_selector.dart` | 42 | Medium |
| 9 | `lib/widgets/dialogs/observation/unified_observation_dialog.dart` | 326 | Medium |

**For each file:**
1. Verify parent widget tree includes `RepositoriesProvider`
2. Remove `allowedKinds: OrganismKind.values` line
3. Run relevant tests
4. Verify no warnings logged in debug mode

### Phase 3: Test Coverage (Priority: HIGH, Effort: 3 hours)

**New Tests Needed:**

| Test Case | Priority | Location |
|-----------|----------|----------|
| Cubit available and loaded → uses cubit | P0 | `organism_selector_test.dart` |
| Cubit available but loading → falls back gracefully | P0 | `organism_selector_test.dart` |
| Cubit missing → asserts in debug, falls back in release | P1 | `organism_selector_test.dart` |
| Cubit returns empty list → asserts, hides widget | P1 | `organism_selector_test.dart` |
| Ultimate fallback triggered → logs error | P1 | `organism_selector_test.dart` |
| Value not in resolved kinds → logs debug | P2 | `organism_selector_test.dart` |
| Grey screen regression test | P0 | `inventory_events_spreadsheet_test.dart` |

### Phase 4: Documentation (Priority: MEDIUM, Effort: 30 min)

Update `OrganismSelector` class documentation to explain:
1. When to use explicit `allowedKinds` (admin screens, onboarding)
2. When to rely on cubit (normal app usage inside `RepositoriesProvider`)
3. The fallback hierarchy and when each path is used
4. Debug assertions that will fire during development

### Phase 5: Code Cleanup (Priority: LOW, Effort: 1 hour)

After Phase 2 verification:
1. Consider deprecating the Organization fallback path
2. Add documentation noting fallback paths are for backwards compatibility
3. Audit similar patterns in other files:
   - `summary_statistics.dart` - `OrganizationFilterCubit?`
   - `simplified_operations_map.dart` - `OrganizationFilterCubit?`
   - `chat_room_list_widget.dart` - `FeatureAccessService?`

## Files to Keep Using allowedKinds (NOT Workarounds)

These files intentionally pass `organismOptions` parameter for filter bar purposes:
- `holdings_filter_bar.dart` (line 136-139)
- `outplant_events_filter_bar.dart` (line 175-178)
- `genetics_filter_bar.dart` (line 292-295)
- `husbandry_logged_filter_bar.dart` (line 102-105)
- `husbandry_tasks_filter_bar.dart` (line 111-114)
- `observations_filter_bar.dart` (line 119-122)
- `monitoring_filter_bar.dart` (line 181-184)
- `csv_export_preview.dart` (line 65-68)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking change for users with disabled organisms | Medium | Low | Intentional - shows correct organisms |
| Debug assertions fire in tests | High | Low | Update tests to provide cubit |
| Dialogs don't have cubit access | Low | Medium | Verify dialog context before changes |

## Timeline

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1: Defensive Validation | 2 hours | None |
| Phase 2: Remove Workarounds | 1-2 hours | Phase 1 |
| Phase 3: Test Coverage | 3 hours | Phase 1 |
| Phase 4: Documentation | 30 min | Phase 1 |
| Phase 5: Code Cleanup | 1 hour | Phase 2, 3 |
| **Total** | **7.5-8.5 hours** | |

## Success Criteria

1. All debug assertions pass without firing in normal operation
2. No warnings logged when OrganismSelector is used within RepositoriesProvider
3. All 9 workaround files updated to use cubit properly
4. Test coverage for all resolution paths
5. Documentation updated with usage guidelines

## Rollback Plan

If issues arise after removing workarounds:
1. Re-add `allowedKinds: OrganismKind.values` to affected file
2. Investigate why cubit is unavailable in that context
3. Either fix provider tree or document as intentional admin screen
