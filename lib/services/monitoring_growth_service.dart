// @tier: community
import 'dart:math' as math;

import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/monitoring/monitoring_entry.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Derived analytics for a monitoring entry (size, volume, growth deltas).
class MonitoringEntryAnalytics {
  const MonitoringEntryAnalytics({
    required this.sizeClass,
    required this.sizeClassInferred,
    required this.estimatedVolumeMm3,
    required this.volumeEstimated,
    required this.growthDeltaMm3,
    required this.growthPercentChange,
    required this.growthPerDayMm3,
    required this.intervalDays,
  });

  /// XS/S/M/L/XL etc. (already normalized to uppercase).
  final String? sizeClass;

  /// True when the size class was inferred rather than explicitly provided.
  final bool sizeClassInferred;

  /// Estimated total colony volume in mm³.
  final double? estimatedVolumeMm3;

  /// True when the volume was derived heuristically.
  final bool volumeEstimated;

  /// Absolute growth delta (current - previous) in mm³.
  final double? growthDeltaMm3;

  /// Percent growth delta relative to previous volume (0-100+).
  final double? growthPercentChange;

  /// Average mm³ gained per day between current and previous measurements.
  final double? growthPerDayMm3;

  /// Interval between current and previous measurements in days (fractional).
  final double? intervalDays;

  MonitoringEntryAnalytics copyWith({
    String? sizeClass,
    bool? sizeClassInferred,
    double? estimatedVolumeMm3,
    bool? volumeEstimated,
    double? growthDeltaMm3,
    double? growthPercentChange,
    double? growthPerDayMm3,
    double? intervalDays,
  }) {
    return MonitoringEntryAnalytics(
      sizeClass: sizeClass ?? this.sizeClass,
      sizeClassInferred: sizeClassInferred ?? this.sizeClassInferred,
      estimatedVolumeMm3: estimatedVolumeMm3 ?? this.estimatedVolumeMm3,
      volumeEstimated: volumeEstimated ?? this.volumeEstimated,
      growthDeltaMm3: growthDeltaMm3 ?? this.growthDeltaMm3,
      growthPercentChange: growthPercentChange ?? this.growthPercentChange,
      growthPerDayMm3: growthPerDayMm3 ?? this.growthPerDayMm3,
      intervalDays: intervalDays ?? this.intervalDays,
    );
  }

  static const empty = MonitoringEntryAnalytics(
    sizeClass: null,
    sizeClassInferred: false,
    estimatedVolumeMm3: null,
    volumeEstimated: false,
    growthDeltaMm3: null,
    growthPercentChange: null,
    growthPerDayMm3: null,
    intervalDays: null,
  );
}

/// Helper value wrapping a numeric result with its inference status.
class _DerivedValue {
  const _DerivedValue({this.value, this.inferred = false});
  final double? value;
  final bool inferred;
}

/// Helper value wrapping a string result with its inference status.
class _DerivedString {
  const _DerivedString({this.value, this.inferred = false});
  final String? value;
  final bool inferred;
}

/// Represents a computed growth delta between two observations.
class _GrowthDelta {
  const _GrowthDelta({
    required this.deltaMm3,
    required this.percentChange,
    required this.perDayMm3,
    required this.intervalDays,
  });

  final double? deltaMm3;
  final double? percentChange;
  final double? perDayMm3;
  final double? intervalDays;
}

/// Heuristic analytics used by the monitoring spreadsheet to back-fill
/// size classification, volume estimates, and growth deltas when partner data
/// omits those derived metrics.
class MonitoringGrowthService {
  const MonitoringGrowthService();

