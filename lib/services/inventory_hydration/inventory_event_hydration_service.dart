// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/inventory_event_formatter.dart';
import 'package:seafoundry_app/services/inventory_hydration/general_event_hydrator.dart';
import 'package:seafoundry_app/services/inventory_hydration/hydration_utils.dart';
import 'package:seafoundry_app/services/inventory_hydration/inventory_event_hydrator.dart';
import 'package:seafoundry_app/services/inventory_hydration/move_event_hydrator.dart';
import 'package:seafoundry_app/services/inventory_hydration/resolved_record_fallback.dart';
import 'package:seafoundry_app/services/location_display_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/inventory/inventory_event_row.dart';

/// Service for hydrating [Event] objects into [InventoryEventRow] instances.
///
/// Encapsulates all the resolution logic for sites, groups, organisms, genets,
/// and user names needed to render inventory event spreadsheet rows.
class InventoryEventHydrationService {
  const InventoryEventHydrationService();

  /// Hydrates a Firestore event with resolved metadata (site, structure, user)
  /// so that we can render a single row in the spreadsheet.
  Future<InventoryEventRow?> hydrateEvent({
    required Event event,
    required Map<String, Group> groupLookup,
    required Map<String, String> siteLookup,
    required Map<String, String> eventTypeLabels,
    required Future<String> Function(String) resolveUserName,
    required Future<ResolvedRecordInfo?> Function(ModelType?, String?)
        resolveRecordReference,
    required OrganismKind organismKind,
    String? organizationDomain,
  }) async {
    final createdAt = DateTime.tryParse(event.createdAt);
    final permit = event.permitMetadata;
    final permitSummary = InventoryEventFormatter.formatPermitSummary(permit);
    final permitWindow = InventoryEventFormatter.formatPermitWindow(permit);

    String? siteId;
    String? siteName;
    String? structureId;
    String? structureName;
    String recordDisplay = event.recordId;
    String? recordName;
    String? recordUrlPath;
    String? genetId;
    String? quantityDelta;
    String details = '';

    final resolvedRecord = await resolveRecordReference(
      event.recordModelType,
      event.recordId,
    );
    final resolvedOrganism = resolvedRecord?.organism;
    final genetLocalId = resolvedRecord?.genetLocalId;

    if (resolvedOrganism != null) {
      recordName = resolvedOrganism.recordName;
      recordUrlPath = resolvedOrganism.urlPath;
      genetId = GenetIdResolver.resolve(resolvedOrganism);
    }

    // Hydrate move events
    final moveResult = hydrateMoveEvent(
      event: event,
      groupLookup: groupLookup,
      siteLookup: siteLookup,
      currentSiteId: siteId,
      currentStructureName: structureName,
    );
    if (moveResult != null) {
      siteId = moveResult.siteId ?? siteId;
      siteName = moveResult.siteName;
      structureId = moveResult.structureId;
      structureName = moveResult.structureName ?? structureName;
      details = moveResult.details;
      quantityDelta = moveResult.quantityDelta;
    }

    String? physicalForm;

    // Hydrate inventory events with snapshots
    final inventoryResult = hydrateInventoryEvent(
      event: event,
      groupLookup: groupLookup,
      siteLookup: siteLookup,
      currentRecordName: recordName,
      currentRecordUrlPath: recordUrlPath,
      currentGenetId: genetId,
      currentRecordDisplay: recordDisplay,
      currentStructureName: structureName,
    );
    if (inventoryResult != null) {
      recordName = inventoryResult.recordName ?? recordName;
      recordUrlPath = inventoryResult.recordUrlPath ?? recordUrlPath;
      genetId = inventoryResult.genetId ?? genetId;
      recordDisplay = inventoryResult.recordDisplay ?? recordDisplay;
      physicalForm = inventoryResult.physicalForm;
      siteId = inventoryResult.siteId ?? siteId;
      siteName = inventoryResult.siteName ?? siteName;
      structureId = inventoryResult.structureId ?? structureId;
      structureName = inventoryResult.structureName ?? structureName;
      details = inventoryResult.details ?? details;
      quantityDelta = inventoryResult.quantityDelta ?? quantityDelta;
    }

    // Hydrate non-inventory event types
    final generalResult = hydrateGeneralEvent(
      event: event,
      siteLookup: siteLookup,
      resolvedOrganism: resolvedOrganism,
      currentRecordName: recordName,
      currentRecordUrlPath: recordUrlPath,
      currentGenetId: genetId,
      currentRecordDisplay: recordDisplay,
    );
    if (generalResult != null) {
      details = generalResult.details ?? details;
      quantityDelta = generalResult.quantityDelta ?? quantityDelta;
      recordDisplay = generalResult.recordDisplay ?? recordDisplay;
      recordName = generalResult.recordName ?? recordName;
      recordUrlPath = generalResult.recordUrlPath ?? recordUrlPath;
      genetId = generalResult.genetId ?? genetId;
      siteId = generalResult.siteId ?? siteId;
      siteName = generalResult.siteName ?? siteName;
      structureId = generalResult.structureId ?? structureId;
    }

    siteName ??= siteNameForId(siteId, siteLookup);

    // Resolve group records
    if (siteName == null && event.recordModelType == ModelType.group) {
      final group = groupLookup[event.recordId];
      siteId = group?.siteId;
      siteName = siteNameForId(siteId, siteLookup);
      structureId ??= group?.id;
      structureName ??= group?.name;
      recordDisplay = group?.name ?? recordDisplay;
    }

    // Apply resolved record fallbacks
    if (resolvedRecord != null) {
      final resolved = applyResolvedRecordFallbacks(
        event: event,
        resolvedRecord: resolvedRecord,
        groupLookup: groupLookup,
        siteLookup: siteLookup,
        currentRecordDisplay: recordDisplay,
        currentRecordName: recordName,
        currentPhysicalForm: physicalForm,
        currentSiteId: siteId,
        currentSiteName: siteName,
        currentStructureId: structureId,
        currentStructureName: structureName,
      );
      recordDisplay = resolved.recordDisplay;
      recordName = resolved.recordName ?? recordName;
      physicalForm = resolved.physicalForm ?? physicalForm;
      siteId = resolved.siteId ?? siteId;
      siteName = resolved.siteName ?? siteName;
      structureId = resolved.structureId ?? structureId;
      structureName = resolved.structureName ?? structureName;
    }

    final locationPath = LocationDisplayService.formatFromEvent(
      event,
      organizationDomain: organizationDomain,
      fallback: siteName ?? siteId,
    );

    final eventType = event.eventTypeId;
    final userName = await resolveUserName(event.createdById);
    final eventLabel = eventTypeLabels[eventType] ?? eventType;

    return InventoryEventRow(
      eventId: event.id,
      eventTypeId: eventType,
      eventLabel: eventLabel,
      recordId: event.recordId,
      recordModelType: event.recordModelType,
      recordDisplay: recordDisplay,
      recordName: recordName,
      recordUrlPath: recordUrlPath,
      genetLocalId: genetLocalId,
      genetId: genetId,
      createdAt: createdAt,
      userName: userName,
      details: details,
      quantityDelta: quantityDelta,
      siteId: siteId,
      siteName: siteName,
      locationPath: locationPath,
      structureId: structureId,
      structureName: structureName,
      organismKind: organismKind,
      physicalForm: physicalForm,
      permitSummary: permitSummary,
      permitAuthority: permit.issuingAuthority ?? '',
      permitWindow: permitWindow,
      hasPermitMetadata: !permit.isEmpty,
    );
  }
}
