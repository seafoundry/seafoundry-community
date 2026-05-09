// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/types/event_type.dart';

class InventoryEventType extends EventType {
  const InventoryEventType({required super.id, required super.name});

  static Map<String, InventoryEventType> builtins = {
    populationLoss.id: populationLoss,
    populationGain.id: populationGain,
    lifeStageTransition.id: lifeStageTransition,
    physicalFormChange.id: physicalFormChange,
    sizeChange.id: sizeChange,
    quantityChange.id: quantityChange,
    split.id: split,
    merge.id: merge,
    ...CoralSizeEventType.builtins,
  };

  static const String populationLossId = 'event_population_loss';
  static const InventoryEventType populationLoss = InventoryEventType(
    id: populationLossId,
    name: 'Population Loss',
  );

  static const String populationGainId = 'event_population_gain';
  static const InventoryEventType populationGain = InventoryEventType(
    id: populationGainId,
    name: 'Population Gain',
  );

  static const String lifeStageTransitionId = 'event_life_stage_transition';
  static const InventoryEventType lifeStageTransition = InventoryEventType(
    id: lifeStageTransitionId,
    name: 'Life Stage Transition',
  );

  /// Database ID for physical form change events.
  static const String physicalFormChangeId = 'event_physical_form_change';
  static const InventoryEventType physicalFormChange = InventoryEventType(
    id: physicalFormChangeId,
    name: 'Physical Form Change',
  );

  static const String sizeChangeId = 'event_size_change';
  static const InventoryEventType sizeChange = InventoryEventType(
    id: sizeChangeId,
    name: 'Size Change',
  );

  static const String quantityChangeId = 'event_quantity_change';
  static const InventoryEventType quantityChange = InventoryEventType(
    id: quantityChangeId,
    name: 'Quantity Change',
  );

  static const String splitId = 'event_split';
  static const InventoryEventType split = InventoryEventType(
    id: splitId,
    name: 'Split',
  );

  static const String mergeId = 'event_merge';
  static const InventoryEventType merge = InventoryEventType(
    id: mergeId,
    name: 'Merge',
  );
}

class CoralSizeEventType extends InventoryEventType {
  const CoralSizeEventType({required super.id, required super.name});

  static final Map<String, CoralSizeEventType> builtins = {
    sizeAdded.id: sizeAdded,
    growth.id: growth,
    tissueLoss.id: tissueLoss,
  };

  static const CoralSizeEventType sizeAdded = CoralSizeEventType(id: 'event_coral_size_added', name: 'Size Added');

  static const CoralSizeEventType growth = CoralSizeEventType(id: 'event_coral_size_growth', name: 'Growth');

  static const CoralSizeEventType tissueLoss = CoralSizeEventType(
    id: 'event_coral_size_tissue_loss',
    name: 'Tissue Loss',
  );
}