  MonitoringEntryAnalytics analyzeEntry({
    required MonitoringEventRecord currentEvent,
    required MonitoringEntry entry,
    MonitoringEventRecord? previousEvent,
    MonitoringEntry? previousEntry,
  }) {
    final combinedMeasurements = _combinedMeasurements(
      event: currentEvent,
      entry: entry,
    );
    final resolvedLifeStage = _lifeStageFromMeasurements(combinedMeasurements);

    final classification = _deriveSizeClass(
      combinedMeasurements,
      lifeStage: resolvedLifeStage,
    );
    final volumeResult = _estimateVolume(
      combinedMeasurements,
      sizeClass: classification?.value,
      lifeStage: resolvedLifeStage,
    );

    final prevMeasurements = previousEvent != null && previousEntry != null
        ? _combinedMeasurements(event: previousEvent, entry: previousEntry)
        : null;
    final prevVolumeResult = prevMeasurements != null
        ? _estimateVolume(
            prevMeasurements,
            sizeClass: classification?.value,
            lifeStage: resolvedLifeStage,
          )
        : null;

    final growth = _computeGrowth(
      currentEvent: currentEvent,
      previousEvent: previousEvent,
      currentVolume: volumeResult.value,
      previousVolume: prevVolumeResult?.value,
    );

    return MonitoringEntryAnalytics(
      sizeClass: classification?.value,
      sizeClassInferred: classification?.inferred ?? false,
      estimatedVolumeMm3: volumeResult.value,
      volumeEstimated: volumeResult.inferred,
      growthDeltaMm3: growth.deltaMm3,
      growthPercentChange: growth.percentChange,
      growthPerDayMm3: growth.perDayMm3,
      intervalDays: growth.intervalDays,
    );
  }

  Map<String, dynamic> _combinedMeasurements({
    required MonitoringEventRecord event,
    required MonitoringEntry entry,
  }) {
    final combined = <String, dynamic>{};
    if (event.measurements != null) {
      combined.addAll(event.measurements!);
    }
    if (entry.measurements != null) {
      combined.addAll(entry.measurements!);
    }
    return combined;
  }

  LifeStage? _lifeStageFromMeasurements(Map<String, dynamic> measurements) {
    final raw = _stringForKeys(
      measurements,
      const ['lifeStageId', 'life_stage_id', 'lifeStage', 'life_stage'],
    );
    return LifeStageX.tryParse(raw);
  }

  _DerivedString? _deriveSizeClass(
    Map<String, dynamic> measurements, {
    LifeStage? lifeStage,
  }) {
    final raw = _stringForKeys(measurements, const [
      'sizeClass',
      'size_class',
      'sizeClassification',
      'size_classification',
      'sizeBandId',
      'size_band_id',
      'size',
    ]);
    if (raw != null) {
      final normalized = _normalizeSizeClass(raw);
      if (normalized != null) {
        return _DerivedString(value: normalized, inferred: false);
      }
    }

    if (_isEarlyLifeStage(lifeStage)) {
      return null;
    }

    final largestDimension = _largestDimensionMm(measurements);
    if (largestDimension != null) {
      return _DerivedString(
        value: _classifyFromDimension(largestDimension),
        inferred: true,
      );
    }

    final volume = _existingVolume(measurements);
    if (volume != null) {
      return _DerivedString(value: _classifyFromVolume(volume), inferred: true);
    }

    return null;
  }

  _DerivedValue _estimateVolume(
    Map<String, dynamic> measurements, {
    String? sizeClass,
    LifeStage? lifeStage,
  }) {
    final existing = _existingVolume(measurements);
    if (existing != null) {
      return _DerivedValue(value: existing, inferred: false);
    }

    if (_isEarlyLifeStage(lifeStage)) {
      return const _DerivedValue(value: null, inferred: false);
    }

    final dimensions = _Dimensions.fromMeasurements(measurements);
    double? computed;
    if (dimensions.hasAllThree) {
      // Treat as ellipsoid (length × width × height × π/6).
      computed =
          dimensions.lengthMm! *
          dimensions.widthMm! *
          dimensions.heightMm! *
          (math.pi / 6.0);
    } else if (dimensions.lengthMm != null &&
        dimensions.widthMm != null &&
        dimensions.heightMm != null) {
      computed =
          dimensions.lengthMm! *
          dimensions.widthMm! *
          dimensions.heightMm! *
          0.5;
    } else if (dimensions.diameterMm != null && dimensions.heightMm != null) {
      final radius = dimensions.diameterMm! / 2;
      computed = math.pi * radius * radius * dimensions.heightMm!;
    } else if (dimensions.diameterMm != null) {
      final radius = dimensions.diameterMm! / 2;
      computed = (4 / 3) * math.pi * math.pow(radius, 3).toDouble();
    } else if (dimensions.lengthMm != null) {
      computed =
          math
              .pow(dimensions.lengthMm!.clamp(0, double.infinity), 3)
              .toDouble() *
          0.3;
    }

    if (computed != null && computed.isFinite) {
      return _DerivedValue(value: computed, inferred: true);
    }

    if (sizeClass != null) {
      // Resolve physical form ID from measurements.
      final physicalFormId = _stringForKeys(measurements, const [
        'physicalFormId',
        'physical_form_id',
      ]);
      if (physicalFormId != null) {
        // Volume lookup from size mappings requires SizeMetricsResolver
        // which is not available in this stateless context. Log for tracing.
        LoggingService.instance.debug(
          'MonitoringGrowthService: no resolver for volume lookup',
          {'physicalFormId': physicalFormId, 'sizeClass': sizeClass},
        );
      }
    }

    return const _DerivedValue(value: null, inferred: false);
  }

