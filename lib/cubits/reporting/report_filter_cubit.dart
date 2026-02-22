// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/reporting/report_filter_state.dart';
import 'package:seafoundry_app/models/reporting/filter_config.dart';
import 'package:seafoundry_app/models/reporting/time_range_config.dart';

/// Cubit managing report filter state.
///
/// Handles:
/// - Time range selection with presets
/// - Multi-level filtering (site, structure, species, etc.)
/// - Filter toggle/clear operations
/// - Dirty state tracking for unsaved changes
class ReportFilterCubit extends Cubit<ReportFilterState> {
  ReportFilterCubit({
    TimeRangeConfig? initialTimeRange,
    FilterConfig? initialFilters,
  }) : super(ReportFilterActive(
          timeRange: initialTimeRange ?? const TimeRangeConfig.last30Days(),
          filters: initialFilters ?? const FilterConfig(),
        ));

  /// Get current filter state (safe cast).
  ReportFilterActive? get activeState {
    final current = state;
    return current is ReportFilterActive ? current : null;
  }

  /// Update time range preset.
  void setTimeRangePreset(TimeRangePreset preset) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      timeRange: current.timeRange.copyWith(preset: preset),
      isDirty: true,
    ));
  }

  /// Update custom date range.
  void setCustomDateRange(DateTime start, DateTime end) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      timeRange: TimeRangeConfig.custom(start: start, end: end),
      isDirty: true,
    ));
  }

  /// Toggle comparison mode (Pro feature).
  void toggleComparison(bool enabled) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      timeRange: current.timeRange.copyWith(comparisonEnabled: enabled),
      isDirty: true,
    ));
  }

  /// Toggle site filter.
  void toggleSite(String siteId) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.toggleSite(siteId),
      isDirty: true,
    ));
  }

  /// Set site IDs filter.
  void setSiteIds(Set<String> siteIds) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(siteIds: siteIds),
      isDirty: true,
    ));
  }

  /// Set structure IDs filter.
  void setStructureIds(Set<String> structureIds) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(structureIds: structureIds),
      isDirty: true,
    ));
  }

  /// Set species IDs filter.
  void setSpeciesIds(Set<String> speciesIds) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(speciesIds: speciesIds),
      isDirty: true,
    ));
  }

  /// Set genet IDs filter.
  void setGenetIds(Set<String> genetIds) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(genetIds: genetIds),
      isDirty: true,
    ));
  }

  /// Set life stage IDs filter.
  void setLifeStageIds(Set<String> lifeStageIds) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(lifeStageIds: lifeStageIds),
      isDirty: true,
    ));
  }

  /// Set health status IDs filter.
  void setHealthStatusIds(Set<String> healthStatusIds) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(healthStatusIds: healthStatusIds),
      isDirty: true,
    ));
  }

  /// Set zone IDs filter.
  void setZoneIds(Set<String> zoneIds) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(zoneIds: zoneIds),
      isDirty: true,
    ));
  }

  /// Toggle cross-site aggregation (Pro feature).
  void toggleCrossSiteAggregation(bool enabled) {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: current.filters.copyWith(crossSiteAggregation: enabled),
      isDirty: true,
    ));
  }

  /// Clear all filters.
  void clearFilters() {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      filters: const FilterConfig(),
      isDirty: true,
    ));
  }

  /// Reset to initial state.
  void reset() {
    emit(const ReportFilterActive(
      timeRange: TimeRangeConfig.last30Days(),
      filters: FilterConfig(),
    ));
  }

  /// Mark state as clean (after save).
  void markClean() {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(isDirty: false));
  }

  /// Apply a complete filter configuration.
  void applyConfiguration(TimeRangeConfig timeRange, FilterConfig filters) {
    emit(ReportFilterActive(
      timeRange: timeRange,
      filters: filters,
      isDirty: false,
    ));
  }
}
