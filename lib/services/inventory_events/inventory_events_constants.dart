// @tier: community
import 'package:seafoundry_app/models/types/site_type.dart';

/// Constants for inventory events filtering and resolution.

/// Nursery site type IDs for filtering nursery-related events.
final Set<String> nurserySiteTypeIds = {
  SiteType.nurseryExSitu.id,
  SiteType.nurseryInSitu.id,
};

/// Keys to search for genet local ID in metadata.
const List<String> genetLocalIdKeys = [
  'localId',
  'displayName',
  'name',
  'genetLocalId',
  'genet_local_id',
];

/// Event type IDs that are relevant for the inventory events spreadsheet.
const Set<String> allowedEventTypeIds = {
  'event_create',
  'event_move_in',
  'event_move_out',
  'event_update',
  'event_propagation',
  'event_spawn',
  'event_cross',
  'event_settle',
  'event_size_change',
  'event_life_stage_transition',
  'event_population_gain',
  'event_population_loss',
  'event_coral_size_added',
  'event_coral_size_growth',
  'event_coral_size_tissue_loss',
  'event_status_propagation_ready',
  'event_status_recent_propagation',
  'outplant_event',
};
