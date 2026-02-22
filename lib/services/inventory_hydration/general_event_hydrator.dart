// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/events/life_stage_transition_event.dart';
// ignore: unused_import (LifeStageX extension provides displayName)
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/events/move_in_event.dart';
import 'package:seafoundry_app/models/events/move_out_event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/events/propagation/propagation_event.dart';
import 'package:seafoundry_app/models/events/size_change_event.dart';
import 'package:seafoundry_app/models/events/spawn_event.dart';
import 'package:seafoundry_app/models/events/update_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/inventory_event_formatter.dart';
import 'package:seafoundry_app/services/inventory_hydration/hydration_result.dart';

/// Hydrates general (non-move, non-inventory) event types.
///
/// Handles [SizeChangeEvent], [LifeStageTransitionEvent], [PropagationEvent],
/// [SpawnEvent], [OutplantEvent], [ObservationEvent], and [UpdateEvent].
GeneralEventResult? hydrateGeneralEvent({
  required Event event,
  required Map<String, String> siteLookup,
  required OrganismRecord? resolvedOrganism,
  String? currentRecordName,
  String? currentRecordUrlPath,
  String? currentGenetId,
  String? currentRecordDisplay,
}) {
  // Skip if already handled by inventory event or move event hydration
  if (event is InventoryEvent) return null;
  if (event is MoveInEvent || event is MoveOutEvent) return null;

  String? details;
  String? quantityDelta;
  String? recordDisplay = currentRecordDisplay;
  String? recordName = currentRecordName;
  String? recordUrlPath = currentRecordUrlPath;
  String? genetId = currentGenetId;
  String? siteId;
  String? siteName;
  String? structureId;

  if (event is SizeChangeEvent) {
    final result = _hydrateSizeChangeEvent(
      event: event,
      currentRecordName: recordName,
      currentRecordUrlPath: recordUrlPath,
      currentGenetId: genetId,
    );
    details = result.details;
    recordName = result.recordName;
    recordUrlPath = result.recordUrlPath;
    genetId = result.genetId;
    recordDisplay = result.recordDisplay;
    siteId = result.siteId;
    structureId = result.structureId;
  } else if (event is LifeStageTransitionEvent) {
    final result = _hydrateLifeStageEvent(
      event: event,
      currentRecordName: recordName,
      currentRecordUrlPath: recordUrlPath,
      currentGenetId: genetId,
    );
    details = result.details;
    recordName = result.recordName;
    recordUrlPath = result.recordUrlPath;
    genetId = result.genetId;
    recordDisplay = result.recordDisplay;
    siteId = result.siteId;
    structureId = result.structureId;
  } else if (event is PropagationEvent) {
    details = 'Propagated ${event.inputQuantity} -> ${event.outputQuantity}';
    quantityDelta = '+${event.outputQuantity - event.inputQuantity}';
    recordDisplay = event.recordId;
  } else if (event is SpawnEvent) {
    details = 'Gametes recorded: ${event.gameteCount}';
    recordDisplay = event.recordId;
  } else if (event is OutplantEvent) {
    final result = _hydrateOutplantEvent(event: event, siteLookup: siteLookup);
    siteId = result.siteId;
    siteName = result.siteName;
    recordDisplay = result.recordDisplay;
    details = result.details;
    quantityDelta = result.quantityDelta;
  } else if (event is ObservationEvent) {
    details = _hydrateObservationEvent(event);
  } else if (event is UpdateEvent) {
    final updateDisplay = InventoryEventFormatter.formatUpdateDisplay(
      event: event,
      resolvedOrganism: resolvedOrganism,
    );
    details = updateDisplay.details;
    quantityDelta = updateDisplay.quantityDelta;
  } else {
    details = _extractGenericDetails(event);
  }

  return GeneralEventResult(
    details: details,
    quantityDelta: quantityDelta,
    recordDisplay: recordDisplay,
    recordName: recordName,
    recordUrlPath: recordUrlPath,
    genetId: genetId,
    siteId: siteId,
    siteName: siteName,
    structureId: structureId,
  );
}

_SizeChangeResult _hydrateSizeChangeEvent({
  required SizeChangeEvent event,
  String? currentRecordName,
  String? currentRecordUrlPath,
  String? currentGenetId,
}) {
  final oldSize = event.oldSize.sizeClass ?? event.oldSize.sizeBandId;
  final newSize = event.newSize.sizeClass ?? event.newSize.sizeBandId;
  final details = 'Size ${oldSize ?? '-'} -> ${newSize ?? '-'}';

  final recordName =
      currentRecordName ?? event.organismRecordSnapshot.recordName;
  final recordUrlPath =
      currentRecordUrlPath ?? event.organismRecordSnapshot.urlPath;
  final genetId =
      currentGenetId ??
      GenetIdResolver.resolve(event.organismRecordSnapshot);

  final snapshotRecordName = event.organismRecordSnapshot.recordName.trim();
  final recordDisplay =
      snapshotRecordName.isNotEmpty
          ? snapshotRecordName
          : event.organismRecordSnapshot.name;

  return _SizeChangeResult(
    details: details,
    recordName: recordName,
    recordUrlPath: recordUrlPath,
    genetId: genetId,
    recordDisplay: recordDisplay,
    siteId: event.organismRecordSnapshot.siteId,
    structureId: event.organismRecordSnapshot.groupId,
  );
}

