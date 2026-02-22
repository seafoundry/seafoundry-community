// @tier: community
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Event type definitions for husbandry actions such as cleaning, feeding,
/// treatments, environmental adjustments, and routine maintenance.
class HusbandryEventType extends EventType {
  const HusbandryEventType({
    required super.id,
    required super.name,
    Set<OrganismKind>? supportedOrganisms,
    this.description,
  }) : supportedOrganisms = supportedOrganisms ?? _allOrganisms;

  final Set<OrganismKind> supportedOrganisms;
  final String? description;

  bool supportsOrganism(OrganismKind kind) =>
      supportedOrganisms.contains(kind);

  static const String cleaningId = 'event_cleaning';
  static const HusbandryEventType cleaning = HusbandryEventType(
    id: cleaningId,
    name: 'Cleaning',
  );

  static const String feedingId = 'event_feeding';
  static const HusbandryEventType feeding = HusbandryEventType(
    id: feedingId,
    name: 'Feeding',
    supportedOrganisms: _feedingOrganisms,
  );

  static const String treatmentId = 'event_treatment';
  static const HusbandryEventType treatment = HusbandryEventType(
    id: treatmentId,
    name: 'Treatment',
  );

  static const String environmentalAdjustmentId =
      'event_environmental_adjustment';
  static const HusbandryEventType environmentalAdjustment = HusbandryEventType(
    id: environmentalAdjustmentId,
    name: 'Environmental Adjustment',
  );

  static const String structureMaintenanceId = 'event_structure_maintenance';
  static const HusbandryEventType structureMaintenance = HusbandryEventType(
    id: structureMaintenanceId,
    name: 'Structure Maintenance',
  );

  static const String waterQualityTestId = 'event_water_quality_test';
  static const HusbandryEventType waterQualityTest = HusbandryEventType(
    id: waterQualityTestId,
    name: 'Water Quality Test',
  );

  // Outplanting-specific husbandry event types
  static const String acquireOrthomosaicId = 'event_acquire_orthomosaic';
  static const HusbandryEventType acquireOrthomosaic = HusbandryEventType(
    id: acquireOrthomosaicId,
    name: 'Acquire Orthomosaic',
    supportedOrganisms: _outplantOrganisms,
  );

  static const String sitePrepId = 'event_site_prep';
  static const HusbandryEventType sitePrep = HusbandryEventType(
    id: sitePrepId,
    name: 'Site Prep',
    supportedOrganisms: _outplantOrganisms,
  );

  static const String ecologicalSurveyId = 'event_ecological_survey';
  static const HusbandryEventType ecologicalSurvey = HusbandryEventType(
    id: ecologicalSurveyId,
    name: 'Record Ecological Survey',
    supportedOrganisms: _outplantOrganisms,
  );

  static const String logWaterConditionsId = 'event_log_water_conditions';
  static const HusbandryEventType logWaterConditions = HusbandryEventType(
    id: logWaterConditionsId,
    name: 'Log Water Conditions',
    supportedOrganisms: _outplantOrganisms,
  );

  static const String husbandryLogId = 'event_husbandry_log';
  static const HusbandryEventType husbandryLog = HusbandryEventType(
    id: husbandryLogId,
    name: 'Husbandry Log',
  );

  /// Ordered list of husbandry event types for UI/query helpers.
  static const List<HusbandryEventType> values = [
    cleaning,
    feeding,
    treatment,
    environmentalAdjustment,
    structureMaintenance,
    waterQualityTest,
    acquireOrthomosaic,
    sitePrep,
    ecologicalSurvey,
    logWaterConditions,
    husbandryLog,
  ];

  static final Map<String, HusbandryEventType> builtins = {
    for (final type in values) type.id: type,
  };

  static List<HusbandryEventType> supportedFor(OrganismKind kind) =>
      values.where((type) => type.supportsOrganism(kind)).toList();

  /// Check if this is an outplanting-specific event type.
  bool get isOutplantingSpecific {
    return id == acquireOrthomosaicId ||
        id == sitePrepId ||
        id == ecologicalSurveyId ||
        id == logWaterConditionsId;
  }
}

const Set<OrganismKind> _allOrganisms = {
  OrganismKind.coral,
  OrganismKind.oyster,
  OrganismKind.seagrass,
  OrganismKind.kelp,
  OrganismKind.mangrove,
  OrganismKind.echinoid,
  OrganismKind.crab,
  OrganismKind.finfish,
  OrganismKind.seaCucumber,
};

/// Organisms that require feeding (heterotrophic organisms only)
/// Excludes photosynthetic/autotrophic organisms (coral, kelp, seagrass, mangrove)
const Set<OrganismKind> _feedingOrganisms = {
  OrganismKind.finfish,
  OrganismKind.oyster,
  OrganismKind.echinoid,
  OrganismKind.crab,
  OrganismKind.seaCucumber,
};

const Set<OrganismKind> _outplantOrganisms = {
  OrganismKind.coral,
  OrganismKind.oyster,
  OrganismKind.seagrass,
  OrganismKind.kelp,
  OrganismKind.mangrove,
};
