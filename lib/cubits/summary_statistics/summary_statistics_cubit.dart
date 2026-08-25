import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/cubits/summary_statistics/summary_statistics_state.dart';
import 'package:seafoundry_community/models/types/health_status.dart';

/// Cubit managing the state of the summary statistics widget.
///
/// **Responsibilities:**
/// - Manages health status filtering
/// - Ensures filter state consistency (e.g., clearing selected health when "only issues" is enabled)
///
/// **State Mutations:**
/// - `healthFilterChanged`: Sets a specific health status filter, clears "only issues" mode
/// - `onlyIssuesChanged`: Toggles "only issues" mode, clears selected health if enabled
class SummaryStatisticsCubit extends Cubit<SummaryStatisticsState> {
  SummaryStatisticsCubit({SummaryTab initialTab = SummaryTab.inventory})
    : super(SummaryStatisticsState(activeTab: initialTab));

  /// Updates the health status filter.
  ///
  /// **Behavior:**
  /// - Sets `selectedHealth` to the provided value (or clears it if null)
  /// - Automatically clears `onlyIssues` mode (they are mutually exclusive)
  void healthFilterChanged(HealthStatus? health) {
    emit(state.copyWith(selectedHealth: () => health, onlyIssues: false));
  }

  /// Toggles the "only issues" filter mode.
  ///
  /// **Behavior:**
  /// - When enabled: Clears `selectedHealth` (shows all non-healthy corals)
  /// - When disabled: Preserves current `selectedHealth` if set
  void onlyIssuesChanged(bool onlyIssues) {
    emit(
      state.copyWith(
        onlyIssues: onlyIssues,
        selectedHealth: onlyIssues ? () => null : null,
      ),
    );
  }

  /// Updates the selected site IDs.
  ///
  /// When sites change, structures, species, life stages, and genets are
  /// preserved but may be filtered in the UI based on cascading logic.
  void siteFilterChanged(Set<String> siteIds) {
    emit(state.copyWith(selectedSiteIds: _normalizeFilterSet(siteIds)));
  }

  /// Updates the selected superstructure IDs.
  ///
  /// **Cascading Behavior:**
  /// - Clears structure and substructure selections (downstream filters)
  void superstructureFilterChanged(Set<String> superstructureIds) {
    emit(state.copyWith(
      selectedSuperstructureIds: _normalizeFilterSet(superstructureIds),
      selectedStructureIds: const {},
      selectedSubstructureIds: const {},
    ));
  }

  /// Updates the selected structure IDs.
  ///
  /// **Cascading Behavior:**
  /// - Clears substructure selection (downstream filter)
  void structureFilterChanged(Set<String> structureIds) {
    emit(state.copyWith(
      selectedStructureIds: _normalizeFilterSet(structureIds),
      selectedSubstructureIds: const {},
    ));
  }

  /// Updates the selected substructure IDs.
  void substructureFilterChanged(Set<String> substructureIds) {
    emit(state.copyWith(
      selectedSubstructureIds: _normalizeFilterSet(substructureIds),
    ));
  }

  /// Updates the selected species IDs.
  void speciesFilterChanged(Set<String> speciesIds) {
    emit(state.copyWith(selectedSpeciesIds: _normalizeFilterSet(speciesIds)));
  }

  /// Updates the selected life stage IDs.
  void lifeStageFilterChanged(Set<String> lifeStageIds) {
    emit(state.copyWith(selectedLifeStageIds: _normalizeFilterSet(lifeStageIds)));
  }

  /// Updates the selected genet IDs.
  void genetFilterChanged(Set<String> genetIds) {
    emit(state.copyWith(selectedGenetIds: _normalizeFilterSet(genetIds)));
  }

  /// Updates the analytics time period in days.
  void analyticsTimePeriodChanged(int days) {
    emit(state.copyWith(analyticsTimePeriodDays: days));
  }

  /// Updates the selected reason IDs for analytics filtering.
  void reasonFilterChanged(Set<String> reasonIds) {
    emit(state.copyWith(selectedReasonIds: _normalizeFilterSet(reasonIds)));
  }

  /// Clears all multiselect filters.
  void clearAllFilters() {
    emit(state.copyWith(
      selectedSiteIds: const {},
      selectedSuperstructureIds: const {},
      selectedStructureIds: const {},
      selectedSubstructureIds: const {},
      selectedSpeciesIds: const {},
      selectedLifeStageIds: const {},
      selectedGenetIds: const {},
      selectedReasonIds: const {},
    ));
  }

  Set<String> _normalizeFilterSet(Set<String> values) {
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
  }
}
