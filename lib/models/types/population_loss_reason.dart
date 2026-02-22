// @tier: community
// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/models.dart';

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
    ...MortalityReason.builtins,
    ...OutplantLossReason.builtins,
  };

  /// Nursery-focused loss reasons (excludes outplant-specific variants)
  /// This includes ALL specific mortality reasons flattened into the list.
  static List<PopulationLossReason> get nurseryLossReasons => builtins.values
      .where((reason) => reason is! OutplantLossReason)
      .toList(growable: false);

  /// Primary nursery loss reasons for UI hierarchies.
  /// Excludes detailed mortality reasons, keeping only the top-level 'Mortality' category.
  static List<PopulationLossReason> get primaryNurseryLossReasons =>
      nurseryLossReasons.where((reason) => reason is! MortalityReason).toList();

  bool get isMortality =>
      id == mortality.id || this is MortalityReason || this is OutplantLossReason;


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
}

class MortalityReason extends PopulationLossReason {
  const MortalityReason({required super.id, required super.name});

  static final Map<String, MortalityReason> builtins = {
    disease.id: disease,
    propagation.id: propagation,
    predation.id: predation,
    waterQuality.id: waterQuality,
    algae.id: algae,
    other.id: other,
  };

  static const MortalityReason disease = MortalityReason(
    id: 'mortality_reason_disease',
    name: 'Disease',
  );

  static const MortalityReason propagation = MortalityReason(
    id: 'mortality_reason_propagation',
    name: 'Recent Propagation',
  );

  static const MortalityReason predation = MortalityReason(
    id: 'mortality_reason_predation',
    name: 'Pest/Predation',
  );

  static const MortalityReason waterQuality = MortalityReason(
    id: 'mortality_reason_water_quality',
    name: 'Water Quality',
  );

  static const MortalityReason algae = MortalityReason(
    id: 'mortality_reason_algae',
    name: 'Algae',
  );

  static const MortalityReason other = MortalityReason(
    id: 'mortality_reason_other',
    name: 'Other',
  );

  // unknown is a fallback for parsing, exclude from builtins
  static const MortalityReason unknown = MortalityReason(
    id: 'mortality_reason_unknown',
    name: 'Unknown',
  );
}

class OutplantLossReason extends PopulationLossReason {
  const OutplantLossReason({required super.id, required super.name});

  static final Map<String, OutplantLossReason> builtins = {
    predation.id: predation,
    disease.id: disease,
    thermalStress.id: thermalStress,
    waterQuality.id: waterQuality,
    unknown.id: unknown,
  };

  static const OutplantLossReason predation = OutplantLossReason(
    id: 'outplant_loss_reason_predation',
    name: 'Pest/Predation',
  );

  static const OutplantLossReason waterQuality = OutplantLossReason(
    id: 'outplant_loss_reason_water_quality',
    name: 'Water Quality',
  );

  static const OutplantLossReason disease = OutplantLossReason(
    id: 'outplant_loss_reason_disease',
    name: 'Disease',
  );

  static const OutplantLossReason thermalStress = OutplantLossReason(
    id: 'outplant_loss_reason_thermal_stress',
    name: 'Thermal Stress',
  );

  static const OutplantLossReason unknown = OutplantLossReason(
    id: 'outplant_loss_reason_unknown',
    name: 'Unknown',
  );
}
