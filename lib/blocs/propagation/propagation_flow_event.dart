// @tier: community
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/models/events/propagation/propagation_ready_event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';

// Data loading events
class PropagationOrganismsLoaded extends RecordFormBaseEvent {
  const PropagationOrganismsLoaded(
    this.organisms,
    this.propagationReadyEvents,
    this.genet,
  );

  final List<OrganismRecord> organisms;
  final List<PropagationReadyStatus> propagationReadyEvents;
  final Genet genet;
}

class PropagationOrganismsLoadFailed extends RecordFormBaseEvent {
  const PropagationOrganismsLoadFailed(this.error);
  final String error;
}

// Step 1: Organism selection events
class PropagationOrganismToggled extends RecordFormBaseEvent {
  const PropagationOrganismToggled(this.organism);
  final OrganismRecord organism;
}

class PropagationOrganismQuantityChanged extends RecordFormBaseEvent {
  const PropagationOrganismQuantityChanged(this.organism, this.quantity);

  final OrganismRecord organism;
  final int quantity;
}

// Step 2: Fragments per input events
class PropagationFragmentsPerInputChanged extends RecordFormInputEvent<int> {
  const PropagationFragmentsPerInputChanged(super.value);
}

// Step 3: Fragment placement events
class PropagationNewOrganismRowAdded extends RecordFormBaseEvent {
  const PropagationNewOrganismRowAdded();
}

class PropagationNewOrganismRowRemoved extends RecordFormBaseEvent {
  const PropagationNewOrganismRowRemoved(this.index);

  final int index;
}

class PropagationNewOrganismQuantityChanged extends RecordFormBaseEvent {
  const PropagationNewOrganismQuantityChanged(this.index, this.quantity);

  final int index;
  final int quantity;
}

class PropagationNewRecordNameChanged extends RecordFormBaseEvent {
  const PropagationNewRecordNameChanged(this.index, this.recordName);

  final int index;
  final String recordName;
}

class PropagationNewOrganismLocationChanged extends RecordFormBaseEvent {
  const PropagationNewOrganismLocationChanged(this.index, this.groupNode);

  final int index;
  final GroupNode groupNode;
}

class PropagationLocationSelectionRequested extends RecordFormBaseEvent {
  const PropagationLocationSelectionRequested(this.index);

  final int index;
}

class PropagationPermitIdChanged extends RecordFormBaseEvent {
  const PropagationPermitIdChanged(this.value);

  final String value;
}

class PropagationPermitTypeChanged extends RecordFormBaseEvent {
  const PropagationPermitTypeChanged(this.value);

  final String value;
}

class PropagationIssuingAuthorityChanged extends RecordFormBaseEvent {
  const PropagationIssuingAuthorityChanged(this.value);

  final String value;
}

class PropagationPermitAttachmentUrlsChanged extends RecordFormBaseEvent {
  const PropagationPermitAttachmentUrlsChanged(this.value);

  final String value;
}

class PropagationPermitValidFromChanged extends RecordFormBaseEvent {
  const PropagationPermitValidFromChanged(this.value);

  final DateTime? value;
}

class PropagationPermitValidToChanged extends RecordFormBaseEvent {
  const PropagationPermitValidToChanged(this.value);

  final DateTime? value;
}

class PropagationFiveAxisChanged extends RecordFormBaseEvent {
  const PropagationFiveAxisChanged({
    required this.selection,
    required this.physicalFormId,
    required this.sizeSpec,
  });

  final ProvenanceLifeStageSelection selection;
  final String physicalFormId;
  final SizeSpec sizeSpec;
}
