// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/events/quantity_change_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';

/// Payload returned after updating an organism's health status.
class OrganismHealthStatusPayload {
  final ObservationEvent event;
  final OrganismRecord updatedRecord;

  const OrganismHealthStatusPayload({
    required this.event,
    required this.updatedRecord,
  });
}

/// Payload returned after updating an organism's size.
class OrganismSizeChangePayload {
  final Event event;
  final OrganismRecord updatedRecord;

  const OrganismSizeChangePayload({
    required this.event,
    required this.updatedRecord,
  });
}

/// Payload returned after updating an organism's population count.
class OrganismPopulationChangePayload {
  final InventoryEvent event;
  final OrganismRecord updatedRecord;

  const OrganismPopulationChangePayload({
    required this.event,
    required this.updatedRecord,
  });
}

/// Payload returned after updating an organism's measurement.
class OrganismQuantityChangePayload {
  final QuantityChangeEvent event;
  final OrganismRecord updatedRecord;

  const OrganismQuantityChangePayload({
    required this.event,
    required this.updatedRecord,
  });
}
