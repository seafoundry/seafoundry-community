// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/move_in_event.dart';
import 'package:seafoundry_app/models/events/move_out_event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/services/inventory_event_formatter.dart';
import 'package:seafoundry_app/services/inventory_hydration/hydration_result.dart';
import 'package:seafoundry_app/services/inventory_hydration/hydration_utils.dart';

/// Hydrates [MoveInEvent] and [MoveOutEvent] instances.
///
/// Extracts site, structure, and quantity information from move events
/// and formats human-readable details.
MoveEventResult? hydrateMoveEvent({
  required Event event,
  required Map<String, Group> groupLookup,
  required Map<String, String> siteLookup,
  String? currentSiteId,
  String? currentStructureName,
}) {
  if (event is MoveInEvent) {
    return _hydrateMoveInEvent(
      event: event,
      groupLookup: groupLookup,
      siteLookup: siteLookup,
      currentSiteId: currentSiteId,
      currentStructureName: currentStructureName,
    );
  }

  if (event is MoveOutEvent) {
    return _hydrateMoveOutEvent(
      event: event,
      groupLookup: groupLookup,
      siteLookup: siteLookup,
      currentSiteId: currentSiteId,
      currentStructureName: currentStructureName,
    );
  }

  return null;
}

MoveEventResult _hydrateMoveInEvent({
  required MoveInEvent event,
  required Map<String, Group> groupLookup,
  required Map<String, String> siteLookup,
  String? currentSiteId,
  String? currentStructureName,
}) {
  final fromGroup = groupLookup[event.fromParentId];
  final toGroup = groupLookup[event.toParentId];
  final fromSiteId = siteIdForParent(event.fromParentId, groupLookup);
  final toSiteId = siteIdForParent(event.toParentId, groupLookup);

  final siteId = toSiteId ?? currentSiteId;
  final siteName = siteNameForId(siteId, siteLookup);
  final structureId = toGroup?.id;
  final structureName = toGroup?.name ?? currentStructureName;

  final fromSiteName = siteNameForId(fromSiteId, siteLookup);
  final toSiteName = siteName ?? siteNameForId(toSiteId, siteLookup);
  final details = InventoryEventFormatter.formatMoveDetails(
    fromSiteName: fromSiteName,
    fromStructureName: fromGroup?.name,
    toSiteName: toSiteName,
    toStructureName: toGroup?.name,
  );

  String? quantityDelta;
  final qty = event.quantity;
  if (qty != null) {
    quantityDelta = qty >= 0 ? '+$qty' : qty.toString();
  }

  return MoveEventResult(
    siteId: siteId,
    siteName: siteName,
    structureId: structureId,
    structureName: structureName,
    details: details,
    quantityDelta: quantityDelta,
  );
}

MoveEventResult _hydrateMoveOutEvent({
  required MoveOutEvent event,
  required Map<String, Group> groupLookup,
  required Map<String, String> siteLookup,
  String? currentSiteId,
  String? currentStructureName,
}) {
  final fromGroup = groupLookup[event.fromParentId];
  final toGroup = groupLookup[event.toParentId];
  final fromSiteId = siteIdForParent(event.fromParentId, groupLookup);
  final toSiteId = siteIdForParent(event.toParentId, groupLookup);

  final siteId = fromSiteId ?? currentSiteId;
  final siteName = siteNameForId(siteId, siteLookup);
  final structureId = fromGroup?.id;
  final structureName = fromGroup?.name ?? currentStructureName;

  final fromSiteName = siteName ?? siteNameForId(fromSiteId, siteLookup);
  final toSiteName = siteNameForId(toSiteId, siteLookup);
  final details = InventoryEventFormatter.formatMoveDetails(
    fromSiteName: fromSiteName,
    fromStructureName: fromGroup?.name,
    toSiteName: toSiteName,
    toStructureName: toGroup?.name,
  );

  String? quantityDelta;
  final qty = event.quantity;
  if (qty != null) {
    quantityDelta = qty > 0 ? '-$qty' : qty.toString();
  }

  return MoveEventResult(
    siteId: siteId,
    siteName: siteName,
    structureId: structureId,
    structureName: structureName,
    details: details,
    quantityDelta: quantityDelta,
  );
}
