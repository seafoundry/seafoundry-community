// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Sentinel object for copyWith to distinguish between "not provided" and "explicitly null"
const _sizeSpecSentinel = Object();

class SizeMetrics extends Equatable {
  const SizeMetrics({
    this.count,
  });

  final int? count;

  SizeMetrics copyWith({
    int? count,
  }) {
    return SizeMetrics(
      count: count ?? this.count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (count != null) 'count': count,
    };
  }

  @override
  List<Object?> get props => [count];
}

/// Size specification with dual interpretation support.
///
/// Size meaning depends on physical form category (per 5-Axis spec):
///
/// **Individual forms** (fragment, colony, plug):
/// - Size represents actual physical dimensions
/// - Use: `measuredDimension` + `dimensionUnit` (cm, mm, m)
///
/// **Shared substrate forms** (settlement_substrate, tile, dome):
/// - Size represents density (organisms per substrate unit)
/// - Use: `organismsPerUnit` + `volumeAmount` + `volumeUnit`
///
/// **Container forms** (vial, tank, bag):
/// - Size represents density (organisms per mL volume)
/// - Use: `organismsPerUnit` + `volumeAmount` + `volumeUnit`
///
/// The `sizeClass` field (xs, s, m, l, xl) is preserved for backward compatibility
/// and provides a quick categorical reference.
class SizeSpec extends Equatable {
  const SizeSpec({
    this.sizeClass,
    this.sizeBandId,
    // Dimension-based fields (for individual forms)
    this.measuredDimension,
    this.dimensionUnit,
    // Density-based fields (for container/shared substrate forms)
    this.organismsPerUnit,
    this.volumeAmount,
    this.volumeUnit,
    // Overrides for resolved metrics
    this.countOverride,
  });

  /// Size class (xs, small, medium, large, xl) - categorical reference
  final String? sizeClass;
  final String? sizeBandId;

  // === Dimension-based sizing (for individual forms) ===

  /// Measured physical dimension (e.g., 5.2 cm fragment length)
  final double? measuredDimension;

  /// Unit for dimension measurement (cm, mm, m)
  final MeasurementUnit? dimensionUnit;

  // === Density-based sizing (for container/shared substrate forms) ===

  /// Number of organisms in the density measurement
  final int? organismsPerUnit;

  /// Volume amount for density calculation (e.g., 1.0 for "1mL")
  final double? volumeAmount;

  /// Volume unit for density calculation (mL, L)
  final MeasurementUnit? volumeUnit;

  /// Override for resolved count metric
  final int? countOverride;

  bool get isEmpty =>
      (sizeClass == null || sizeClass!.trim().isEmpty) &&
      measuredDimension == null &&
      dimensionUnit == null &&
      organismsPerUnit == null &&
      volumeAmount == null &&
      volumeUnit == null &&
      countOverride == null &&
      sizeBandId == null;

  /// Returns true if this SizeSpec has size information (either sizeClass or measurements)
  bool get hasSize => !isEmpty;

  /// Returns true if this uses density-based sizing (container/shared substrate)
  bool get isDensityBased => organismsPerUnit != null;

  /// Returns true if this uses dimension-based sizing (individual forms)
  bool get isDimensionBased => measuredDimension != null;

  /// Display string for size based on interpretation mode
  String get displayValue {
    if (isDensityBased) {
      // Density-based display: "1000 per 1mL"
      return '$organismsPerUnit per $volumeAmount${volumeUnit?.symbol ?? ''}';
    } else if (isDimensionBased) {
      // Dimension-based display: "5.2cm"
      final dimension = measuredDimension;
      final unit = dimensionUnit;
      return '$dimension${unit?.symbol ?? ''}';
    } else if (sizeClass != null && sizeClass!.isNotEmpty) {
      // Fallback to size class: "MEDIUM"
      return sizeClass!.toUpperCase();
    } else {
      return 'Unspecified';
    }
  }

  /// Creates a copy with updated fields. Use sentinel pattern for override fields
  /// to distinguish between "not provided" (keep existing) and "explicitly null" (clear).
  SizeSpec copyWith({
    String? sizeClass,
    String? sizeBandId,
    double? measuredDimension,
    MeasurementUnit? dimensionUnit,
    int? organismsPerUnit,
    double? volumeAmount,
    MeasurementUnit? volumeUnit,
    // Use Object? with sentinel to allow explicitly setting null
    Object? countOverride = _sizeSpecSentinel,
  }) {
    return SizeSpec(
      sizeClass: sizeClass ?? this.sizeClass,
      sizeBandId: sizeBandId ?? this.sizeBandId,
      measuredDimension: measuredDimension ?? this.measuredDimension,
      dimensionUnit: dimensionUnit ?? this.dimensionUnit,
      organismsPerUnit: organismsPerUnit ?? this.organismsPerUnit,
      volumeAmount: volumeAmount ?? this.volumeAmount,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      // Sentinel pattern: if sentinel, keep existing; otherwise use new value (including null)
      countOverride: countOverride == _sizeSpecSentinel
          ? this.countOverride
          : countOverride as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    // Always include sizeClass if present
    if (sizeClass != null) json['sizeClass'] = sizeClass;
    if (sizeBandId != null) json['sizeBandId'] = sizeBandId;

    // Dimension-based fields
    if (measuredDimension != null) json['measuredDimension'] = measuredDimension;
    if (dimensionUnit != null) json['dimensionUnit'] = dimensionUnit!.id;

    // Density-based fields
    if (organismsPerUnit != null) json['organismsPerUnit'] = organismsPerUnit;
    if (volumeAmount != null) json['volumeAmount'] = volumeAmount;
    if (volumeUnit != null) json['volumeUnit'] = volumeUnit!.id;

    // Metric overrides
    if (countOverride != null) json['countOverride'] = countOverride;

    return json;
  }

  factory SizeSpec.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const SizeSpec();
    }

    return SizeSpec(
      sizeClass: _asString(json['sizeClass']),
      sizeBandId: _asString(json['sizeBandId']),
      // Dimension-based fields
      measuredDimension: _parseMeasuredDimension(json),
      dimensionUnit: _parseDimensionUnit(json),
      // Density-based fields
      organismsPerUnit: safeInt(json['organismsPerUnit']),
      volumeAmount: safeDouble(json['volumeAmount']),
      volumeUnit: MeasurementUnitX.tryParse(json['volumeUnit']?.toString()),
      countOverride: safeInt(json['countOverride']),
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static double? _parseMeasuredDimension(Map<String, dynamic> json) {
    return safeDouble(json['measuredDimension']);
  }

  static MeasurementUnit? _parseDimensionUnit(Map<String, dynamic> json) {
    return MeasurementUnitX.tryParse(json['dimensionUnit']?.toString());
  }

  /// Model-level resolution for size metrics (count only).
  ///
  /// Resolves count using the following priority chain:
  ///   - **Tier 1**: Per-record override ([countOverride])
  ///   - **Tier 2**: YAML default from [sizeBand] config (defaultCount,
  ///     estimatedIndividuals)
  SizeMetrics resolvedMetrics({SizeBandConfig? sizeBand}) {
    final resolvedCount =
        countOverride ?? sizeBand?.defaultCount ?? sizeBand?.estimatedIndividuals;

    return SizeMetrics(
      count: resolvedCount,
    );
  }

  @override
  List<Object?> get props => [
        sizeClass,
        sizeBandId,
        measuredDimension,
        dimensionUnit,
        organismsPerUnit,
        volumeAmount,
        volumeUnit,
        countOverride,
      ];
}
