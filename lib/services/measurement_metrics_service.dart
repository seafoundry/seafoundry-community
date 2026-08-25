import 'package:seafoundry_community/models/inventory/physical_form_config.dart';
import 'package:seafoundry_community/models/types/life_stage.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';
import 'package:seafoundry_community/models/types/organism_kind.dart';
import 'package:seafoundry_community/services/physical_form_registry.dart';

/// Configuration for which measurement fields are enabled for a physical form
class MeasurementFieldConfig {
  const MeasurementFieldConfig({
    required this.enableCount,
    required this.enableVolume,
    required this.enableTissueArea,
    this.countLabel,
    this.volumeLabel,
    this.tissueAreaLabel,
    this.countUnits = const [MeasurementUnit.count],
    this.volumeUnits = const [MeasurementUnit.milliliter, MeasurementUnit.liter],
  });

  final bool enableCount;
  final bool enableVolume;
  final bool enableTissueArea;
  final String? countLabel;
  final String? volumeLabel;
  final String? tissueAreaLabel;
  final List<MeasurementUnit> countUnits;
  final List<MeasurementUnit> volumeUnits;
  // Tissue area is always cm², no dropdown needed

  /// Default config when physical form is unknown
  static const defaultConfig = MeasurementFieldConfig(
    enableCount: true,
    enableVolume: true,
    enableTissueArea: false,
  );
}

class MeasurementMetricsService {
  MeasurementMetricsService._();

  /// Get measurement field configuration for a physical form
  static MeasurementFieldConfig getFieldConfig({
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    String? physicalFormId,
    String? sizeBandId,
  }) {
    if (physicalFormId == null) {
      return MeasurementFieldConfig.defaultConfig;
    }

    final formConfig = PhysicalFormRegistry.instance.getFormConfig(
      organismKind,
      lifeStage,
      physicalFormId,
    );

    if (formConfig == null) {
      return MeasurementFieldConfig.defaultConfig;
    }

    // Get size band config if specified
    SizeBandConfig? sizeBand;
    if (sizeBandId != null) {
      sizeBand = formConfig.sizeBands
          .where((b) => b.id == sizeBandId)
          .firstOrNull;
    }
    sizeBand ??= formConfig.sizeBands.firstOrNull;

    if (sizeBand == null) {
      return MeasurementFieldConfig.defaultConfig;
    }

    // Determine count units based on form category
    final countUnits = _getCountUnits(formConfig);

    return MeasurementFieldConfig(
      enableCount: sizeBand.enableCount,
      enableVolume: sizeBand.enableVolume,
      enableTissueArea: sizeBand.enableTissueArea,
      countLabel: sizeBand.countLabel,
      volumeLabel: sizeBand.volumeLabel,
      tissueAreaLabel: sizeBand.tissueAreaLabel,
      countUnits: countUnits,
    );
  }

  static List<MeasurementUnit> _getCountUnits(PhysicalFormConfig config) {
    // Count is the only valid unit for record quantity
    return [MeasurementUnit.count];
  }

  /// Validate that metrics are appropriate for the physical form
  static String? validateMetrics({
    required MeasurementFieldConfig config,
    int? count,
  }) {
    // If field is enabled and required but empty, return error
    // For now, all enabled fields are optional

    if (!config.enableCount && count != null) {
      return 'Count is not applicable for this physical form';
    }

    return null; // Valid
  }
}
