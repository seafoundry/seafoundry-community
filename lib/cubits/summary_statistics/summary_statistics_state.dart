// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

/// Tab selection for summary statistics display.
///
/// - `inventory`: Shows coral counts with tissue volume by category
/// - `observationHusbandry`: Shows operational metrics (tasks, observations, health issues)
/// - `tasks`: Shows task-related metrics
enum SummaryTab { inventory, observationHusbandry, tasks }

/// State for the summary statistics widget.
///
/// **State Management:**
/// - Manages active tab selection (inventory vs observation/husbandry)
/// - Manages health status filtering (selected status or "only issues" mode)
/// - Manages multiselect filters for site, structure, species, life stage, and genet
/// - Provides `filterSignature` for caching/memoization purposes
///
/// **Default Values:**
/// - `activeTab`: `SummaryTab.inventory` (shows inventory stats by default)
/// - `onlyIssues`: `false` (shows all corals by default)
/// - `selectedHealth`: `null` (no health filter by default)
/// - All multiselect filters: empty Set (no filter applied)
class SummaryStatisticsState extends Equatable {
  const SummaryStatisticsState({
    this.selectedHealth,
    this.onlyIssues = false,
    this.activeTab = SummaryTab.inventory,
    this.selectedSiteIds = const {},
    this.selectedSuperstructureIds = const {},
    this.selectedStructureIds = const {},
    this.selectedSubstructureIds = const {},
    this.selectedSpeciesIds = const {},
    this.selectedLifeStageIds = const {},
    this.selectedGenetIds = const {},
    this.analyticsTimePeriodDays = 30,
    this.selectedReasonIds = const {},
  });

  final HealthStatus? selectedHealth;
  final bool onlyIssues;
  final SummaryTab activeTab;
  final Set<String> selectedSiteIds;
  final Set<String> selectedSuperstructureIds;
  final Set<String> selectedStructureIds;
  final Set<String> selectedSubstructureIds;
  final Set<String> selectedSpeciesIds;
  final Set<String> selectedLifeStageIds;
  final Set<String> selectedGenetIds;
  final int analyticsTimePeriodDays;
  final Set<String> selectedReasonIds;

  /// Creates a copy of this state with the given fields replaced.
  ///
  /// **Nullable Field Pattern:**
  /// For `selectedHealth`, use a function wrapper to distinguish between
  /// "not specified" (null function) and "clear to null" (function returning null):
  /// - `copyWith()` - keeps current selectedHealth
  /// - `copyWith(selectedHealth: () => HealthStatus.healthy)` - sets to healthy
  /// - `copyWith(selectedHealth: () => null)` - clears to null
  SummaryStatisticsState copyWith({
    HealthStatus? Function()? selectedHealth,
    bool? onlyIssues,
    SummaryTab? activeTab,
    Set<String>? selectedSiteIds,
    Set<String>? selectedSuperstructureIds,
    Set<String>? selectedStructureIds,
    Set<String>? selectedSubstructureIds,
    Set<String>? selectedSpeciesIds,
    Set<String>? selectedLifeStageIds,
    Set<String>? selectedGenetIds,
    int? analyticsTimePeriodDays,
    Set<String>? selectedReasonIds,
  }) {
    return SummaryStatisticsState(
      selectedHealth: selectedHealth != null
          ? selectedHealth()
          : this.selectedHealth,
      onlyIssues: onlyIssues ?? this.onlyIssues,
      activeTab: activeTab ?? this.activeTab,
      selectedSiteIds: selectedSiteIds ?? this.selectedSiteIds,
      selectedSuperstructureIds:
          selectedSuperstructureIds ?? this.selectedSuperstructureIds,
      selectedStructureIds: selectedStructureIds ?? this.selectedStructureIds,
      selectedSubstructureIds:
          selectedSubstructureIds ?? this.selectedSubstructureIds,
      selectedSpeciesIds: selectedSpeciesIds ?? this.selectedSpeciesIds,
      selectedLifeStageIds: selectedLifeStageIds ?? this.selectedLifeStageIds,
      selectedGenetIds: selectedGenetIds ?? this.selectedGenetIds,
      analyticsTimePeriodDays:
          analyticsTimePeriodDays ?? this.analyticsTimePeriodDays,
      selectedReasonIds: selectedReasonIds ?? this.selectedReasonIds,
    );
  }

  /// Generates a unique signature string for the current filter state.
  ///
  /// **Format:** `{healthStatusId}_{filterMode}_{filters...}`
  /// - `healthStatusId`: The ID of the selected health status, or 'all' if none selected
  /// - `filterMode`: 'issues' if `onlyIssues` is true, 'all' otherwise
  /// - Each multiselect filter: sorted IDs joined by '+' or 'all' if empty
  ///
  /// **Use Case:** Can be used for caching statistics calculations based on filter state.
  String get filterSignature {
    final statusKey = selectedHealth?.id ?? 'all';
    final modeKey = onlyIssues ? 'issues' : 'all';
    final siteKey = _setToKey(selectedSiteIds);
    final superstructureKey = _setToKey(selectedSuperstructureIds);
    final structureKey = _setToKey(selectedStructureIds);
    final substructureKey = _setToKey(selectedSubstructureIds);
    final speciesKey = _setToKey(selectedSpeciesIds);
    final lifeStageKey = _setToKey(selectedLifeStageIds);
    final genetKey = _setToKey(selectedGenetIds);
    return '${statusKey}_$modeKey'
        '_$siteKey'
        '_$superstructureKey'
        '_$structureKey'
        '_$substructureKey'
        '_$speciesKey'
        '_$lifeStageKey'
        '_$genetKey';
  }

  /// Generates a unique signature for event analytics cache invalidation.
  ///
  /// Extends `filterSignature` with analytics-specific fields (time period,
  /// reason filter). Kept separate so organism stats caching is not
  /// invalidated by time period or reason changes.
  String get analyticsFilterSignature =>
      '${filterSignature}_${analyticsTimePeriodDays}_${_setToKey(selectedReasonIds)}';

  /// Converts a Set of IDs to a stable signature key.
  String _setToKey(Set<String> ids) {
    if (ids.isEmpty) return 'all';
    final sorted = ids.toList()..sort();
    return sorted.join('+');
  }

  /// Whether any filter is active (useful for showing "clear filters" button).
  bool get hasActiveFilters =>
      selectedSiteIds.isNotEmpty ||
      selectedSuperstructureIds.isNotEmpty ||
      selectedStructureIds.isNotEmpty ||
      selectedSubstructureIds.isNotEmpty ||
      selectedSpeciesIds.isNotEmpty ||
      selectedLifeStageIds.isNotEmpty ||
      selectedGenetIds.isNotEmpty ||
      selectedReasonIds.isNotEmpty;

  @override
  List<Object?> get props => [
    selectedHealth,
    onlyIssues,
    activeTab,
    selectedSiteIds,
    selectedSuperstructureIds,
    selectedStructureIds,
    selectedSubstructureIds,
    selectedSpeciesIds,
    selectedLifeStageIds,
    selectedGenetIds,
    analyticsTimePeriodDays,
    selectedReasonIds,
  ];
}
