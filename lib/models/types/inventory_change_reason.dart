import 'package:seafoundry_community/models/types/record_type.dart';

class LifeStageTransitionReason extends BuiltinRecordType {
  const LifeStageTransitionReason({required super.id, required super.name});

  static final Map<String, LifeStageTransitionReason> builtins = {
    growth.id: growth,
    protocol.id: protocol,
    correction.id: correction,
    other.id: other,
  };

  static const LifeStageTransitionReason growth = LifeStageTransitionReason(
    id: 'life_stage_reason_growth',
    name: 'Observed Growth',
  );

  static const LifeStageTransitionReason protocol = LifeStageTransitionReason(
    id: 'life_stage_reason_protocol',
    name: 'Protocol Driven',
  );

  static const LifeStageTransitionReason correction = LifeStageTransitionReason(
    id: 'life_stage_reason_correction',
    name: 'Data Correction',
  );

  static const LifeStageTransitionReason other = LifeStageTransitionReason(
    id: 'life_stage_reason_other',
    name: 'Other',
  );
}

class PhysicalFormChangeReason extends BuiltinRecordType {
  const PhysicalFormChangeReason({required super.id, required super.name});

  static final Map<String, PhysicalFormChangeReason> builtins = {
    fragmentation.id: fragmentation,
    fusion.id: fusion,
    sampling.id: sampling,
    partialMortality.id: partialMortality,
    correction.id: correction,
    other.id: other,
  };

  static const PhysicalFormChangeReason fragmentation = PhysicalFormChangeReason(
    id: 'form_change_reason_fragmentation',
    name: 'Fragmentation',
  );

  static const PhysicalFormChangeReason fusion = PhysicalFormChangeReason(
    id: 'form_change_reason_fusion',
    name: 'Fusion',
  );

  static const PhysicalFormChangeReason sampling = PhysicalFormChangeReason(
    id: 'form_change_reason_sampling',
    name: 'Sampling',
  );

  static const PhysicalFormChangeReason partialMortality = PhysicalFormChangeReason(
    id: 'form_change_reason_partial_mortality',
    name: 'Partial Mortality',
  );

  static const PhysicalFormChangeReason correction = PhysicalFormChangeReason(
    id: 'form_change_reason_correction',
    name: 'Data Correction',
  );

  static const PhysicalFormChangeReason other = PhysicalFormChangeReason(
    id: 'form_change_reason_other',
    name: 'Other',
  );
}