  _GrowthDelta _computeGrowth({
    required MonitoringEventRecord currentEvent,
    required MonitoringEventRecord? previousEvent,
    required double? currentVolume,
    required double? previousVolume,
  }) {
    if (currentVolume == null ||
        previousVolume == null ||
        previousEvent == null) {
      return const _GrowthDelta(
        deltaMm3: null,
        percentChange: null,
        perDayMm3: null,
        intervalDays: null,
      );
    }

    final currentDate = _eventDate(currentEvent);
    final previousDate = _eventDate(previousEvent);
    if (currentDate == null || previousDate == null) {
      return const _GrowthDelta(
        deltaMm3: null,
        percentChange: null,
        perDayMm3: null,
        intervalDays: null,
      );
    }

    final delta = currentVolume - previousVolume;
    final days = currentDate.difference(previousDate).inHours / 24.0;
    if (days <= 0) {
      return _GrowthDelta(
        deltaMm3: delta,
        percentChange: _percentChange(previousVolume, delta),
        perDayMm3: null,
        intervalDays: null,
      );
    }

    return _GrowthDelta(
      deltaMm3: delta,
      percentChange: _percentChange(previousVolume, delta),
      perDayMm3: delta / days,
      intervalDays: days,
    );
  }

  static double? _percentChange(double base, double delta) {
    if (base == 0) return null;
    return (delta / base) * 100;
  }

  static DateTime? _eventDate(MonitoringEventRecord event) {
    if (event.monitoringDate != null) {
      return event.monitoringDate;
    }
    try {
      return DateTime.parse(event.createdAt);
    } catch (e) {
      LoggingService.instance.debug(
        'Failed to parse event createdAt timestamp',
        {'createdAt': event.createdAt, 'error': e.toString()},
      );
      return null;
    }
  }

  static double? _existingVolume(Map<String, dynamic> measurements) {
    final mm3 = _doubleForKeys(measurements, const [
      'estimatedVolumeMm3',
      'estimated_volume_mm3',
      'volumeMm3',
      'volume_mm3',
      'volume',
    ]);
    if (mm3 != null) return mm3;

    final cm3 = _doubleForKeys(measurements, const [
      'estimatedVolumeCm3',
      'estimated_volume_cm3',
      'volume_cm3',
    ]);
    if (cm3 != null) return cm3 * 1000.0;

    return null;
  }

