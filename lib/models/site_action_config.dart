// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/widgets/dialogs/observation/observation_dialog_config.dart';

/// Configuration for site-specific actions that appear in the action dock.
/// This class defines which observation, husbandry, and task types are available
/// for each site type, along with custom labels and icons.
class SiteActionConfig {
  const SiteActionConfig({
    required this.observationTypes,
    required this.husbandryTypes,
    this.taskTypes,
    this.customLabels = const {},
    this.customSubtitles = const {},
    this.customIcons = const {},
  });

  /// Observation dialog types available for this site type.
  final List<ObservationDialogType> observationTypes;

  /// Husbandry event types available for this site type.
  final List<HusbandryEventType> husbandryTypes;

  /// Task action types available for this site type (optional).
  /// If null, uses default task types.
  final List<String>? taskTypes;

  /// Custom labels to override default action names.
  /// Key format: 'observation.{type}' or 'husbandry.{type}'
  final Map<String, String> customLabels;

  /// Custom subtitles to override default action descriptions.
  /// Key format: 'observation.{type}' or 'husbandry.{type}'
  final Map<String, String> customSubtitles;

  /// Custom icons to override default action icons.
  /// Key format: 'observation.{type}' or 'husbandry.{type}'
  final Map<String, IconData> customIcons;

  /// Get custom label for an observation type.
  String? getObservationLabel(ObservationDialogType type) {
    return customLabels['observation.${type.name}'];
  }

  /// Get custom subtitle for an observation type.
  String? getObservationSubtitle(ObservationDialogType type) {
    return customSubtitles['observation.${type.name}'];
  }

  /// Get custom icon for an observation type.
  IconData? getObservationIcon(ObservationDialogType type) {
    return customIcons['observation.${type.name}'];
  }

  /// Get custom label for a husbandry type.
  String? getHusbandryLabel(HusbandryEventType type) {
    return customLabels['husbandry.${type.id}'];
  }

  /// Get custom subtitle for a husbandry type.
  String? getHusbandrySubtitle(HusbandryEventType type) {
    return customSubtitles['husbandry.${type.id}'];
  }

  /// Get custom icon for a husbandry type.
  IconData? getHusbandryIcon(HusbandryEventType type) {
    return customIcons['husbandry.${type.id}'];
  }

  /// Default configuration for ex-situ nursery sites.
  static const SiteActionConfig forNursery = SiteActionConfig(
    observationTypes: [
      ObservationDialogType.general,
      ObservationDialogType.disease,
      ObservationDialogType.biofouling,
      ObservationDialogType.pest,
      ObservationDialogType.discoloration,
      ObservationDialogType.maintenanceRequired,
    ],
    husbandryTypes: [
      HusbandryEventType.feeding,
      HusbandryEventType.waterQualityTest,
      HusbandryEventType.cleaning,
      HusbandryEventType.treatment,
      HusbandryEventType.environmentalAdjustment,
      HusbandryEventType.structureMaintenance,
    ],
  );

  /// Configuration for in-situ nursery sites (ocean-based).
  static const SiteActionConfig forNurseryInSitu = SiteActionConfig(
    observationTypes: [
      ObservationDialogType.general,
      ObservationDialogType.disease,
      ObservationDialogType.biofouling,
      ObservationDialogType.pest,
      ObservationDialogType.discoloration,
      ObservationDialogType.maintenanceRequired,
    ],
    husbandryTypes: [
      HusbandryEventType.feeding,
      HusbandryEventType.cleaning,
      HusbandryEventType.treatment,
      HusbandryEventType.structureMaintenance,
    ],
  );

