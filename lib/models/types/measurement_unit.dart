// @tier: community
import 'package:collection/collection.dart';

/// Measurement units supported by the neutral inventory model. These identifiers
/// flow through CSV v2 payloads, PopulationMeasurement values, and any UI
/// surfaces that capture batch quantities.
enum MeasurementUnit {
  count,
  gram,
  kilogram,
  milliliter,
  liter,
  millimeter,
  centimeter,
  meter,
  percent,
  partsPerThousand,
  kilogramsPerMeter,
  shootsPerSquareMeter,
  squareCentimeter,
  substrates,
  bags,
  patches,
}

/// Broad categories used for validation and UI grouping.
enum MeasurementUnitCategory { count, mass, volume, length, area, ratio, derived }

extension MeasurementUnitX on MeasurementUnit {
  static const Map<MeasurementUnit, _MeasurementUnitMetadata> _metadata =
      <MeasurementUnit, _MeasurementUnitMetadata>{
        MeasurementUnit.count: _MeasurementUnitMetadata(
          id: 'count',
          label: 'Count',
          symbol: 'count',
          category: MeasurementUnitCategory.count,
          aliases: ['counts', 'units', 'individuals'],
        ),
        MeasurementUnit.gram: _MeasurementUnitMetadata(
          id: 'g',
          label: 'Gram',
          symbol: 'g',
          category: MeasurementUnitCategory.mass,
          aliases: ['grams'],
        ),
        MeasurementUnit.kilogram: _MeasurementUnitMetadata(
          id: 'kg',
          label: 'Kilogram',
          symbol: 'kg',
          category: MeasurementUnitCategory.mass,
          aliases: ['kilograms'],
        ),
        MeasurementUnit.milliliter: _MeasurementUnitMetadata(
          id: 'mL',
          label: 'Milliliter',
          symbol: 'mL',
          category: MeasurementUnitCategory.volume,
          aliases: ['milliliters', 'ml'],
        ),
        MeasurementUnit.liter: _MeasurementUnitMetadata(
          id: 'L',
          label: 'Liter',
          symbol: 'L',
          category: MeasurementUnitCategory.volume,
          aliases: ['liters', 'l'],
        ),
        MeasurementUnit.millimeter: _MeasurementUnitMetadata(
          id: 'mm',
          label: 'Millimeter',
          symbol: 'mm',
          category: MeasurementUnitCategory.length,
          aliases: ['millimeters'],
        ),
        MeasurementUnit.centimeter: _MeasurementUnitMetadata(
          id: 'cm',
          label: 'Centimeter',
          symbol: 'cm',
          category: MeasurementUnitCategory.length,
          aliases: ['centimeters'],
        ),
        MeasurementUnit.meter: _MeasurementUnitMetadata(
          id: 'm',
          label: 'Meter',
          symbol: 'm',
          category: MeasurementUnitCategory.length,
          aliases: ['meters'],
        ),
        MeasurementUnit.percent: _MeasurementUnitMetadata(
          id: 'pct',
          label: 'Percent',
          symbol: '%',
          category: MeasurementUnitCategory.ratio,
          aliases: ['percent', 'percentage'],
        ),
        MeasurementUnit.partsPerThousand: _MeasurementUnitMetadata(
          id: 'ppt',
          label: 'Parts Per Thousand',
          symbol: 'ppt',
          category: MeasurementUnitCategory.ratio,
          aliases: ['parts_per_thousand'],
        ),
        MeasurementUnit.kilogramsPerMeter: _MeasurementUnitMetadata(
          id: 'kg_per_m',
          label: 'Kilograms per meter',
          symbol: 'kg/m',
          category: MeasurementUnitCategory.derived,
          aliases: ['kg/m', 'kilograms_per_meter'],
        ),
        MeasurementUnit.shootsPerSquareMeter: _MeasurementUnitMetadata(
          id: 'shoots_per_m2',
          label: 'Shoots per square meter',
          symbol: 'shoots/m²',
          category: MeasurementUnitCategory.derived,
          aliases: ['shoots/m2', 'shoots_per_square_meter'],
        ),
        MeasurementUnit.squareCentimeter: _MeasurementUnitMetadata(
          id: 'square_centimeter',
          label: 'Square Centimeter',
          symbol: 'cm²',
          category: MeasurementUnitCategory.area,
          aliases: ['cm2', 'square_centimeters'],
        ),
        MeasurementUnit.substrates: _MeasurementUnitMetadata(
          id: 'substrates',
          label: 'Substrates',
          symbol: 'substrates',
          category: MeasurementUnitCategory.count,
        ),
        MeasurementUnit.bags: _MeasurementUnitMetadata(
          id: 'bags',
          label: 'Bags',
          symbol: 'bags',
          category: MeasurementUnitCategory.count,
        ),
        MeasurementUnit.patches: _MeasurementUnitMetadata(
          id: 'patches',
          label: 'Patches',
          symbol: 'patches',
          category: MeasurementUnitCategory.count,
        ),
      };

  /// Canonical identifier used in persistence layers and CSV payloads.
  String get id => _metadata[this]!.id;

  /// Human-friendly label for UI presentation.
  String get label => _metadata[this]!.label;

  /// Symbol suitable for compact displays (e.g., spreadsheet column headers).
  String get symbol => _metadata[this]!.symbol;

  MeasurementUnitCategory get category => _metadata[this]!.category;

  List<String> get aliases => _metadata[this]!.aliases;

  static MeasurementUnit fromName(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Unknown measurement unit. Expected one of: '
            '${MeasurementUnit.values.map((unit) => unit.id).join(', ')}',
      );
    }
    return parsed;
  }

  static MeasurementUnit? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    return MeasurementUnit.values.firstWhereOrNull((unit) {
      final metadata = _metadata[unit]!;
      final candidates = <String>[
        unit.name,
        metadata.id,
        metadata.label,
        metadata.symbol,
        ...metadata.aliases,
      ];
      return candidates.any(
        (candidate) => candidate.trim().toLowerCase() == normalized,
      );
    });
  }

  static MeasurementUnit? fromId(String? value) {
    return tryParse(value);
  }
}

class _MeasurementUnitMetadata {
  const _MeasurementUnitMetadata({
    required this.id,
    required this.label,
    required this.symbol,
    required this.category,
    this.aliases = const <String>[],
  });

  final String id;
  final String label;
  final String symbol;
  final MeasurementUnitCategory category;
  final List<String> aliases;
}
