// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/reporting/filter_config.dart';
import 'package:seafoundry_app/models/reporting/time_range_config.dart';
import 'package:seafoundry_app/models/reporting/visualization_config.dart';

/// Export settings for report output.
class ExportSettings extends Equatable {
  const ExportSettings({
    this.includeCsvData = true,
    this.includeChartConfig = true,
    this.includeMetadata = true,
    this.csvFileName,
    this.jsonFileName,
  });

  final bool includeCsvData;
  final bool includeChartConfig;
  final bool includeMetadata;
  final String? csvFileName;
  final String? jsonFileName;

  ExportSettings copyWith({
    bool? includeCsvData,
    bool? includeChartConfig,
    bool? includeMetadata,
    String? csvFileName,
    String? jsonFileName,
  }) {
    return ExportSettings(
      includeCsvData: includeCsvData ?? this.includeCsvData,
      includeChartConfig: includeChartConfig ?? this.includeChartConfig,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      csvFileName: csvFileName ?? this.csvFileName,
      jsonFileName: jsonFileName ?? this.jsonFileName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'includeCsvData': includeCsvData,
      'includeChartConfig': includeChartConfig,
      'includeMetadata': includeMetadata,
      if (csvFileName != null) 'csvFileName': csvFileName,
      if (jsonFileName != null) 'jsonFileName': jsonFileName,
    };
  }

