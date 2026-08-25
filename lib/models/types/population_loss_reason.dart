// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_community/models/models.dart';

class PopulationLossReason extends BuiltinRecordType {
  const PopulationLossReason({required super.id, required super.name});

  static final Map<String, PopulationLossReason> builtins = {
    mortality.id: mortality,
    lost.id: lost,
    propagated.id: propagated,
    humanError.id: humanError,
    outplanted.id: outplanted,
    transferred.id: transferred,
    other.id: other,
    // Specific mortality reasons (formerly MortalityReason subclass)
    mortalityDisease.id: mortalityDisease,
    mortalityPropagation.id: mortalityPropagation,
    mortalityPredation.id: mortalityPredation,
    mortalityWaterQuality.id: mortalityWaterQuality,
    mortalityAlgae.id: mortalityAlgae,
    mortalityOther.id: mortalityOther,
    // Outplant-specific loss reasons (formerly OutplantLossReason subclass)
    outplantPredation.id: outplantPredation,
    outplantDisease.id: outplantDisease,
    outplantThermalStress.id: outplantThermalStress,
    outplantWaterQuality.id: outplantWaterQuality,
    outplantUnknown.id: outplantUnknown,
  };

  /// IDs of detailed mortality reasons (nursery context).
  static const Set<String> mortalityReasonIds = {
    'mortality_reason_disease',
    'mortality_reason_propagation',
    'mortality_reason_predation',
    'mortality_reason_water_quality',
    'mortality_reason_algae',
    'mortality_reason_other',
    'mortality_reason_unknown',
  };

  /// IDs of outplant-specific loss reasons.
  static const Set<String> outplantLossReasonIds = {
    'outplant_loss_reason_predation',
    'outplant_loss_reason_disease',
    'outplant_loss_reason_thermal_stress',
    'outplant_loss_reason_water_quality',
    'outplant_loss_reason_unknown',
  };

  /// Map of just the mortality-detail reasons, for UI selectors.
  static final Map<String, PopulationLossReason> mortalityReasonBuiltins = {
    mortalityDisease.id: mortalityDisease,
    mortalityPropagation.id: mortalityPropagation,
    mortalityPredation.id: mortalityPredation,
    mortalityWaterQuality.id: mortalityWaterQuality,
    mortalityAlgae.id: mortalityAlgae,
    mortalityOther.id: mortalityOther,
  };

  /// Nursery-focused loss reasons (excludes outplant-specific variants).
  static List<PopulationLossReason> get nurseryLossReasons => builtins.values
      .where((reason) => !outplantLossReasonIds.contains(reason.id))
      .toList(growable: false);

  /// Primary nursery loss reasons for UI hierarchies.
  /// Excludes detailed mortality reasons, keeping only the top-level 'Mortality' category.
  static List<PopulationLossReason> get primaryNurseryLossReasons =>
      nurseryLossReasons
          .where((reason) => !mortalityReasonIds.contains(reason.id))
          .toList();

  bool get isMortality =>
      id == mortality.id ||
      mortalityReasonIds.contains(id) ||
      outplantLossReasonIds.contains(id);

  // --- Top-level loss reasons ---

  static const PopulationLossReason mortality = PopulationLossReason(
    id: 'population_loss_reason_mortality',
    name: 'Mortality',
  );

  static const PopulationLossReason lost = PopulationLossReason(
    id: 'population_loss_reason_lost',
    name: 'Lost',
  );

  static const PopulationLossReason propagated = PopulationLossReason(
    id: 'population_loss_reason_propagated',
    name: 'Propagated',
  );

  static const PopulationLossReason humanError = PopulationLossReason(
    id: 'population_loss_reason_human_error',
    name: 'Human Error',
  );

  static const PopulationLossReason outplanted = PopulationLossReason(
    id: 'population_loss_reason_outplanted',
    name: 'Outplanted',
  );

  static const PopulationLossReason transferred = PopulationLossReason(
    id: 'population_loss_reason_transferred',
    name: 'Transferred',
  );

  static const PopulationLossReason other = PopulationLossReason(
    id: 'population_loss_reason_other',
    name: 'Other',
  );

  // unknown is a fallback for parsing, exclude from builtins
  static const PopulationLossReason unknown = PopulationLossReason(
    id: 'population_loss_reason_unknown',
    name: 'Unknown',
  );

  // --- Specific mortality reasons (nursery context) ---

  static const PopulationLossReason mortalityDisease = PopulationLossReason(
    id: 'mortality_reason_disease',
    name: 'Disease',
  );

  static const PopulationLossReason mortalityPropagation = PopulationLossReason(
    id: 'mortality_reason_propagation',
    name: 'Recent Propagation',
  );

  static const PopulationLossReason mortalityPredation = PopulationLossReason(
    id: 'mortality_reason_predation',
    name: 'Pest/Predation',
  );

  static const PopulationLossReason mortalityWaterQuality = PopulationLossReason(
    id: 'mortality_reason_water_quality',
    name: 'Water Quality',
  );

  static const PopulationLossReason mortalityAlgae = PopulationLossReason(
    id: 'mortality_reason_algae',
    name: 'Algae',
  );

  static const PopulationLossReason mortalityOther = PopulationLossReason(
    id: 'mortality_reason_other',
    name: 'Other',
  );

  // unknown mortality is a fallback for parsing, exclude from builtins
  static const PopulationLossReason mortalityUnknown = PopulationLossReason(
    id: 'mortality_reason_unknown',
    name: 'Unknown',
  );

  // --- Outplant-specific loss reasons ---

  static const PopulationLossReason outplantPredation = PopulationLossReason(
    id: 'outplant_loss_reason_predation',
    name: 'Pest/Predation',
  );

  static const PopulationLossReason outplantDisease = PopulationLossReason(
    id: 'outplant_loss_reason_disease',
    name: 'Disease',
  );

  static const PopulationLossReason outplantThermalStress = PopulationLossReason(
    id: 'outplant_loss_reason_thermal_stress',
    name: 'Thermal Stress',
  );

  static const PopulationLossReason outplantWaterQuality = PopulationLossReason(
    id: 'outplant_loss_reason_water_quality',
    name: 'Water Quality',
  );

  static const PopulationLossReason outplantUnknown = PopulationLossReason(
    id: 'outplant_loss_reason_unknown',
    name: 'Unknown',
  );
}
