// @tier: community
// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/types/gene_bank_event_type.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/loan_event_type.dart';
import 'package:seafoundry_app/models/types/record_type.dart';
import 'package:seafoundry_app/models/types/status_event_type.dart';

class EventType extends BuiltinRecordType {
  const EventType({required super.id, required super.name});

  static final Map<String, EventType> builtins = {
    create.id: create,
    update.id: update,
    delete.id: delete,
    moveIn.id: moveIn,
    moveOut.id: moveOut,
    observation.id: observation,
    ecologicalSurvey.id: ecologicalSurvey,
    spawn.id: spawn,
    cross.id: cross,
    settle.id: settle,
    propagation.id: propagation,
    task.id: task,
    maintenanceRequiredObservation.id: maintenanceRequiredObservation,
    activity.id: activity,
    comment.id: comment,
    outplant.id: outplant,
    genetModification.id: genetModification,
    inventoryRecordCorrection.id: inventoryRecordCorrection,
    inventoryEventCorrection.id: inventoryEventCorrection,
    observationCorrection.id: observationCorrection,
    geneticRecordCorrection.id: geneticRecordCorrection,
    recordNameChange.id: recordNameChange,
    localIdChange.id: localIdChange,
    genetIdentityChange.id: genetIdentityChange,
    ownershipChange.id: ownershipChange,
    ...InventoryEventType.builtins,
    ...StatusEventType.builtins,
    ...HusbandryEventType.builtins,
    ...GeneBankEventType.builtins,
    ...LoanEventType.builtins,
  };

  // unknown is a fallback for parsing, exclude from builtins
  static const EventType unknown = EventType(
    id: 'event_unknown',
    name: 'Unknown Event Type',
  );

  static const EventType create = EventType(id: 'event_create', name: 'Create');
  static const EventType update = EventType(id: 'event_update', name: 'Update');
  static const EventType delete = EventType(id: 'event_delete', name: 'Delete');
  static const EventType moveOut = EventType(
    id: 'event_move_out',
    name: 'Move Out',
  );
  static const EventType moveIn = EventType(
    id: 'event_move_in',
    name: 'Move In',
  );
  static const EventType observation = EventType(
    id: 'event_observation',
    name: 'Observation',
  );
  static const EventType ecologicalSurvey = EventType(
    id: 'event_ecological_survey',
    name: 'Ecological Survey',
  );
  static const EventType spawn = EventType(id: 'event_spawn', name: 'Spawn');
  static const EventType cross = EventType(id: 'event_cross', name: 'Cross');
  static const EventType settle = EventType(id: 'event_settle', name: 'Settle');
  static const EventType propagation = EventType(id: 'event_propagation', name: 'Propagation');
  static const EventType task = EventType(id: 'event_task', name: 'Task');
  static const EventType maintenanceRequiredObservation = EventType(
    id: 'event_maintenance_required_observation',
    name: 'Maintenance Required Observation',
  );
  static const EventType activity = EventType(
    id: 'event_activity',
    name: 'Activity',
  );
  static const EventType comment = EventType(
    id: 'event_comment',
    name: 'Comment',
  );
  // Filter-only grouping for comment events and community posts.
  static const EventType commentsAndPosts = EventType(
    id: 'event_comments_posts',
    name: 'Comments & Posts',
  );
  static const EventType outplant = EventType(
    id: 'outplant_event',
    name: 'Outplant',
  );
  static const EventType genetModification = EventType(
    id: 'event_genet_modification',
    name: 'Genet Record Modification',
  );
  static const EventType inventoryRecordCorrection = EventType(
    id: 'event_inventory_record_correction',
    name: 'Inventory Record Correction',
  );
  static const EventType inventoryEventCorrection = EventType(
    id: 'event_inventory_event_correction',
    name: 'Inventory Event Correction',
  );
  static const EventType observationCorrection = EventType(
    id: 'event_observation_correction',
    name: 'Observation Correction',
  );
  static const EventType geneticRecordCorrection = EventType(
    id: 'event_genetic_record_correction',
    name: 'Genetic Record Correction',
  );
  static const EventType recordNameChange = EventType(
    id: 'event_record_name_change',
    name: 'Record Name Change',
  );
  static const EventType localIdChange = EventType(
    id: 'event_local_id_change',
    name: 'Local ID Change',
  );
  static const EventType genetIdentityChange = EventType(
    id: 'event_genet_identity_change',
    name: 'Genet Identity Change',
  );
  static const EventType ownershipChange = EventType(
    id: 'event_ownership_change',
    name: 'Ownership Change',
  );
}