  factory ExportSettings.fromJson(Map<String, dynamic> json) {
    return ExportSettings(
      includeCsvData: json['includeCsvData'] as bool? ?? true,
      includeChartConfig: json['includeChartConfig'] as bool? ?? true,
      includeMetadata: json['includeMetadata'] as bool? ?? true,
      csvFileName: json['csvFileName'] as String?,
      jsonFileName: json['jsonFileName'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        includeCsvData,
        includeChartConfig,
        includeMetadata,
        csvFileName,
        jsonFileName,
      ];
}

/// Complete report configuration including template, filters, and visualizations.
///
/// This is the main model for saved report configurations.
class ReportConfiguration extends Equatable {
  const ReportConfiguration({
    required this.id,
    required this.name,
    required this.timeRange,
    required this.filters,
    required this.visualizations,
    this.templateId,
    this.description,
    this.exportSettings = const ExportSettings(),
    this.organizationId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  /// Unique configuration identifier.
  final String id;

  /// User-defined name for this configuration.
  final String name;

  /// Optional description.
  final String? description;

  /// Template this was created from (if any).
  final String? templateId;

  /// Time range configuration.
  final TimeRangeConfig timeRange;

  /// Filter configuration.
  final FilterConfig filters;

  /// Visualization configurations.
  final List<VisualizationConfig> visualizations;

  /// Export settings.
  final ExportSettings exportSettings;

  /// Organization this belongs to.
  final String? organizationId;

  /// User who created this configuration.
  final String? createdBy;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// Count of visualizations by type.
  Map<VisualizationType, int> get visualizationCounts {
    final counts = <VisualizationType, int>{};
    for (final viz in visualizations) {
      counts[viz.type] = (counts[viz.type] ?? 0) + 1;
    }
    return counts;
  }

  /// KPI card count.
  int get kpiCount => visualizationCounts[VisualizationType.kpiCard] ?? 0;

  /// Chart count (pie + line + bar).
  int get chartCount =>
      (visualizationCounts[VisualizationType.pieChart] ?? 0) +
      (visualizationCounts[VisualizationType.lineChart] ?? 0) +
      (visualizationCounts[VisualizationType.barChart] ?? 0);

  /// Create from a template with optional overrides.
  factory ReportConfiguration.fromTemplate({
    required String id,
    required String name,
    required String templateId,
    required TimeRangeConfig defaultTimeRange,
    required FilterConfig defaultFilters,
    required List<VisualizationConfig> defaultVisualizations,
    String? organizationId,
    String? createdBy,
  }) {
    return ReportConfiguration(
      id: id,
      name: name,
      templateId: templateId,
      timeRange: defaultTimeRange,
      filters: defaultFilters,
      visualizations: defaultVisualizations,
      organizationId: organizationId,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a blank configuration.
  factory ReportConfiguration.blank({
    required String id,
    required String name,
    String? organizationId,
    String? createdBy,
  }) {
    return ReportConfiguration(
      id: id,
      name: name,
      timeRange: const TimeRangeConfig.last30Days(),
      filters: const FilterConfig(),
      visualizations: const [],
      organizationId: organizationId,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  ReportConfiguration copyWith({
    String? id,
    String? name,
    String? description,
    String? templateId,
    TimeRangeConfig? timeRange,
    FilterConfig? filters,
    List<VisualizationConfig>? visualizations,
    ExportSettings? exportSettings,
    String? organizationId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ReportConfiguration(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      templateId: templateId ?? this.templateId,
      timeRange: timeRange ?? this.timeRange,
      filters: filters ?? this.filters,
      visualizations: visualizations ?? this.visualizations,
      exportSettings: exportSettings ?? this.exportSettings,
      organizationId: organizationId ?? this.organizationId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  /// Add a visualization.
  ReportConfiguration addVisualization(VisualizationConfig viz) {
    return copyWith(
      visualizations: [...visualizations, viz.copyWith(position: visualizations.length)],
    );
  }

  /// Remove a visualization by ID.
  ReportConfiguration removeVisualization(String vizId) {
    final newList = visualizations.where((v) => v.id != vizId).toList();
    // Reindex positions
    final reindexed = newList.asMap().entries.map(
      (e) => e.value.copyWith(position: e.key),
    ).toList();
    return copyWith(visualizations: reindexed);
  }

  /// Update a visualization.
  ReportConfiguration updateVisualization(VisualizationConfig viz) {
    final newList = visualizations.map((v) => v.id == viz.id ? viz : v).toList();
    return copyWith(visualizations: newList);
  }

  /// Reorder visualizations.
  ///
  /// Moves the visualization at [oldIndex] to [newIndex].
  /// Uses Flutter ReorderableListView semantics where newIndex is adjusted
  /// when moving items downward.
  ///
  /// Returns unchanged configuration if indices are out of bounds.
  ReportConfiguration reorderVisualizations(int oldIndex, int newIndex) {
    // Validate indices
    if (oldIndex < 0 ||
        oldIndex >= visualizations.length ||
        newIndex < 0 ||
        newIndex > visualizations.length) {
      return this; // Return unchanged on invalid indices
    }

    // No-op if same position
    if (oldIndex == newIndex) return this;

    final newList = List<VisualizationConfig>.from(visualizations);
    final item = newList.removeAt(oldIndex);

    // Adjust newIndex for Flutter ReorderableListView semantics
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newList.insert(adjustedNewIndex.clamp(0, newList.length), item);

    // Reindex positions
    final reindexed = newList
        .asMap()
        .entries
        .map((e) => e.value.copyWith(position: e.key))
        .toList();
    return copyWith(visualizations: reindexed);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (templateId != null) 'templateId': templateId,
      'timeRange': timeRange.toJson(),
      'filters': filters.toJson(),
      'visualizations': visualizations.map((v) => v.toJson()).toList(),
      'exportSettings': exportSettings.toJson(),
      if (organizationId != null) 'organizationId': organizationId,
      if (createdBy != null) 'createdBy': createdBy,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  factory ReportConfiguration.fromJson(Map<String, dynamic> json) {
    return ReportConfiguration(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Report',
      description: json['description'] as String?,
      templateId: json['templateId'] as String?,
      timeRange: json['timeRange'] != null
          ? TimeRangeConfig.fromJson(json['timeRange'] as Map<String, dynamic>)
          : const TimeRangeConfig.last30Days(),
      filters: json['filters'] != null
          ? FilterConfig.fromJson(json['filters'] as Map<String, dynamic>)
          : const FilterConfig(),
      visualizations: (json['visualizations'] as List?)
              ?.map(
                  (v) => VisualizationConfig.fromJson(v as Map<String, dynamic>))
              .toList() ??
          const [],
      exportSettings: json['exportSettings'] != null
          ? ExportSettings.fromJson(
              json['exportSettings'] as Map<String, dynamic>)
          : const ExportSettings(),
      organizationId: json['organizationId'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        templateId,
        timeRange,
        filters,
        visualizations,
        exportSettings,
        organizationId,
        createdBy,
        createdAt,
        updatedAt,
        metadata,
      ];
}
