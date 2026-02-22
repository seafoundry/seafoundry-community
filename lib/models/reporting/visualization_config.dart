// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Types of visualizations available in reports.
enum VisualizationType {
  kpiCard('KPI Card', Icons.dashboard),
  pieChart('Pie Chart', Icons.pie_chart),
  lineChart('Line Chart', Icons.show_chart),
  barChart('Bar Chart', Icons.bar_chart),
  resultsTable('Results Table', Icons.table_chart);

  const VisualizationType(this.displayName, this.icon);

  final String displayName;
  final IconData icon;

  /// Whether this visualization type is available in Community tier.
  /// Only the Results Table is free - all charts/visualizations are Pro.
  bool get isCommunityTier {
    switch (this) {
      case VisualizationType.resultsTable:
        return true;
      case VisualizationType.kpiCard:
      case VisualizationType.pieChart:
      case VisualizationType.lineChart:
      case VisualizationType.barChart:
        return false;
    }
  }
}

/// Data source configuration for a visualization.
enum DataSourceMetric {
  totalCount('Total Count', 'Sum of all organisms'),
  healthyCount('Healthy Count', 'Count of healthy organisms'),
  healthyPercentage('Healthy %', 'Percentage of healthy organisms'),
  readyForOutplant('Ready for Outplant', 'Count ready for outplanting'),
  quantity('Quantity', 'Total quantity by group'),
  uniqueGenets('Unique Genets', 'Count of unique genotypes'),
  survivalRate('Survival Rate', 'Survival percentage over time'),
  growthRate('Growth Rate', 'Growth trend over time');

