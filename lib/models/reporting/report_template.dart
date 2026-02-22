// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/reporting/filter_config.dart';
import 'package:seafoundry_app/models/reporting/report_icon_registry.dart';
import 'package:seafoundry_app/models/reporting/time_range_config.dart';
import 'package:seafoundry_app/models/reporting/visualization_config.dart';
import 'package:seafoundry_app/services/tier.dart';

/// Template category for organization.
enum ReportTemplateCategory {
  inventory('Inventory', Icons.inventory_2),
  health('Health & Monitoring', Icons.health_and_safety),
  outplanting('Outplanting', Icons.nature),
  production('Production', Icons.factory),
  custom('Custom', Icons.tune);

  const ReportTemplateCategory(this.displayName, this.icon);

  final String displayName;
  final IconData icon;
}

/// A report template defining default configuration for a report type.
class ReportTemplate extends Equatable {
  const ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
    required this.defaultTimeRange,
    required this.defaultVisualizations,
    this.iconName,
    this.defaultFilters = const FilterConfig(),
    this.isBuiltIn = true,
  });

  /// Unique template identifier.
  final String id;

  /// Display name.
  final String name;

  /// Description of what this template reports on.
  final String description;

  /// Category for organization.
  final ReportTemplateCategory category;

  /// Minimum tier required.
  final Tier tier;

  /// Optional icon name override (from ReportIconRegistry).
  final String? iconName;

  /// Default time range when using this template.
  final TimeRangeConfig defaultTimeRange;

  /// Default filters when using this template.
  final FilterConfig defaultFilters;

  /// Default visualizations included in this template.
  final List<VisualizationConfig> defaultVisualizations;

  /// Whether this is a built-in template (vs user-created).
  final bool isBuiltIn;

  /// Optional icon override (from registry).
  IconData? get icon => ReportIconRegistry.get(iconName);

  /// Icon to display (from category if not overridden).
  IconData get displayIcon => icon ?? category.icon;

  /// Whether the template is accessible to a user tier.
  bool isAccessibleTo(Tier userTier) => tier.isAccessibleTo(userTier);

  ReportTemplate copyWith({
    String? id,
    String? name,
    String? description,
    ReportTemplateCategory? category,
    Tier? tier,
    String? iconName,
    TimeRangeConfig? defaultTimeRange,
    FilterConfig? defaultFilters,
    List<VisualizationConfig>? defaultVisualizations,
    bool? isBuiltIn,
  }) {
    return ReportTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      tier: tier ?? this.tier,
      iconName: iconName ?? this.iconName,
      defaultTimeRange: defaultTimeRange ?? this.defaultTimeRange,
      defaultFilters: defaultFilters ?? this.defaultFilters,
      defaultVisualizations:
          defaultVisualizations ?? this.defaultVisualizations,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'tier': tier.name,
      if (iconName != null) 'iconName': iconName,
      'defaultTimeRange': defaultTimeRange.toJson(),
      'defaultFilters': defaultFilters.toJson(),
      'defaultVisualizations':
          defaultVisualizations.map((v) => v.toJson()).toList(),
      'isBuiltIn': isBuiltIn,
    };
  }

  factory ReportTemplate.fromJson(Map<String, dynamic> json) {
    return ReportTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Template',
      description: json['description'] as String? ?? '',
      category: ReportTemplateCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ReportTemplateCategory.custom,
      ),
      tier: Tier.fromString(json['tier'] as String?),
      iconName: json['iconName'] as String?,
      defaultTimeRange: json['defaultTimeRange'] != null
          ? TimeRangeConfig.fromJson(
              json['defaultTimeRange'] as Map<String, dynamic>,
            )
          : const TimeRangeConfig.last30Days(),
      defaultFilters: json['defaultFilters'] != null
          ? FilterConfig.fromJson(json['defaultFilters'] as Map<String, dynamic>)
          : const FilterConfig(),
      defaultVisualizations: (json['defaultVisualizations'] as List?)
              ?.map(
                  (v) => VisualizationConfig.fromJson(v as Map<String, dynamic>))
              .toList() ??
          const [],
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        category,
        tier,
        iconName,
        defaultTimeRange,
        defaultFilters,
        defaultVisualizations,
        isBuiltIn,
      ];
}

/// Built-in report templates.
class BuiltInTemplates {
  BuiltInTemplates._();

