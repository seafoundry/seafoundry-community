
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';

/// Builder for constructing SizeSpec from CSV row data.
class SizeSpecBuilder {
  SizeSpecBuilder._();

  /// Builds a SizeSpec from CSV row data.
  ///
  /// Looks for size-related fields in the row and constructs
  /// a SizeSpec with the appropriate values.
  static SizeSpec build(Map<String, String> row) {
    String? firstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final value = row[key];
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    final sizeBandId = firstNonEmpty(['sizeBandId']);
    final measuredValue = _parseDouble(firstNonEmpty(['measuredDimension']));
    final measuredUnitId = firstNonEmpty(['dimensionUnit']);
    final organismsPerUnit =
        _parseInt(firstNonEmpty(['organismsPerUnit']));
    final volumeAmount = _parseDouble(firstNonEmpty(['volumeAmount']));
    final volumeUnitId = firstNonEmpty(['volumeUnit']);
    final countOverride = _parseInt(firstNonEmpty(['inventoryCount']));

    return SizeSpec(
      sizeBandId: sizeBandId,
      sizeClass: sizeBandId,
      measuredDimension: measuredValue,
      dimensionUnit: MeasurementUnitX.tryParse(measuredUnitId),
      organismsPerUnit: organismsPerUnit,
      volumeAmount: volumeAmount,
      volumeUnit: MeasurementUnitX.tryParse(volumeUnitId),
      countOverride: countOverride,
    );
  }

  static double? _parseDouble(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return double.tryParse(raw.trim());
  }

  static int? _parseInt(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return int.tryParse(raw.trim());
  }
}
