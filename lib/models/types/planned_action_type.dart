// @tier: community
import 'package:seafoundry_app/models/types/record_type.dart';

/// Builtin planned action types for mission allocations.
///
/// These represent the types of actions that can be planned for organisms
/// within a mission context.
class PlannedActionType extends BuiltinRecordType {
  final String? description;

  const PlannedActionType({
    required super.id,
    required super.name,
    this.description,
  });

  // ==========================================================================
  // BUILTIN PLANNED ACTION TYPES
  // ==========================================================================

  static const PlannedActionType outplant = PlannedActionType(
    id: 'planned_action_outplant',
    name: 'Outplant',
    description: 'Transplant organisms to a reef site',
  );

  static const PlannedActionType fragment = PlannedActionType(
    id: 'planned_action_fragment',
    name: 'Fragment',
    description: 'Create fragments from existing organisms',
  );

  static const PlannedActionType monitor = PlannedActionType(
    id: 'planned_action_monitor',
    name: 'Monitor',
    description: 'Monitor and observe organisms',
  );

  static const PlannedActionType collect = PlannedActionType(
    id: 'planned_action_collect',
    name: 'Collect',
    description: 'Collect organisms from the field',
  );

  static const PlannedActionType relocate = PlannedActionType(
    id: 'planned_action_relocate',
    name: 'Relocate',
    description: 'Move organisms to a new location',
  );

  static const PlannedActionType sample = PlannedActionType(
    id: 'planned_action_sample',
    name: 'Sample',
    description: 'Take samples from organisms',
  );

  static const PlannedActionType treat = PlannedActionType(
    id: 'planned_action_treat',
    name: 'Treat',
    description: 'Apply treatment to organisms',
  );

  static const PlannedActionType maintenance = PlannedActionType(
    id: 'planned_action_maintenance',
    name: 'Maintenance',
    description: 'Perform maintenance on organisms or structures',
  );

  /// Ordered list of builtin planned action types
  static const List<PlannedActionType> values = [
    outplant,
    fragment,
    monitor,
    collect,
    relocate,
    sample,
    treat,
    maintenance,
  ];

  /// Map of ID to PlannedActionType for quick lookup
  static final Map<String, PlannedActionType> builtins = {
    for (final type in values) type.id: type,
  };

  /// Look up a builtin planned action type by ID
  static PlannedActionType? fromId(String? id) {
    if (id == null) return null;
    return builtins[id];
  }
}
