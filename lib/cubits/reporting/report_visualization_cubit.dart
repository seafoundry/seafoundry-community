// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/reporting/report_visualization_state.dart';
import 'package:seafoundry_app/models/reporting/visualization_config.dart';
import 'package:uuid/uuid.dart';

/// Cubit managing report visualization configurations.
///
/// Handles:
/// - Adding/removing visualizations
/// - Updating visualization properties
/// - Reordering visualizations in layout
/// - Selection for editing
class ReportVisualizationCubit extends Cubit<ReportVisualizationState> {
  ReportVisualizationCubit({
    List<VisualizationConfig>? initialVisualizations,
  }) : super(ReportVisualizationActive(
          visualizations: initialVisualizations ?? const [],
        ));

  final _uuid = const Uuid();

  /// Get current active state (safe cast).
  ReportVisualizationActive? get activeState {
    final current = state;
    return current is ReportVisualizationActive ? current : null;
  }

  /// Add a new visualization.
  void addVisualization(VisualizationType type, {String? title}) {
    final current = activeState;
    if (current == null) return;

    final config = VisualizationConfig(
      id: _uuid.v4(),
      type: type,
      title: title ?? _defaultTitle(type),
      dataSource: _defaultDataSource(type),
    );

    emit(current.copyWith(
      visualizations: [...current.visualizations, config],
      selectedId: config.id,
      isDirty: true,
    ));
  }

  /// Remove a visualization by ID.
  void removeVisualization(String id) {
    final current = activeState;
    if (current == null) return;

    final newVisualizations =
        current.visualizations.where((v) => v.id != id).toList();

    emit(current.copyWith(
      visualizations: newVisualizations,
      selectedId: current.selectedId == id ? null : current.selectedId,
      clearSelectedId: current.selectedId == id,
      isDirty: true,
    ));
  }

  /// Update a visualization's configuration.
  void updateVisualization(VisualizationConfig updated) {
    final current = activeState;
    if (current == null) return;

    final newVisualizations = current.visualizations.map((v) {
      return v.id == updated.id ? updated : v;
    }).toList();

    emit(current.copyWith(
      visualizations: newVisualizations,
      isDirty: true,
    ));
  }

  /// Update visualization title.
  void updateTitle(String id, String title) {
    final current = activeState;
    if (current == null) return;

    final visualization = current.getById(id);
    if (visualization == null) return;

    updateVisualization(visualization.copyWith(title: title));
  }

  /// Update visualization data source.
  void updateDataSource(String id, DataSourceConfig dataSource) {
    final current = activeState;
    if (current == null) return;

    final visualization = current.getById(id);
    if (visualization == null) return;

    updateVisualization(visualization.copyWith(dataSource: dataSource));
  }

  /// Update visualization style.
  void updateStyle(String id, VisualizationStyle style) {
    final current = activeState;
    if (current == null) return;

    final visualization = current.getById(id);
    if (visualization == null) return;

    updateVisualization(visualization.copyWith(style: style));
  }

  /// Reorder visualizations.
  void reorderVisualizations(int oldIndex, int newIndex) {
    final current = activeState;
    if (current == null) return;

    if (oldIndex < 0 || oldIndex >= current.visualizations.length) return;
    if (newIndex < 0 || newIndex > current.visualizations.length) return;

    final newVisualizations = List<VisualizationConfig>.from(current.visualizations);
    final item = newVisualizations.removeAt(oldIndex);

    // Adjust index if moving down
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newVisualizations.insert(adjustedIndex, item);

    // Update position field on all visualizations to reflect new order
    final updatedVisualizations = <VisualizationConfig>[];
    for (var i = 0; i < newVisualizations.length; i++) {
      updatedVisualizations.add(newVisualizations[i].copyWith(position: i));
    }

    emit(current.copyWith(
      visualizations: updatedVisualizations,
      isDirty: true,
    ));
  }

  /// Select a visualization for editing.
  void selectVisualization(String? id) {
    final current = activeState;
    if (current == null) return;

    if (id == null) {
      emit(current.copyWith(clearSelectedId: true));
    } else {
      emit(current.copyWith(selectedId: id));
    }
  }

  /// Clear selection.
  void clearSelection() {
    selectVisualization(null);
  }

  /// Set all visualizations (bulk update).
  void setVisualizations(List<VisualizationConfig> visualizations) {
    final current = activeState;
    if (current == null) {
      emit(ReportVisualizationActive(
        visualizations: visualizations,
        isDirty: true,
      ));
    } else {
      emit(current.copyWith(
        visualizations: visualizations,
        isDirty: true,
      ));
    }
  }

  /// Clear all visualizations.
  void clearVisualizations() {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(
      visualizations: const [],
      clearSelectedId: true,
      isDirty: true,
    ));
  }

  /// Mark state as clean (after save).
  void markClean() {
    final current = activeState;
    if (current == null) return;

    emit(current.copyWith(isDirty: false));
  }

  /// Reset to initial state.
  void reset() {
    emit(const ReportVisualizationActive(visualizations: []));
  }

  String _defaultTitle(VisualizationType type) {
    switch (type) {
      case VisualizationType.kpiCard:
        return 'KPI Card';
      case VisualizationType.lineChart:
        return 'Trend Chart';
      case VisualizationType.barChart:
        return 'Bar Chart';
      case VisualizationType.pieChart:
        return 'Distribution Chart';
      case VisualizationType.resultsTable:
        return 'Data Table';
    }
  }

  DataSourceConfig _defaultDataSource(VisualizationType type) {
    switch (type) {
      case VisualizationType.kpiCard:
        return const DataSourceConfig(metric: DataSourceMetric.totalCount);
      case VisualizationType.lineChart:
        return const DataSourceConfig(
          metric: DataSourceMetric.totalCount,
          groupBy: DataGroupBy.day,
        );
      case VisualizationType.barChart:
        return const DataSourceConfig(
          metric: DataSourceMetric.quantity,
          groupBy: DataGroupBy.site,
        );
      case VisualizationType.pieChart:
        return const DataSourceConfig(
          metric: DataSourceMetric.quantity,
          groupBy: DataGroupBy.healthStatus,
        );
      case VisualizationType.resultsTable:
        return const DataSourceConfig(metric: DataSourceMetric.totalCount);
    }
  }
}
