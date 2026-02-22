// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/events/population_gain_event.dart';
import 'package:seafoundry_app/models/events/quantity_change_event.dart';
import 'package:seafoundry_app/models/events/size_change_event.dart';
import 'package:seafoundry_app/models/events/status_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/record.dart';

/// Payload containing an event and optional updated record for propagation
class PropagationPayload<T extends Event, R extends Record> {
  final T event;
  final R? updatedRecord;

  const PropagationPayload({required this.event, this.updatedRecord});
}

/// Specific payload types for common operations (migrated to OrganismRecord)
typedef PopulationChangePayload = PropagationPayload<InventoryEvent, OrganismRecord>;
typedef PopulationGainPayload = PropagationPayload<PopulationGainEvent, OrganismRecord>;

/// Organism-based payload types (multi-organism support)
typedef OrganismHealthStatusPayload = PropagationPayload<ObservationEvent, OrganismRecord>;
typedef OrganismPopulationChangePayload = PropagationPayload<InventoryEvent, OrganismRecord>;
typedef OrganismQuantityChangePayload = PropagationPayload<QuantityChangeEvent, OrganismRecord>;
typedef OrganismPropagationReadyPayload = PropagationPayload<StatusEvent, OrganismRecord>;
typedef OrganismSizeChangePayload = PropagationPayload<SizeChangeEvent, OrganismRecord>;
