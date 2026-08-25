import 'package:equatable/equatable.dart';
import 'package:seafoundry_community/models/inventory/physical_form_category.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

/// Counting mode for inventory records
///
/// Simplified to two modes:
/// - volumetric: Quantity measured in volume (mL, L)
/// - individual (default): Quantity is count of physical units
///   - estimatedIndividuals on size band provides density when applicable
enum InventoryCountingMode {
  /// Count of physical units (fragments, substrates, colonies, etc.)
  /// When size band has estimatedIndividuals, that's density metadata
  /// Example: 5 substrates (size: medium with ~1000 recruits each) = 5 units
  individual,

  /// Measured by volume (e.g., 10mL of gametes)
  volumetric;

  static InventoryCountingMode fromString(String value) {
    return InventoryCountingMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => InventoryCountingMode.individual,
    );
  }
}

/// Default size band identifier used as a fallback when no explicit band is
/// specified. Matches the canonical 'medium' band defined in physical form data.
const String kDefaultSizeBandId = 'medium';

/// Configuration for a size band within a physical form
class SizeBandConfig extends Equatable {
  const SizeBandConfig({
    required this.id,
    required this.label,
    required this.volumeMm3,
    this.estimatedIndividuals,
    required this.sortOrder,
    this.defaultCount,
    this.defaultVolumeCm3,
    this.defaultTissueAreaCm2,
    this.enableCount = true,
    this.enableVolume = true,
    this.enableTissueArea = false,
    this.countLabel,
    this.volumeLabel,
    this.tissueAreaLabel,
  });

  /// Unique identifier (xs, small, medium, large, xl)
  final String id;

  /// Display label with size range (e.g., "Small (~15cm accross)")
  final String label;

  /// Volumetric measurement in cubic millimeters
  final double volumeMm3;

  /// For batch counting mode: estimated population per unit
  /// Null for individual and volumetric counting modes
  final int? estimatedIndividuals;

  /// Display order (1, 2, 3...)
  final int sortOrder;

  /// Optional default metrics for this band (cm^3, cm^2, count)
  final int? defaultCount;
  final double? defaultVolumeCm3;
  final double? defaultTissueAreaCm2;

  /// Toggle metric capture for this band
  final bool enableCount;
  final bool enableVolume;
  final bool enableTissueArea;

  /// Optional custom labels for display
  final String? countLabel;
  final String? volumeLabel;
  final String? tissueAreaLabel;

  factory SizeBandConfig.fromYaml(Map<String, dynamic> yaml) {
    return SizeBandConfig(
      id: yaml['id'] as String,
      label: yaml['label'] as String,
      volumeMm3: safeDouble(yaml['volume_mm3']) ?? 0.0,
      estimatedIndividuals: safeInt(yaml['estimated_individuals']),
      sortOrder: safeInt(yaml['sort_order']) ?? 0,
      defaultCount: safeInt(yaml['default_count']),
      defaultVolumeCm3: safeDouble(yaml['default_volume_cm3']),
      defaultTissueAreaCm2: safeDouble(yaml['default_tissue_area_cm2']),
      enableCount: yaml['enable_count'] as bool? ?? true,
      enableVolume: yaml['enable_volume'] as bool? ?? true,
      enableTissueArea: yaml['enable_tissue_area'] as bool? ?? false,
      countLabel: yaml['count_label'] as String?,
      volumeLabel: yaml['volume_label'] as String?,
      tissueAreaLabel: yaml['tissue_area_label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'volume_mm3': volumeMm3,
      if (estimatedIndividuals != null) 'estimated_individuals': estimatedIndividuals,
      'sort_order': sortOrder,
      if (defaultCount != null) 'default_count': defaultCount,
      if (defaultVolumeCm3 != null) 'default_volume_cm3': defaultVolumeCm3,
      if (defaultTissueAreaCm2 != null)
        'default_tissue_area_cm2': defaultTissueAreaCm2,
      'enable_count': enableCount,
      'enable_volume': enableVolume,
      'enable_tissue_area': enableTissueArea,
      if (countLabel != null) 'count_label': countLabel,
      if (volumeLabel != null) 'volume_label': volumeLabel,
      if (tissueAreaLabel != null) 'tissue_area_label': tissueAreaLabel,
    };
  }

  @override
  List<Object?> get props => [
        id,
        label,
        volumeMm3,
        estimatedIndividuals,
        sortOrder,
        defaultCount,
        defaultVolumeCm3,
        defaultTissueAreaCm2,
        enableCount,
        enableVolume,
        enableTissueArea,
        countLabel,
        volumeLabel,
        tissueAreaLabel,
      ];
}

/// Configuration for a physical form (e.g., settlement substrate, microfragment)
class PhysicalFormConfig extends Equatable {
  const PhysicalFormConfig({
    required this.id,
    required this.displayName,
    required this.countingMode,
    required this.measurementUnit,
    required this.sizeBands,
    this.category,
  });

