// @tier: community
import 'package:equatable/equatable.dart';

/// Predefined time range presets for reporting.
enum TimeRangePreset {
  last7Days('Last 7 Days', 7),
  last30Days('Last 30 Days', 30),
  last90Days('Last 90 Days', 90),
  last180Days('Last 180 Days', 180),
  last365Days('Last Year', 365),
  yearToDate('Year to Date', 0),
  quarterToDate('Quarter to Date', 0),
  monthToDate('Month to Date', 0),
  custom('Custom Range', 0);

  const TimeRangePreset(this.displayName, this.days);

  final String displayName;
  final int days;

  /// Calculate date range for this preset from a reference date.
  ///
  /// Uses calendar-aware date arithmetic to avoid DST boundary issues.
  ({DateTime start, DateTime end}) calculateRange([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (this) {
      case TimeRangePreset.last7Days:
      case TimeRangePreset.last30Days:
      case TimeRangePreset.last90Days:
      case TimeRangePreset.last180Days:
      case TimeRangePreset.last365Days:
        // Use Duration-based subtraction which properly handles month boundaries
        final start = DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: days - 1));
        return (start: start, end: today);
      case TimeRangePreset.yearToDate:
        return (start: DateTime(now.year, 1, 1), end: today);
      case TimeRangePreset.quarterToDate:
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return (start: DateTime(now.year, quarterMonth, 1), end: today);
      case TimeRangePreset.monthToDate:
        return (start: DateTime(now.year, now.month, 1), end: today);
      case TimeRangePreset.custom:
        return (start: today.subtract(const Duration(days: 30)), end: today);
    }
  }
}

/// Configuration for report time range with optional comparison period.
class TimeRangeConfig extends Equatable {
  const TimeRangeConfig({
    required this.preset,
    this.customStart,
    this.customEnd,
    this.comparisonEnabled = false,
    this.comparisonPreset,
    this.comparisonCustomStart,
    this.comparisonCustomEnd,
  });

  /// Create with last 30 days preset.
  const TimeRangeConfig.last30Days()
      : preset = TimeRangePreset.last30Days,
        customStart = null,
        customEnd = null,
        comparisonEnabled = false,
        comparisonPreset = null,
        comparisonCustomStart = null,
        comparisonCustomEnd = null;

  /// Create with last 90 days preset.
  const TimeRangeConfig.last90Days()
      : preset = TimeRangePreset.last90Days,
        customStart = null,
        customEnd = null,
        comparisonEnabled = false,
        comparisonPreset = null,
        comparisonCustomStart = null,
        comparisonCustomEnd = null;

  /// Create with year to date preset.
  const TimeRangeConfig.yearToDate()
      : preset = TimeRangePreset.yearToDate,
        customStart = null,
        customEnd = null,
        comparisonEnabled = false,
        comparisonPreset = null,
        comparisonCustomStart = null,
        comparisonCustomEnd = null;

  /// Create custom range.
  const TimeRangeConfig.custom({
    required DateTime start,
    required DateTime end,
  })  : preset = TimeRangePreset.custom,
        customStart = start,
        customEnd = end,
        comparisonEnabled = false,
        comparisonPreset = null,
        comparisonCustomStart = null,
        comparisonCustomEnd = null;

  final TimeRangePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  /// Whether comparison to a previous period is enabled (Pro feature).
  final bool comparisonEnabled;
  final TimeRangePreset? comparisonPreset;
  final DateTime? comparisonCustomStart;
  final DateTime? comparisonCustomEnd;

  /// Get the effective start date for the primary period.
  DateTime get startDate {
    if (preset == TimeRangePreset.custom && customStart != null) {
      return customStart!;
    }
    return preset.calculateRange().start;
  }

  /// Get the effective end date for the primary period.
  DateTime get endDate {
    if (preset == TimeRangePreset.custom && customEnd != null) {
      return customEnd!;
    }
    return preset.calculateRange().end;
  }

