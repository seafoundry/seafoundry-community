// @tier: community
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Lightweight aggregate that captures how many neutral holdings exist for a
/// given organism/holding kind combination (and the summed measurement value).
class HoldingSummary {
  const HoldingSummary({
    required this.organismKind,
    required this.holdingKind,
    required this.recordCount,
    required this.totalQuantity,
    required this.measurementUnit,
  });

  final OrganismKind organismKind;
  final String holdingKind;
  final int recordCount;
  final double totalQuantity;
  final MeasurementUnit measurementUnit;

  bool get hasQuantity => totalQuantity > 0;
}