  const DataSourceMetric(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Grouping options for aggregating data.
enum DataGroupBy {
  none('None', 'No grouping'),
  day('Day', 'Group by day'),
  week('Week', 'Group by week'),
  month('Month', 'Group by month'),
  site('Site', 'Group by site'),
  species('Species', 'Group by species'),
  genet('Genet', 'Group by genotype'),
  lifeStage('Life Stage', 'Group by life stage'),
  healthStatus('Health Status', 'Group by health status');

  const DataGroupBy(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Data source configuration for retrieving chart data.
class DataSourceConfig extends Equatable {
  const DataSourceConfig({
    required this.metric,
    this.groupBy = DataGroupBy.none,
    this.aggregation = 'sum',
    this.limit,
  });

  final DataSourceMetric metric;
  final DataGroupBy groupBy;
  final String aggregation; // sum, avg, count, min, max
  final int? limit; // For top N results

  DataSourceConfig copyWith({
    DataSourceMetric? metric,
    DataGroupBy? groupBy,
    String? aggregation,
    int? limit,
  }) {
    return DataSourceConfig(
      metric: metric ?? this.metric,
      groupBy: groupBy ?? this.groupBy,
      aggregation: aggregation ?? this.aggregation,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metric': metric.name,
      'groupBy': groupBy.name,
      'aggregation': aggregation,
      if (limit != null) 'limit': limit,
    };
  }

  factory DataSourceConfig.fromJson(Map<String, dynamic> json) {
    return DataSourceConfig(
      metric: DataSourceMetric.values.firstWhere(
        (m) => m.name == json['metric'],
        orElse: () => DataSourceMetric.totalCount,
      ),
      groupBy: DataGroupBy.values.firstWhere(
        (g) => g.name == json['groupBy'],
        orElse: () => DataGroupBy.none,
      ),
      aggregation: json['aggregation'] as String? ?? 'sum',
      limit: safeInt(json['limit']),
    );
  }

  @override
  List<Object?> get props => [metric, groupBy, aggregation, limit];
}

/// Dimensions for visualization layout in the grid.
class VisualizationDimensions extends Equatable {
  const VisualizationDimensions({
    this.width = 1,
    this.height = 1,
  });

  /// Width in grid units (1 = single column, 2 = double width).
  final int width;

  /// Height in grid units (1 = single row, 2 = double height).
  final int height;

  VisualizationDimensions copyWith({int? width, int? height}) {
    return VisualizationDimensions(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {'width': width, 'height': height};

  factory VisualizationDimensions.fromJson(Map<String, dynamic> json) {
    return VisualizationDimensions(
      width: safeInt(json['width']) ?? 1,
      height: safeInt(json['height']) ?? 1,
    );
  }

  @override
  List<Object?> get props => [width, height];
}

/// Style configuration for visualizations.
class VisualizationStyle extends Equatable {
  const VisualizationStyle({
    this.primaryColor,
    this.showDots = true,
    this.showLegend = true,
    this.showLabels = true,
    this.animated = true,
  });

  /// Primary color for the chart (hex string).
  final String? primaryColor;

  /// Whether to show dots on line charts.
  final bool showDots;

  /// Whether to show legend.
  final bool showLegend;

  /// Whether to show value labels.
  final bool showLabels;

  /// Whether to animate the chart.
  final bool animated;

  Color? get primaryColorValue {
    if (primaryColor == null) return null;
    try {
      final hex = primaryColor!.replaceFirst('#', '');
      if (hex.length != 6) return null;
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null; // Return null for invalid hex strings
    }
  }

  VisualizationStyle copyWith({
    String? primaryColor,
    bool? showDots,
    bool? showLegend,
    bool? showLabels,
    bool? animated,
  }) {
    return VisualizationStyle(
      primaryColor: primaryColor ?? this.primaryColor,
      showDots: showDots ?? this.showDots,
      showLegend: showLegend ?? this.showLegend,
      showLabels: showLabels ?? this.showLabels,
      animated: animated ?? this.animated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (primaryColor != null) 'primaryColor': primaryColor,
      'showDots': showDots,
      'showLegend': showLegend,
      'showLabels': showLabels,
      'animated': animated,
    };
  }

  factory VisualizationStyle.fromJson(Map<String, dynamic> json) {
    return VisualizationStyle(
      primaryColor: json['primaryColor'] as String?,
      showDots: json['showDots'] as bool? ?? true,
      showLegend: json['showLegend'] as bool? ?? true,
      showLabels: json['showLabels'] as bool? ?? true,
      animated: json['animated'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props =>
      [primaryColor, showDots, showLegend, showLabels, animated];
}

/// Configuration for a single visualization in a report.
class VisualizationConfig extends Equatable {
  const VisualizationConfig({
    required this.id,
    required this.type,
    required this.title,
    required this.dataSource,
    this.subtitle,
    this.dimensions = const VisualizationDimensions(),
    this.style = const VisualizationStyle(),
    this.position = 0,
  });

  /// Unique identifier for this visualization.
  final String id;

  /// Type of visualization (kpi, pie, line, bar, table).
  final VisualizationType type;

  /// Display title for the visualization.
  final String title;

  /// Optional subtitle or description.
  final String? subtitle;

  /// Data source configuration.
  final DataSourceConfig dataSource;

  /// Layout dimensions in the grid.
  final VisualizationDimensions dimensions;

  /// Style configuration.
  final VisualizationStyle style;

  /// Position in the visualization grid (0-indexed).
  final int position;

  VisualizationConfig copyWith({
    String? id,
    VisualizationType? type,
    String? title,
    String? subtitle,
    DataSourceConfig? dataSource,
    VisualizationDimensions? dimensions,
    VisualizationStyle? style,
    int? position,
  }) {
    return VisualizationConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      dataSource: dataSource ?? this.dataSource,
      dimensions: dimensions ?? this.dimensions,
      style: style ?? this.style,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'dataSource': dataSource.toJson(),
      'dimensions': dimensions.toJson(),
      'style': style.toJson(),
      'position': position,
    };
  }

  factory VisualizationConfig.fromJson(Map<String, dynamic> json) {
    return VisualizationConfig(
      id: json['id'] as String? ?? '',
      type: VisualizationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => VisualizationType.kpiCard,
      ),
      title: json['title'] as String? ?? 'Untitled',
      subtitle: json['subtitle'] as String?,
      dataSource: json['dataSource'] != null
          ? DataSourceConfig.fromJson(json['dataSource'] as Map<String, dynamic>)
          : const DataSourceConfig(metric: DataSourceMetric.totalCount),
      dimensions: json['dimensions'] != null
          ? VisualizationDimensions.fromJson(
              json['dimensions'] as Map<String, dynamic>,
            )
          : const VisualizationDimensions(),
      style: json['style'] != null
          ? VisualizationStyle.fromJson(json['style'] as Map<String, dynamic>)
          : const VisualizationStyle(),
      position: safeInt(json['position']) ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, title, subtitle, dataSource, dimensions, style, position];
}
