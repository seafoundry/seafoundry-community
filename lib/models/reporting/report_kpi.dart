// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/reporting/report_icon_registry.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Trend direction for KPI comparison.
enum KpiTrend {
  up,
  down,
  neutral;

  IconData get icon {
    switch (this) {
      case KpiTrend.up:
        return Icons.trending_up;
      case KpiTrend.down:
        return Icons.trending_down;
      case KpiTrend.neutral:
        return Icons.trending_flat;
    }
  }

  Color get color {
    switch (this) {
      case KpiTrend.up:
        return Colors.green;
      case KpiTrend.down:
        return Colors.red;
      case KpiTrend.neutral:
        return Colors.grey;
    }
  }
}

/// KPI data model for dashboard cards.
class ReportKpi extends Equatable {
  const ReportKpi({
    required this.id,
    required this.label,
    required this.value,
    this.unit,
    this.iconName,
    this.colorValue,
    this.trend,
    this.previousValue,
    this.changePercent,
    this.subtitle,
  });

  /// Unique identifier for the KPI.
  final String id;

  /// Display label (e.g., "Total Organisms").
  final String label;

  /// Primary value (numeric).
  final double value;

  /// Optional unit suffix (e.g., "%", "cm").
  final String? unit;

  /// Optional icon name for the KPI card (from ReportIconRegistry).
  final String? iconName;

  /// Optional color value for the KPI card.
  final int? colorValue;

  /// Optional icon for the KPI card (from registry).
  IconData? get icon => ReportIconRegistry.get(iconName);

  /// Optional color for the KPI card (derived from color value).
  Color? get color => colorValue != null ? Color(colorValue!) : null;

  /// Trend direction compared to previous period.
  final KpiTrend? trend;

  /// Value from previous period for comparison.
  final double? previousValue;

  /// Percentage change from previous period.
  final double? changePercent;

  /// Optional subtitle or context.
  final String? subtitle;

  /// Formatted value string.
  String get displayValue {
    if (value == value.truncate()) {
      return '${value.truncate()}${unit ?? ''}';
    }
    return '${value.toStringAsFixed(1)}${unit ?? ''}';
  }

  /// Formatted change string (e.g., "+12.5%").
  String? get displayChange {
    if (changePercent == null) return null;
    final sign = changePercent! >= 0 ? '+' : '';
    return '$sign${changePercent!.toStringAsFixed(1)}%';
  }

  /// Calculate trend from change percent.
  KpiTrend get effectiveTrend {
    if (trend != null) return trend!;
    if (changePercent == null) return KpiTrend.neutral;
    if (changePercent! > 0.5) return KpiTrend.up;
    if (changePercent! < -0.5) return KpiTrend.down;
    return KpiTrend.neutral;
  }

  ReportKpi copyWith({
    String? id,
    String? label,
    double? value,
    String? unit,
    String? iconName,
    int? colorValue,
    KpiTrend? trend,
    double? previousValue,
    double? changePercent,
    String? subtitle,
  }) {
    return ReportKpi(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      trend: trend ?? this.trend,
      previousValue: previousValue ?? this.previousValue,
      changePercent: changePercent ?? this.changePercent,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  /// Add comparison data from a previous period.
  ///
  /// Calculates percentage change from [previous] to current [value].
  /// Returns null for changePercent if [previous] is zero (undefined growth).
  ReportKpi withComparison(double previous) {
    double? change;
    if (previous != 0) {
      change = ((value - previous) / previous) * 100;
    }
    // When previous is 0, change is undefined (infinite growth or no change)
    // We leave changePercent as null to indicate this edge case
    return copyWith(
      previousValue: previous,
      changePercent: change,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'value': value,
      if (unit != null) 'unit': unit,
      if (iconName != null) 'iconName': iconName,
      if (colorValue != null) 'colorValue': colorValue,
      if (trend != null) 'trend': trend!.name,
      if (previousValue != null) 'previousValue': previousValue,
      if (changePercent != null) 'changePercent': changePercent,
      if (subtitle != null) 'subtitle': subtitle,
    };
  }

  factory ReportKpi.fromJson(Map<String, dynamic> json) {
    return ReportKpi(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Unknown',
      value: safeDouble(json['value']) ?? 0.0,
      unit: json['unit'] as String?,
      iconName: json['iconName'] as String?,
      colorValue: safeInt(json['colorValue']),
      trend: json['trend'] != null
          ? KpiTrend.values.firstWhere(
              (t) => t.name == json['trend'],
              orElse: () => KpiTrend.neutral,
            )
          : null,
      previousValue: safeDouble(json['previousValue']),
      changePercent: safeDouble(json['changePercent']),
      subtitle: json['subtitle'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        value,
        unit,
        iconName,
        colorValue,
        trend,
        previousValue,
        changePercent,
        subtitle,
      ];
}

/// Predefined KPI templates for common metrics.
class ReportKpiTemplates {
  ReportKpiTemplates._();

  static ReportKpi totalOrganisms(int count, {int? recordCount}) {
    return ReportKpi(
      id: 'total_organisms',
      label: 'Total Organisms',
      value: count.toDouble(),
      iconName: 'eco',
      colorValue: Colors.green.toARGB32(),
      subtitle: recordCount == null ? null : 'Records: $recordCount',
    );
  }

  static ReportKpi healthyPercentage(double percent) {
    return ReportKpi(
      id: 'healthy_percentage',
      label: 'Healthy',
      value: percent,
      unit: '%',
      iconName: 'favorite',
      colorValue: Colors.green.toARGB32(),
    );
  }

  static ReportKpi readyForOutplant(int count, {int? recordCount}) {
    return ReportKpi(
      id: 'ready_for_outplant',
      label: 'Ready for Outplant',
      value: count.toDouble(),
      iconName: 'moving',
      colorValue: Colors.blue.toARGB32(),
      subtitle: recordCount == null ? null : 'Records: $recordCount',
    );
  }

  static ReportKpi uniqueGenets(int count) {
    return ReportKpi(
      id: 'unique_genets',
      label: 'Unique Genets',
      value: count.toDouble(),
      iconName: 'fingerprint',
      colorValue: Colors.purple.toARGB32(),
    );
  }

  static ReportKpi totalOutplanted(int count) {
    return ReportKpi(
      id: 'total_outplanted',
      label: 'Total Outplanted',
      value: count.toDouble(),
      iconName: 'nature',
      colorValue: Colors.teal.toARGB32(),
    );
  }

  static ReportKpi survivalRate(double percent) {
    return ReportKpi(
      id: 'survival_rate',
      label: 'Survival Rate',
      value: percent,
      unit: '%',
      iconName: 'health_and_safety',
      colorValue: Colors.amber.toARGB32(),
    );
  }
}
