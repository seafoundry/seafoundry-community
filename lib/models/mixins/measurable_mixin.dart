import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Historical snapshot recording how a measurement or size specification
/// changed over time (e.g., grading, biomass sampling).
class MeasurementSnapshot extends Equatable {
  const MeasurementSnapshot({
    required this.measurement,
    this.sizeSpec = const SizeSpec(),
    this.recordedAt,
    this.source,
    this.notes,
  });

  factory MeasurementSnapshot.fromJson(Map<String, dynamic> json) {
    final measurementMap = safeMapCast(json['measurement']);
    final sizeSpecMap = safeMapCast(json['sizeSpec']);
    return MeasurementSnapshot(
      measurement: measurementMap != null
          ? PopulationMeasurement.fromJson(measurementMap)
          : _parseMeasurement(json['measurement']),
      sizeSpec: SizeSpec.fromJson(
        sizeSpecMap != null ? deepNormalizeMap(sizeSpecMap) : null,
      ),
      recordedAt: _parseDate(json['recordedAt']),
      source: json['source']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  final PopulationMeasurement measurement;
  final SizeSpec sizeSpec;
  final DateTime? recordedAt;
  final String? source;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'measurement': measurement.toJson(),
        if (!sizeSpec.isEmpty) 'sizeSpec': sizeSpec.toJson(),
        if (recordedAt != null) 'recordedAt': recordedAt!.toIso8601String(),
        if (source != null) 'source': source,
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => [
        measurement,
        sizeSpec,
        recordedAt,
        source,
        notes,
      ];
}

PopulationMeasurement _parseMeasurement(dynamic value) {
  if (value is Map) {
    return PopulationMeasurement.fromJson(deepNormalizeMap(value));
  }
  if (value is PopulationMeasurement) return value;
  final numeric = safeDouble(value) ?? 0;
  return PopulationMeasurement(value: numeric, unit: MeasurementUnit.count);
}

/// Shared helpers for models that expose canonical population measurements and
/// optional size metadata.
mixin MeasurableMixin {
  PopulationMeasurement get canonicalMeasurement;
  SizeSpec get measurementSizeSpec;
  List<MeasurementSnapshot> get measurementHistory;

  bool get hasMeasurement => canonicalMeasurement.value > 0;

  PopulationMeasurement measurementInUnit(MeasurementUnit unit) {
    final converted = _MeasurementConverter.convert(
      canonicalMeasurement.value,
      canonicalMeasurement.unit,
      unit,
    );
    if (converted == null) {
      throw ArgumentError(
        'Cannot convert ${canonicalMeasurement.unit.label} to ${unit.label}.',
      );
    }
    return PopulationMeasurement(value: converted, unit: unit);
  }

  PopulationMeasurement applyMeasurementDelta(
    double delta, {
    MeasurementUnit? deltaUnit,
  }) {
    final normalizedDelta = deltaUnit == null
        ? delta
        : _MeasurementConverter.convert(delta, deltaUnit, canonicalMeasurement.unit);
    if (normalizedDelta == null) {
      throw ArgumentError(
        'Cannot convert delta from ${deltaUnit!.label} to '
        '${canonicalMeasurement.unit.label}.',
      );
    }
    final updatedValue = (canonicalMeasurement.value + normalizedDelta)
        .clamp(0, double.infinity)
        .toDouble();
    return canonicalMeasurement.copyWith(value: updatedValue);
  }

  PopulationMeasurement scaleMeasurement(double multiplier) {
    final updatedValue = (canonicalMeasurement.value * multiplier)
        .clamp(0, double.infinity)
        .toDouble();
    return canonicalMeasurement.copyWith(value: updatedValue);
  }

  SizeSpec updateSizeSpec({
    String? sizeClass,
    double? measuredDimension,
    MeasurementUnit? dimensionUnit,
  }) {
    return measurementSizeSpec.copyWith(
      sizeClass: sizeClass,
      measuredDimension: measuredDimension,
      dimensionUnit: dimensionUnit,
    );
  }

  List<MeasurementSnapshot> appendMeasurementSnapshot({
    PopulationMeasurement? measurement,
    SizeSpec? sizeSpec,
    DateTime? recordedAt,
    String? source,
    String? notes,
  }) {
    return [
      ...measurementHistory,
      MeasurementSnapshot(
        measurement: measurement ?? canonicalMeasurement,
        sizeSpec: sizeSpec ?? measurementSizeSpec,
        recordedAt: recordedAt ?? DateTime.now().toUtc(),
        source: source,
        notes: notes,
      ),
    ];
  }
}

class _MeasurementConverter {
  static double? convert(
    double value,
    MeasurementUnit from,
    MeasurementUnit to,
  ) {
    if (from == to) return value;
    if (from.category != to.category) return null;

    switch (from.category) {
      case MeasurementUnitCategory.mass:
        final grams = from == MeasurementUnit.gram ? value : value * 1000;
        return to == MeasurementUnit.gram ? grams : grams / 1000;
      case MeasurementUnitCategory.volume:
        final milliliters =
            from == MeasurementUnit.milliliter ? value : value * 1000;
        return to == MeasurementUnit.milliliter
            ? milliliters
            : milliliters / 1000;
      case MeasurementUnitCategory.length:
        final millimeters = switch (from) {
          MeasurementUnit.millimeter => value,
          MeasurementUnit.centimeter => value * 10,
          MeasurementUnit.meter => value * 1000,
          _ => null,
        };
        if (millimeters == null) return null;
        return switch (to) {
          MeasurementUnit.millimeter => millimeters,
          MeasurementUnit.centimeter => millimeters / 10,
          MeasurementUnit.meter => millimeters / 1000,
          _ => null,
        };
      case MeasurementUnitCategory.count:
      case MeasurementUnitCategory.ratio:
      case MeasurementUnitCategory.derived:
      case MeasurementUnitCategory.area:
        // No conversion needed for these categories (single unit or incompatible)
        return null;
    }
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}