  /// Monthly inventory summary template.
  static ReportTemplate get monthlySummary => ReportTemplate(
        id: 'monthly_summary',
        name: 'Monthly Summary',
        description:
            'Overview of nursery inventory for the past month including health status and production metrics.',
        category: ReportTemplateCategory.inventory,
        tier: Tier.community,
        iconName: 'calendar_month',
        defaultTimeRange: const TimeRangeConfig.last30Days(),
        defaultVisualizations: [
          const VisualizationConfig(
            id: 'kpi_total',
            type: VisualizationType.kpiCard,
            title: 'Total Organisms',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.totalCount,
            ),
            position: 0,
          ),
          const VisualizationConfig(
            id: 'kpi_healthy',
            type: VisualizationType.kpiCard,
            title: 'Healthy %',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.healthyPercentage,
            ),
            position: 1,
          ),
          const VisualizationConfig(
            id: 'kpi_ready',
            type: VisualizationType.kpiCard,
            title: 'Ready for Outplant',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.readyForOutplant,
            ),
            position: 2,
          ),
          const VisualizationConfig(
            id: 'health_pie',
            type: VisualizationType.pieChart,
            title: 'Health Distribution',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.quantity,
              groupBy: DataGroupBy.healthStatus,
            ),
            dimensions: VisualizationDimensions(width: 1, height: 1),
            position: 3,
          ),
          const VisualizationConfig(
            id: 'trend_line',
            type: VisualizationType.lineChart,
            title: 'Inventory Trend',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.totalCount,
              groupBy: DataGroupBy.day,
            ),
            dimensions: VisualizationDimensions(width: 2, height: 1),
            position: 4,
          ),
        ],
      );

  /// Quarterly health report template.
  static ReportTemplate get quarterlyHealth => ReportTemplate(
        id: 'quarterly_health',
        name: 'Quarterly Health Report',
        description:
            'Comprehensive health analysis for the past quarter with trend analysis and site comparisons.',
        category: ReportTemplateCategory.health,
        tier: Tier.community,
        iconName: 'medical_services',
        defaultTimeRange: const TimeRangeConfig(
          preset: TimeRangePreset.last90Days,
        ),
        defaultVisualizations: [
          const VisualizationConfig(
            id: 'kpi_healthy',
            type: VisualizationType.kpiCard,
            title: 'Healthy Organisms',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.healthyCount,
            ),
            position: 0,
          ),
          const VisualizationConfig(
            id: 'kpi_survival',
            type: VisualizationType.kpiCard,
            title: 'Survival Rate',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.survivalRate,
            ),
            position: 1,
          ),
          const VisualizationConfig(
            id: 'health_trend',
            type: VisualizationType.lineChart,
            title: 'Health Trend',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.healthyPercentage,
              groupBy: DataGroupBy.week,
            ),
            dimensions: VisualizationDimensions(width: 2, height: 1),
            position: 2,
          ),
          const VisualizationConfig(
            id: 'health_dist',
            type: VisualizationType.pieChart,
            title: 'Current Health Status',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.quantity,
              groupBy: DataGroupBy.healthStatus,
            ),
            position: 3,
          ),
        ],
      );

  /// Annual inventory report template.
  static ReportTemplate get annualInventory => ReportTemplate(
        id: 'annual_inventory',
        name: 'Annual Inventory Report',
        description:
            'Year-long inventory analysis with growth trends, species breakdown, and year-over-year comparison.',
        category: ReportTemplateCategory.inventory,
        tier: Tier.community,
        iconName: 'calendar_today',
        defaultTimeRange: const TimeRangeConfig.yearToDate(),
        defaultVisualizations: [
          const VisualizationConfig(
            id: 'kpi_total',
            type: VisualizationType.kpiCard,
            title: 'Total Inventory',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.totalCount,
            ),
            position: 0,
          ),
          const VisualizationConfig(
            id: 'kpi_genets',
            type: VisualizationType.kpiCard,
            title: 'Unique Genets',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.uniqueGenets,
            ),
            position: 1,
          ),
          const VisualizationConfig(
            id: 'growth_trend',
            type: VisualizationType.lineChart,
            title: 'Growth Over Year',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.totalCount,
              groupBy: DataGroupBy.month,
            ),
            dimensions: VisualizationDimensions(width: 2, height: 1),
            position: 2,
          ),
          const VisualizationConfig(
            id: 'species_pie',
            type: VisualizationType.pieChart,
            title: 'Species Distribution',
            dataSource: DataSourceConfig(
              metric: DataSourceMetric.quantity,
              groupBy: DataGroupBy.species,
            ),
            position: 3,
          ),
        ],
      );

  /// List of all built-in templates.
  static List<ReportTemplate> get all => [
        monthlySummary,
        quarterlyHealth,
        annualInventory,
      ];

  /// Get template by ID.
  static ReportTemplate? byId(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
