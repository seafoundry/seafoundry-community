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
    this.volumeCm3,
    this.tissueAreaCm2,
  });

  final int? count;
  final double? volumeCm3;
  final double? tissueAreaCm2;

  SizeMetrics copyWith({
    int? count,
    double? volumeCm3,
    double? tissueAreaCm2,
  }) {
    return SizeMetrics(
      count: count ?? this.count,
      volumeCm3: volumeCm3 ?? this.volumeCm3,
      tissueAreaCm2: tissueAreaCm2 ?? this.tissueAreaCm2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (count != null) 'count': count,
      if (volumeCm3 != null) 'volumeCm3': volumeCm3,
      if (tissueAreaCm2 != null) 'tissueAreaCm2': tissueAreaCm2,
    };
  }

  @override
  List<Object?> get props => [count, volumeCm3, tissueAreaCm2];
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
    this.volumeCm3Override,
    this.tissueAreaCm2Override,
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

  /// Overrides for resolved metrics (count, volume cm^3, tissue area cm^2)
  final int? countOverride;
  final double? volumeCm3Override;
  final double? tissueAreaCm2Override;

  bool get isEmpty =>
      (sizeClass == null || sizeClass!.trim().isEmpty) &&
      measuredDimension == null &&
      dimensionUnit == null &&
      organismsPerUnit == null &&
      volumeAmount == null &&
      volumeUnit == null &&
      countOverride == null &&
      volumeCm3Override == null &&
      tissueAreaCm2Override == null &&
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
    Object? volumeCm3Override = _sizeSpecSentinel,
    Object? tissueAreaCm2Override = _sizeSpecSentinel,
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
      volumeCm3Override: volumeCm3Override == _sizeSpecSentinel
          ? this.volumeCm3Override
          : volumeCm3Override as double?,
      tissueAreaCm2Override: tissueAreaCm2Override == _sizeSpecSentinel
          ? this.tissueAreaCm2Override
          : tissueAreaCm2Override as double?,
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
    if (volumeCm3Override != null) json['volumeCm3Override'] = volumeCm3Override;
    if (tissueAreaCm2Override != null) {
      json['tissueAreaCm2Override'] = tissueAreaCm2Override;
    }

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
      volumeCm3Override: safeDouble(json['volumeCm3Override']),
      tissueAreaCm2Override: safeDouble(json['tissueAreaCm2Override']),
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

  /// Model-level 3-tier resolution for size metrics.
  ///
  /// Resolves metrics using the following priority chain:
  ///   - **Tier 1**: Per-record override ([countOverride], [volumeCm3Override],
  ///     [tissueAreaCm2Override])
  ///   - **Tier 3**: YAML default from [sizeBand] config (defaultCount,
  ///     defaultVolumeCm3, defaultTissueAreaCm2)
  ///   - **Tier 4**: Legacy mm3 conversion ([SizeBandConfig.volumeMm3] / 1000)
  ///
  /// **Tier 2 (org admin overrides)** is intentionally omitted here because
  /// models should not depend on services. [SizeMetricsResolver] in the service
  /// layer adds tier 2 via [OrgSizeOverridesService], providing the full 4-tier
  /// chain. Use this method in contexts where org overrides are unavailable
  /// (e.g., pure model logic, offline fallback, or display-only paths).
  SizeMetrics resolvedMetrics({SizeBandConfig? sizeBand}) {
    final resolvedCount =
        countOverride ?? sizeBand?.defaultCount ?? sizeBand?.estimatedIndividuals;
    final resolvedVolume =
        volumeCm3Override ?? sizeBand?.defaultVolumeCm3 ?? _convertFromMm3(sizeBand?.volumeMm3);
    final resolvedTissueArea =
        tissueAreaCm2Override ?? sizeBand?.defaultTissueAreaCm2;

    return SizeMetrics(
      count: resolvedCount,
      volumeCm3: resolvedVolume,
      tissueAreaCm2: resolvedTissueArea,
    );
  }

  double? _convertFromMm3(double? mm3) {
    if (mm3 == null) return null;
    // 1 cubic centimeter = 1000 cubic millimeters
    return mm3 / 1000.0;
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
        volumeCm3Override,
        tissueAreaCm2Override,
      ];
}
