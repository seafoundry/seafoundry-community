// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/reporting/visualization_config.dart';

/// State for report visualization management.
sealed class ReportVisualizationState extends Equatable {
  const ReportVisualizationState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any visualizations are configured.
final class ReportVisualizationInitial extends ReportVisualizationState {
  const ReportVisualizationInitial();
}

/// State with active visualization configurations.
final class ReportVisualizationActive extends ReportVisualizationState {
  const ReportVisualizationActive({
    required this.visualizations,
    this.selectedId,
    this.isDirty = false,
  });

  /// List of visualization configurations.
  final List<VisualizationConfig> visualizations;

  /// Currently selected visualization ID for editing.
  final String? selectedId;

  /// Whether there are unsaved changes.
  final bool isDirty;

  /// Get the currently selected visualization.
  VisualizationConfig? get selectedVisualization {
    if (selectedId == null) return null;
    return visualizations.where((v) => v.id == selectedId).firstOrNull;
  }

  /// Get visualization by ID.
  VisualizationConfig? getById(String id) {
    return visualizations.where((v) => v.id == id).firstOrNull;
  }

  ReportVisualizationActive copyWith({
    List<VisualizationConfig>? visualizations,
    String? selectedId,
    bool clearSelectedId = false,
    bool? isDirty,
  }) {
    return ReportVisualizationActive(
      visualizations: visualizations ?? this.visualizations,
      selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [visualizations, selectedId, isDirty];
}