_LifeStageResult _hydrateLifeStageEvent({
  required LifeStageTransitionEvent event,
  String? currentRecordName,
  String? currentRecordUrlPath,
  String? currentGenetId,
}) {
  final oldStage = event.oldLifeStage.displayName;
  final newStage = event.newLifeStage.displayName;
  final details = 'Life stage $oldStage -> $newStage';

  final recordName =
      currentRecordName ?? event.organismRecordSnapshot.recordName;
  final recordUrlPath =
      currentRecordUrlPath ?? event.organismRecordSnapshot.urlPath;
  final genetId =
      currentGenetId ??
      GenetIdResolver.resolve(event.organismRecordSnapshot);

  final snapshotRecordName = event.organismRecordSnapshot.recordName.trim();
  final recordDisplay =
      snapshotRecordName.isNotEmpty
          ? snapshotRecordName
          : event.organismRecordSnapshot.name;

  return _LifeStageResult(
    details: details,
    recordName: recordName,
    recordUrlPath: recordUrlPath,
    genetId: genetId,
    recordDisplay: recordDisplay,
    siteId: event.organismRecordSnapshot.siteId,
    structureId: event.organismRecordSnapshot.groupId,
  );
}

_OutplantResult _hydrateOutplantEvent({
  required OutplantEvent event,
  required Map<String, String> siteLookup,
}) {
  final siteId = event.siteId;
  final siteDisplay = siteLookup[siteId] ?? siteId;
  final siteName = siteDisplay;
  final totalQuantity = event.totalQuantity;
  final fragmentsLabel = totalQuantity == 1 ? 'fragment' : 'fragments';
  final recordDisplay = event.name.isNotEmpty ? event.name : siteDisplay;
  var details = '$siteDisplay - $totalQuantity $fragmentsLabel';
  details = InventoryEventFormatter.appendComment(details, event.comment);

  String? quantityDelta;
  if (totalQuantity > 0) {
    quantityDelta = '-$totalQuantity';
  }

  return _OutplantResult(
    siteId: siteId,
    siteName: siteName,
    recordDisplay: recordDisplay,
    details: details,
    quantityDelta: quantityDelta,
  );
}

String _hydrateObservationEvent(ObservationEvent event) {
  final parts = <String>[];
  if (event.isHealthStatusChange) {
    final oldStatus =
        event.oldHealthStatusEnum?.displayName ?? event.oldHealthStatus;
    final newStatus =
        event.newHealthStatusEnum?.displayName ?? event.newHealthStatus;
    parts.add('Health: $oldStatus -> $newStatus');
  }
  if (event.comment != null && event.comment!.isNotEmpty) {
    parts.add(event.comment!);
  }
  return parts.join(' - ');
}

String? _extractGenericDetails(Event event) {
  final json = event.toJson();
  final comment =
      json['comment']?.toString() ??
      json['notes']?.toString() ??
      json['description']?.toString();
  if (comment != null && comment.isNotEmpty) {
    return comment;
  }
  return null;
}

/// Internal result for size change event hydration.
class _SizeChangeResult {
  const _SizeChangeResult({
    this.details,
    this.recordName,
    this.recordUrlPath,
    this.genetId,
    this.recordDisplay,
    this.siteId,
    this.structureId,
  });

  final String? details;
  final String? recordName;
  final String? recordUrlPath;
  final String? genetId;
  final String? recordDisplay;
  final String? siteId;
  final String? structureId;
}

/// Internal result for life stage event hydration.
class _LifeStageResult {
  const _LifeStageResult({
    this.details,
    this.recordName,
    this.recordUrlPath,
    this.genetId,
    this.recordDisplay,
    this.siteId,
    this.structureId,
  });

  final String? details;
  final String? recordName;
  final String? recordUrlPath;
  final String? genetId;
  final String? recordDisplay;
  final String? siteId;
  final String? structureId;
}

/// Internal result for outplant event hydration.
class _OutplantResult {
  const _OutplantResult({
    this.siteId,
    this.siteName,
    this.recordDisplay,
    this.details,
    this.quantityDelta,
  });

  final String? siteId;
  final String? siteName;
  final String? recordDisplay;
  final String? details;
  final String? quantityDelta;
}
