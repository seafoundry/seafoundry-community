import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';

/// Wraps a numeric quantity with its corresponding measurement unit so batch
/// holdings and CSV adapters can remain organism-agnostic.
class PopulationMeasurement extends Equatable {
  const PopulationMeasurement({required this.value, required this.unit});

  final double value;
  final MeasurementUnit unit;

  PopulationMeasurement copyWith({double? value, MeasurementUnit? unit}) {
    return PopulationMeasurement(
      value: value ?? this.value,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() {
    return {'value': value, 'unit': unit.id};
  }

  factory PopulationMeasurement.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('value')) {
      throw ArgumentError('PopulationMeasurement requires a numeric value.');
    }
    final rawValue = json['value'];
    final double parsedValue;
    if (rawValue is num) {
      parsedValue = rawValue.toDouble();
    } else if (rawValue is String && rawValue.trim().isNotEmpty) {
      parsedValue = double.parse(rawValue);
    } else {
      throw ArgumentError.value(
        rawValue,
        'value',
        'PopulationMeasurement value must be numeric.',
      );
    }

    final unit = MeasurementUnitX.fromName(
      json['unit']?.toString() ?? MeasurementUnit.count.id,
    );

    return PopulationMeasurement(value: parsedValue, unit: unit);
  }

  @override
  List<Object?> get props => [value, unit];
}