  /// Unique identifier (e.g., 'settlement_substrate', 'microfragment')
  final String id;

  /// Human-readable name (e.g., 'Settlement Substrate', 'Microfragment')
  final String displayName;

  /// How inventory is counted for this form
  final InventoryCountingMode countingMode;

  /// Measurement unit (e.g., 'substrates', 'count', 'milliliters', 'bags')
  final String measurementUnit;

  /// Available size bands for this form
  final List<SizeBandConfig> sizeBands;

  /// Category determining size interpretation (individual, sharedSubstrate, container)
  /// If null, inferred from countingMode and form ID for backward compatibility.
  final PhysicalFormCategory? category;

  /// Get size band by ID
  SizeBandConfig? getSizeBand(String sizeBandId) {
    try {
      return sizeBands.firstWhere((band) => band.id == sizeBandId);
    } catch (_) {
      return null;
    }
  }

  /// Get default (first) size band
  SizeBandConfig? get defaultSizeBand {
    if (sizeBands.isEmpty) return null;
    return sizeBands.first;
  }

  /// Get the effective category for this physical form.
  /// Uses explicit category if set, otherwise infers from form ID and counting mode.
  PhysicalFormCategory get effectiveCategory {
    if (category != null) return category!;

    if (countingMode == InventoryCountingMode.volumetric) {
      return PhysicalFormCategory.container;
    }

    return PhysicalFormCategory.inferFromFormId(id);
  }

  factory PhysicalFormConfig.fromYaml(Map<String, dynamic> yaml) {
    return PhysicalFormConfig(
      id: yaml['id'] as String,
      displayName: yaml['display_name'] as String,
      countingMode: InventoryCountingMode.fromString(yaml['counting_mode'] as String),
      measurementUnit: yaml['measurement_unit'] as String,
      sizeBands: (yaml['size_bands'] as List)
          .map((band) => SizeBandConfig.fromYaml(safeMapCast(band) ?? const {}))
          .toList(),
      category: PhysicalFormCategoryX.tryParse(yaml['category'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'counting_mode': countingMode.name,
      'measurement_unit': measurementUnit,
      'size_bands': sizeBands.map((band) => band.toJson()).toList(),
      if (category != null) 'category': category!.id,
    };
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        countingMode,
        measurementUnit,
        sizeBands,
        category,
      ];
}

/// Instance of a physical form with selected size band (stored in OrganismRecord)
class PhysicalFormInstance extends Equatable {
  const PhysicalFormInstance({
    required this.formId,
    required this.sizeBandId,
  });

  /// Reference to PhysicalFormConfig (e.g., 'settlement_substrate')
  final String formId;

  /// Selected size band (e.g., 'medium')
  final String sizeBandId;

  factory PhysicalFormInstance.fromJson(Map<String, dynamic> json) {
    return PhysicalFormInstance(
      formId: json['formId'] as String,
      sizeBandId: json['sizeBandId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formId': formId,
      'sizeBandId': sizeBandId,
    };
  }

  @override
  List<Object?> get props => [formId, sizeBandId];
}