  static double? _largestDimensionMm(Map<String, dynamic> measurements) {
    final dimensions = _Dimensions.fromMeasurements(measurements);
    final candidates = <double>[
      if (dimensions.lengthMm != null) dimensions.lengthMm!,
      if (dimensions.widthMm != null) dimensions.widthMm!,
      if (dimensions.heightMm != null) dimensions.heightMm!,
      if (dimensions.diameterMm != null) dimensions.diameterMm!,
      if (dimensions.linearExtensionMm != null) dimensions.linearExtensionMm!,
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce(math.max);
  }

  static String? _normalizeSizeClass(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    const synonyms = {
      'extra small': 'XS',
      'xs': 'XS',
      'x-small': 'XS',
      'tiny': 'XS',
      'small': 'S',
      's': 'S',
      'medium': 'M',
      'm': 'M',
      'large': 'L',
      'l': 'L',
      'extra large': 'XL',
      'x-large': 'XL',
      'xl': 'XL',
      'xxl': 'XL',
    };

    if (synonyms.containsKey(lower)) {
      return synonyms[lower];
    }

    if (trimmed.length <= 3) {
      return trimmed.toUpperCase();
    }
    return trimmed;
  }

  static String _classifyFromDimension(double mm) {
    if (mm < 25) return 'XS';
    if (mm < 60) return 'S';
    if (mm < 120) return 'M';
    if (mm < 220) return 'L';
    return 'XL';
  }

  static String _classifyFromVolume(double mm3) {
    if (mm3 < 2_000) return 'XS';
    if (mm3 < 10_000) return 'S';
    if (mm3 < 40_000) return 'M';
    if (mm3 < 120_000) return 'L';
    return 'XL';
  }

  bool _isEarlyLifeStage(LifeStage? lifeStage) {
    if (lifeStage == null) {
      return false;
    }
    return lifeStage == LifeStage.gamete || lifeStage == LifeStage.embryo;
  }

  static String? _stringForKeys(
    Map<String, dynamic> measurements,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = measurements[key];
      if (value == null) continue;
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static double? _doubleForKeys(
    Map<String, dynamic> measurements,
    List<String> keys, {
    double multiplier = 1,
  }) {
    for (final key in keys) {
      final value = measurements[key];
      final parsed = _toDouble(value);
      if (parsed != null) {
        return parsed * multiplier;
      }
    }
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }
}

class _Dimensions {
  const _Dimensions({
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.diameterMm,
    this.linearExtensionMm,
  });

  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final double? diameterMm;
  final double? linearExtensionMm;

  bool get hasAllThree =>
      lengthMm != null && widthMm != null && heightMm != null;

  static _Dimensions fromMeasurements(Map<String, dynamic> measurements) {
    double? readMm(List<String> keys) =>
        MonitoringGrowthService._doubleForKeys(measurements, keys);

    double? readCm(List<String> keys) => MonitoringGrowthService._doubleForKeys(
          measurements,
          keys,
          multiplier: 10,
        );

    double? readMeters(List<String> keys) =>
        MonitoringGrowthService._doubleForKeys(
          measurements,
          keys,
          multiplier: 1000,
        );

    return _Dimensions(
      lengthMm: readMm(const [
            'lengthMm',
            'length_mm',
            'length',
            'maxLengthMm',
            'max_length_mm',
            'bladeLengthMm',
            'blade_length_mm',
            'bladeLength',
            'blade_length',
            'stipeLengthMm',
            'stipe_length_mm',
          ]) ??
          readCm(const [
            'lengthCm',
            'length_cm',
            'max_length_cm',
            'bladeLengthCm',
            'blade_length_cm',
            'stipeLengthCm',
            'stipe_length_cm',
          ]) ??
          readMeters(const [
            'lengthM',
            'length_m',
            'bladeLengthM',
            'bladeLength_m',
            'blade_length_m',
          ]),
      widthMm: readMm(const [
            'widthMm',
            'width_mm',
            'width',
            'maxWidthMm',
            'max_width_mm',
          ]) ??
          readCm(const ['widthCm', 'width_cm', 'max_width_cm']),
      heightMm: readMm(const [
            'heightMm',
            'height_mm',
            'height',
            'thicknessMm',
            'thickness_mm',
            'shellHeightMm',
            'shellHeight_mm',
            'shell_height_mm',
            'shellHeight',
            'shell_height',
          ]) ??
          readCm(const [
            'heightCm',
            'height_cm',
            'thickness_cm',
            'shellHeightCm',
            'shell_height_cm',
          ]),
      diameterMm: readMm(const [
            'diameterMm',
            'diameter_mm',
            'diameter',
            'averageDiameterMm',
            'avgDiameterMm',
          ]) ??
          readCm(const [
            'diameterCm',
            'diameter_cm',
            'average_diameter_cm',
            'crownDiameterCm',
            'crown_diameter_cm',
          ]),
      linearExtensionMm: readMm(const [
            'linearExtensionMm',
            'linear_extension_mm',
            'linearExtension',
            'extensionMm',
          ]) ??
          readCm(const ['linearExtensionCm', 'linear_extension_cm']),
    );
  }
}
