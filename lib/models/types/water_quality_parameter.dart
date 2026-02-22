// @tier: community
import 'package:equatable/equatable.dart';

/// Represents a water quality parameter that can be measured
class WaterQualityParameter extends Equatable {
  final String id;
  final String label;
  final String unit;
  final double? minValue;
  final double? maxValue;
  final int decimalPlaces;
  final bool isCustom;

  const WaterQualityParameter._({
    required this.id,
    required this.label,
    required this.unit,
    this.minValue,
    this.maxValue,
    this.decimalPlaces = 2,
    this.isCustom = false,
  });

  /// Create a WaterQualityParameter from an ID
  static WaterQualityParameter? fromId(String? id) {
    if (id == null) return null;
    return builtInParameters.firstWhere(
      (param) => param.id == id,
      orElse: () => WaterQualityParameter._(id: id, label: 'Custom Parameter', unit: '', isCustom: true),
    );
  }

  /// Create a custom water quality parameter
  static WaterQualityParameter custom({
    required String id,
    required String label,
    required String unit,
    double? minValue,
    double? maxValue,
    int decimalPlaces = 2,
  }) {
    return WaterQualityParameter._(
      id: id,
      label: label,
      unit: unit,
      minValue: minValue,
      maxValue: maxValue,
      decimalPlaces: decimalPlaces,
      isCustom: true,
    );
  }

  /// Temperature in Celsius
  static const WaterQualityParameter temperature = WaterQualityParameter._(
    id: 'temperature',
    label: 'Temperature',
    unit: '°C',
    minValue: 15.0,
    maxValue: 32.0,
    decimalPlaces: 1,
  );

  /// pH level
  static const WaterQualityParameter pH = WaterQualityParameter._(
    id: 'ph',
    label: 'pH',
    unit: '',
    minValue: 7.8,
    maxValue: 8.5,
    decimalPlaces: 2,
  );

  /// Salinity in parts per thousand (ppt)
  static const WaterQualityParameter salinity = WaterQualityParameter._(
    id: 'salinity',
    label: 'Salinity',
    unit: 'ppt',
    minValue: 30.0,
    maxValue: 36.0,
    decimalPlaces: 1,
  );

  /// Alkalinity in milliequivalents per liter (meq/L)
  static const WaterQualityParameter alkalinity = WaterQualityParameter._(
    id: 'alkalinity',
    label: 'Alkalinity',
    unit: 'meq/L',
    minValue: 2.5,
    maxValue: 4.0,
    decimalPlaces: 2,
  );

  /// Dissolved oxygen in milligrams per liter (mg/L)
  static const WaterQualityParameter dissolvedOxygen = WaterQualityParameter._(
    id: 'dissolved_oxygen',
    label: 'Dissolved Oxygen',
    unit: 'mg/L',
    minValue: 5.0,
    maxValue: 8.0,
    decimalPlaces: 1,
  );

  /// Nitrate in milligrams per liter (mg/L)
  static const WaterQualityParameter nitrate = WaterQualityParameter._(
    id: 'nitrate',
    label: 'Nitrate',
    unit: 'mg/L',
    minValue: 0.0,
    maxValue: 5.0,
    decimalPlaces: 2,
  );

  /// Phosphate in milligrams per liter (mg/L)
  static const WaterQualityParameter phosphate = WaterQualityParameter._(
    id: 'phosphate',
    label: 'Phosphate',
    unit: 'mg/L',
    minValue: 0.0,
    maxValue: 0.2,
    decimalPlaces: 3,
  );

  /// Ammonia in milligrams per liter (mg/L)
  static const WaterQualityParameter ammonia = WaterQualityParameter._(
    id: 'ammonia',
    label: 'Ammonia',
    unit: 'mg/L',
    minValue: 0.0,
    maxValue: 0.1,
    decimalPlaces: 3,
  );

  /// Photosynthetically Active Radiation (PAR) in microEinsteins per square meter per second (μE/m²/s)
  static const WaterQualityParameter par = WaterQualityParameter._(
    id: 'par',
    label: 'PAR',
    unit: 'μE/m²/s',
    minValue: 50.0,
    maxValue: 500.0,
    decimalPlaces: 0,
  );

  /// List of all built-in water quality parameters
  static const List<WaterQualityParameter> builtInParameters = [
    temperature,
    pH,
    salinity,
    alkalinity,
    dissolvedOxygen,
    nitrate,
    phosphate,
    ammonia,
    par,
  ];

  /// Check if the given value is within the acceptable range
  bool isValueInRange(double value) {
    if (minValue != null && value < minValue!) return false;
    if (maxValue != null && value > maxValue!) return false;
    return true;
  }

  /// Format a value according to the parameter's decimal places
  String formatValue(double value) {
    return value.toStringAsFixed(decimalPlaces);
  }

  /// Get the full display string including value and unit
  String getDisplayString(double value) {
    return '${formatValue(value)} $unit';
  }

  @override
  List<Object?> get props => [id];
}