  /// Configuration for outplanting sites.
  static const SiteActionConfig forOutplanting = SiteActionConfig(
    observationTypes: [
      ObservationDialogType.disease,
      ObservationDialogType.biofouling,
    ],
    husbandryTypes: [
      HusbandryEventType.acquireOrthomosaic,
      HusbandryEventType.sitePrep,
      HusbandryEventType.ecologicalSurvey,
      HusbandryEventType.logWaterConditions,
    ],
    customLabels: {
      'observation.disease': 'Record Disease',
      'observation.biofouling': 'Record Biofouling',
      'husbandry.${HusbandryEventType.acquireOrthomosaicId}':
          'Acquire Orthomosaic',
      'husbandry.${HusbandryEventType.sitePrepId}': 'Site Prep',
      'husbandry.${HusbandryEventType.ecologicalSurveyId}':
          'Record Ecological Survey',
      'husbandry.${HusbandryEventType.logWaterConditionsId}':
          'Log Water Conditions',
    },
    customSubtitles: {
      'observation.disease': 'Track disease symptoms and severity',
      'observation.biofouling': 'Track algae, barnacles, and fouling',
      'husbandry.${HusbandryEventType.acquireOrthomosaicId}':
          'Capture orthomosaic imagery',
      'husbandry.${HusbandryEventType.sitePrepId}':
          'Record site preparation activities',
      'husbandry.${HusbandryEventType.ecologicalSurveyId}':
          'Record ecological survey data',
      'husbandry.${HusbandryEventType.logWaterConditionsId}':
          'Record water quality parameters',
    },
    customIcons: {
      'husbandry.${HusbandryEventType.acquireOrthomosaicId}': Icons.camera_alt,
      'husbandry.${HusbandryEventType.sitePrepId}': Icons.build,
      'husbandry.${HusbandryEventType.ecologicalSurveyId}': Icons.eco,
      'husbandry.${HusbandryEventType.logWaterConditionsId}': Icons.water_drop,
    },
    taskTypes: [
      'acquire_orthomosaic',
      'site_prep',
      'ecological_survey',
      'log_water_conditions',
    ],
  );

  /// Configuration for gene bank sites.
  static const SiteActionConfig forGeneBank = SiteActionConfig(
    observationTypes: [
      ObservationDialogType.general,
      ObservationDialogType.disease,
      ObservationDialogType.maintenanceRequired,
    ],
    husbandryTypes: [
      HusbandryEventType.waterQualityTest,
      HusbandryEventType.cleaning,
      HusbandryEventType.treatment,
      HusbandryEventType.structureMaintenance,
    ],
  );

  /// Configuration for field collection sites.
  static const SiteActionConfig forFieldCollection = SiteActionConfig(
    observationTypes: [
      ObservationDialogType.general,
      ObservationDialogType.disease,
      ObservationDialogType.biofouling,
      ObservationDialogType.discoloration,
    ],
    husbandryTypes: [HusbandryEventType.treatment],
  );

  /// Configuration for monitoring-only sites (baseline, reference).
  /// Focuses on observations and ecological surveys without husbandry interventions.
  static const SiteActionConfig forMonitoringOnly = SiteActionConfig(
    observationTypes: [
      ObservationDialogType.general,
      ObservationDialogType.disease,
      ObservationDialogType.biofouling,
      ObservationDialogType.discoloration,
    ],
    husbandryTypes: [
      HusbandryEventType.ecologicalSurvey,
      HusbandryEventType.logWaterConditions,
      HusbandryEventType.acquireOrthomosaic,
    ],
    customLabels: {
      'husbandry.${HusbandryEventType.ecologicalSurveyId}':
          'Record Ecological Survey',
      'husbandry.${HusbandryEventType.logWaterConditionsId}':
          'Log Water Conditions',
      'husbandry.${HusbandryEventType.acquireOrthomosaicId}':
          'Acquire Orthomosaic',
    },
    customSubtitles: {
      'husbandry.${HusbandryEventType.ecologicalSurveyId}':
          'Document baseline/reference ecological conditions',
      'husbandry.${HusbandryEventType.logWaterConditionsId}':
          'Record water quality parameters for comparison',
      'husbandry.${HusbandryEventType.acquireOrthomosaicId}':
          'Capture imagery for change detection',
    },
    customIcons: {
      'husbandry.${HusbandryEventType.ecologicalSurveyId}': Icons.eco,
      'husbandry.${HusbandryEventType.logWaterConditionsId}': Icons.water_drop,
      'husbandry.${HusbandryEventType.acquireOrthomosaicId}': Icons.camera_alt,
    },
  );
}