  /// Get the comparison period start date if enabled.
  DateTime? get comparisonStartDate {
    if (!comparisonEnabled) return null;
    if (comparisonPreset == TimeRangePreset.custom &&
        comparisonCustomStart != null) {
      return comparisonCustomStart;
    }
    return comparisonPreset?.calculateRange().start ?? _defaultComparisonStart;
  }

  /// Get the comparison period end date if enabled.
  DateTime? get comparisonEndDate {
    if (!comparisonEnabled) return null;
    if (comparisonPreset == TimeRangePreset.custom &&
        comparisonCustomEnd != null) {
      return comparisonCustomEnd;
    }
    return comparisonPreset?.calculateRange().end ?? _defaultComparisonEnd;
  }

  /// Default comparison is previous period of same length, immediately adjacent.
  ///
  /// For a 7-day primary period (Jan 8-14), comparison is Jan 1-7.
  DateTime get _defaultComparisonStart {
    final dayCount = endDate.difference(startDate).inDays + 1;
    // Use calendar-aware subtraction for DST safety
    return DateTime(startDate.year, startDate.month, startDate.day - dayCount);
  }

  DateTime get _defaultComparisonEnd {
    // End of comparison is day before primary start
    return DateTime(
      startDate.year,
      startDate.month,
      startDate.day - 1,
      23,
      59,
      59,
    );
  }

  /// Display label for the time range.
  String get displayLabel {
    if (preset == TimeRangePreset.custom) {
      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);
      return '$startStr - $endStr';
    }
    return preset.displayName;
  }

  /// Number of days in the primary range.
  int get dayCount => endDate.difference(startDate).inDays + 1;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  TimeRangeConfig copyWith({
    TimeRangePreset? preset,
    DateTime? customStart,
    DateTime? customEnd,
    bool? comparisonEnabled,
    TimeRangePreset? comparisonPreset,
    DateTime? comparisonCustomStart,
    DateTime? comparisonCustomEnd,
  }) {
    return TimeRangeConfig(
      preset: preset ?? this.preset,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      comparisonEnabled: comparisonEnabled ?? this.comparisonEnabled,
      comparisonPreset: comparisonPreset ?? this.comparisonPreset,
      comparisonCustomStart:
          comparisonCustomStart ?? this.comparisonCustomStart,
      comparisonCustomEnd: comparisonCustomEnd ?? this.comparisonCustomEnd,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preset': preset.name,
      if (customStart != null) 'customStart': customStart!.toIso8601String(),
      if (customEnd != null) 'customEnd': customEnd!.toIso8601String(),
      'comparisonEnabled': comparisonEnabled,
      if (comparisonPreset != null) 'comparisonPreset': comparisonPreset!.name,
      if (comparisonCustomStart != null)
        'comparisonCustomStart': comparisonCustomStart!.toIso8601String(),
      if (comparisonCustomEnd != null)
        'comparisonCustomEnd': comparisonCustomEnd!.toIso8601String(),
    };
  }

  factory TimeRangeConfig.fromJson(Map<String, dynamic> json) {
    return TimeRangeConfig(
      preset: TimeRangePreset.values.firstWhere(
        (p) => p.name == json['preset'],
        orElse: () => TimeRangePreset.last30Days,
      ),
      customStart: json['customStart'] != null
          ? DateTime.parse(json['customStart'] as String)
          : null,
      customEnd: json['customEnd'] != null
          ? DateTime.parse(json['customEnd'] as String)
          : null,
      comparisonEnabled: json['comparisonEnabled'] as bool? ?? false,
      comparisonPreset: json['comparisonPreset'] != null
          ? TimeRangePreset.values.firstWhere(
              (p) => p.name == json['comparisonPreset'],
              orElse: () => TimeRangePreset.last30Days,
            )
          : null,
      comparisonCustomStart: json['comparisonCustomStart'] != null
          ? DateTime.parse(json['comparisonCustomStart'] as String)
          : null,
      comparisonCustomEnd: json['comparisonCustomEnd'] != null
          ? DateTime.parse(json['comparisonCustomEnd'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        preset,
        customStart,
        customEnd,
        comparisonEnabled,
        comparisonPreset,
        comparisonCustomStart,
        comparisonCustomEnd,
      ];
}
