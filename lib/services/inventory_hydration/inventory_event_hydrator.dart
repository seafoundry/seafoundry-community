// @tier: community
import 'package:seafoundry_app/models/events/coral_size_event.dart';
import 'package:seafoundry_app/models/events/create_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/events/population_gain_event.dart';
import 'package:seafoundry_app/models/events/population_loss_event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/population_gain_reason.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/inventory_event_formatter.dart';
import 'package:seafoundry_app/services/inventory_hydration/hydration_result.dart';
import 'package:seafoundry_app/widgets/spreadsheet/inventory/inventory_event_row.dart';

/// Hydrates [InventoryEvent] subclasses with snapshot data.
///
/// Handles [PopulationGainEvent], [PopulationLossEvent], [CoralSizeEvent],
/// and [CreateEvent] by extracting record info from their embedded snapshots.
InventoryEventResult? hydrateInventoryEvent({
  required Event event,
  required Map<String, Group> groupLookup,
  required Map<String, String> siteLookup,
  String? currentRecordName,
  String? currentRecordUrlPath,
  String? currentGenetId,
  String? currentRecordDisplay,
  String? currentStructureName,
}) {
  if (event is! InventoryEvent) return null;

  final snapshot = event.snapshot;
  String? recordName = currentRecordName;
  String? recordUrlPath = currentRecordUrlPath;
  String? genetId = currentGenetId;
  String? recordDisplay = currentRecordDisplay;
  String? physicalForm;
  String? siteId;
  String? siteName;
  String? structureId;
  String? structureName = currentStructureName;
  String? details;
  String? quantityDelta;

  if (snapshot is OrganismRecord) {
    final result = _hydrateOrganismSnapshot(
      snapshot: snapshot,
      groupLookup: groupLookup,
      siteLookup: siteLookup,
      currentRecordName: recordName,
      currentRecordUrlPath: recordUrlPath,
      currentGenetId: genetId,
      currentStructureName: structureName,
    );
    recordName = result.recordName;
    recordUrlPath = result.recordUrlPath;
    genetId = result.genetId;
    recordDisplay = result.recordDisplay;
    physicalForm = result.physicalForm;
    siteId = result.siteId;
    siteName = result.siteName;
    structureId = result.structureId;
    structureName = result.structureName;
  } else if (snapshot is Group) {
    recordDisplay = snapshot.name;
    siteId = snapshot.siteId;
    siteName = siteLookup[siteId] ?? siteId;
    structureId = snapshot.id;
    structureName = snapshot.name;
  } else if (snapshot is Site) {
    recordDisplay = snapshot.name;
    siteId = snapshot.id;
    siteName = siteLookup[siteId] ?? snapshot.name;
  }

  // Event-specific details
  final eventDetails = _extractEventDetails(event);
  details = eventDetails.details;
  quantityDelta = eventDetails.quantityDelta;

  return InventoryEventResult(
    recordName: recordName,
    recordUrlPath: recordUrlPath,
    genetId: genetId,
    recordDisplay: recordDisplay,
    physicalForm: physicalForm,
    siteId: siteId,
    siteName: siteName,
    structureId: structureId,
    structureName: structureName,
    details: details,
    quantityDelta: quantityDelta,
  );
}

/// Hydrates an organism record snapshot.
_OrganismSnapshotResult _hydrateOrganismSnapshot({
  required OrganismRecord snapshot,
  required Map<String, Group> groupLookup,
  required Map<String, String> siteLookup,
  String? currentRecordName,
  String? currentRecordUrlPath,
  String? currentGenetId,
  String? currentStructureName,
}) {
  final formId = snapshot.physicalForm?.formId;

  final recordName = currentRecordName ?? snapshot.recordName;
  final recordUrlPath = currentRecordUrlPath ?? snapshot.urlPath;
  final genetId =
      currentGenetId ??
      GenetIdResolver.resolve(snapshot);

  final snapshotRecordName = snapshot.recordName.trim();
  final recordDisplay =
      snapshotRecordName.isNotEmpty ? snapshotRecordName : snapshot.name;

  final siteId = snapshot.siteId;
  final siteName = siteLookup[siteId] ?? siteId;
  final structureId = snapshot.groupId;
  final structureName =
      groupLookup[snapshot.groupId]?.name ?? currentStructureName;

  return _OrganismSnapshotResult(
    recordName: recordName,
    recordUrlPath: recordUrlPath,
    genetId: genetId,
    recordDisplay: recordDisplay,
    physicalForm: formId,
    siteId: siteId,
    siteName: siteName,
    structureId: structureId,
    structureName: structureName,
  );
}

/// Extracts event-specific details and quantity delta.
_EventDetailsResult _extractEventDetails(InventoryEvent event) {
  String? details;
  String? quantityDelta;

  if (event is PopulationGainEvent) {
    final delta = event.delta;
    final label =
        PopulationGainReason.builtins[event.gainReasonId]?.name ??
        event.gainReasonId;
    details =
        'Population ${event.oldPopulation} -> ${event.newPopulation} '
        '(${delta >= 0 ? '+' : ''}$delta)${InventoryEventRow.labelSuffix(label)}';
    quantityDelta = delta >= 0 ? '+$delta' : delta.toString();
    details = InventoryEventFormatter.appendComment(details, event.comment);
  } else if (event is PopulationLossEvent) {
    final delta = event.delta;
    final label =
        PopulationLossReason.builtins[event.lossReasonId]?.name ??
        event.lossReasonId;
    details =
        'Population ${event.oldPopulation} -> ${event.newPopulation} '
        '(${delta >= 0 ? '+' : ''}$delta)${InventoryEventRow.labelSuffix(label)}';
    quantityDelta = delta.toString();
    details = InventoryEventFormatter.appendComment(details, event.comment);
  } else if (event is CoralSizeEvent) {
    final oldSize = event.oldSize?.name.toUpperCase() ?? '-';
    final newSize = event.newSize.name.toUpperCase();
    details = 'Size $oldSize -> $newSize';
    if (event.comment != null && event.comment!.isNotEmpty) {
      details = '$details - ${event.comment}';
    }
  } else if (event is CreateEvent) {
    details = 'Created ${event.recordModelType.displayName}'.trim();
  } else {
    details = event.toJson()['comment']?.toString() ?? '';
  }

  return _EventDetailsResult(details: details, quantityDelta: quantityDelta);
}

/// Internal result for organism snapshot hydration.
class _OrganismSnapshotResult {
  const _OrganismSnapshotResult({
    this.recordName,
    this.recordUrlPath,
    this.genetId,
    this.recordDisplay,
    this.physicalForm,
    this.siteId,
    this.siteName,
    this.structureId,
    this.structureName,
  });

  final String? recordName;
  final String? recordUrlPath;
  final String? genetId;
  final String? recordDisplay;
  final String? physicalForm;
  final String? siteId;
  final String? siteName;
  final String? structureId;
  final String? structureName;
}

/// Internal result for event details extraction.
class _EventDetailsResult {
  const _EventDetailsResult({this.details, this.quantityDelta});

  final String? details;
  final String? quantityDelta;
}
