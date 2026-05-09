part of 'inventory_events_table.dart';

/// Default event types for inventory events.
const Set<String> _defaultInventoryEventTypes = {
  'event_create',
  'event_update',
  'event_quantity_change',
  'event_split',
  'event_merge',
  'event_move_in',
  'event_move_out',
  'event_population_loss',
  'event_population_gain',
  'event_life_stage_transition',
  'event_physical_form_change',
};

/// Event types for outplanting events.
const Set<String> _outplantingEventTypes = {
  'outplant_event',
  'event_create',
};

/// Event label overrides for display.
const Map<String, String> _inventoryEventLabels = {
  'event_create': 'Created',
  'event_update': 'Updated',
  'event_quantity_change': 'Quantity Change',
  'event_split': 'Split',
  'event_merge': 'Merge',
  'event_move_in': 'Move In',
  'event_move_out': 'Move Out',
  'event_population_loss': 'Population Loss',
  'event_population_gain': 'Population Gain',
  'event_life_stage_transition': 'Life Stage Transition',
  'event_physical_form_change': 'Physical Form Change',
  'outplant_event': 'Outplant',
};

class _InventoryEventCandidate {
  const _InventoryEventCandidate(this.event, this.eventTypeId);

  final Event event;
  final String eventTypeId;
}

/// A hydrated row representing an inventory event for spreadsheet display.
class _InventoryEventRow {
  const _InventoryEventRow({
    required this.eventId,
    required this.eventTypeId,
    required this.eventLabel,
    required this.recordDisplay,
    required this.genetLocalId,
    required this.details,
    required this.siteName,
    required this.userName,
    required this.createdAt,
  });

  final String eventId;
  final String eventTypeId;
  final String eventLabel;
  final String recordDisplay;
  final String genetLocalId;
  final String details;
  final String siteName;
  final String userName;
  final DateTime? createdAt;
}
