// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/inventory_hydration/hydration_result.dart';
import 'package:seafoundry_app/services/inventory_hydration/hydration_utils.dart';
import 'package:seafoundry_app/widgets/spreadsheet/inventory/inventory_event_row.dart';

/// Applies fallback values from resolved record info.
///
/// When the primary hydration methods don't fully populate all fields,
/// this function fills in missing values from the resolved record lookup.
ResolvedFallbackResult applyResolvedRecordFallbacks({
  required Event event,
  required ResolvedRecordInfo resolvedRecord,
  required Map<String, Group> groupLookup,
  required Map<String, String> siteLookup,
  required String currentRecordDisplay,
  String? currentRecordName,
  String? currentPhysicalForm,
  String? currentSiteId,
  String? currentSiteName,
  String? currentStructureId,
  String? currentStructureName,
}) {
  var recordDisplay = currentRecordDisplay;
  var recordName = currentRecordName;
  var physicalForm = currentPhysicalForm;
  var siteId = currentSiteId;
  var siteName = currentSiteName;
  var structureId = currentStructureId;
  var structureName = currentStructureName;

  final resolvedOrganism = resolvedRecord.organism;
  if (event.recordModelType == ModelType.organismRecord &&
      resolvedOrganism != null) {
    final resolvedRecordName = resolvedOrganism.recordName.trim();
    if (resolvedRecordName.isNotEmpty) {
      recordDisplay = resolvedRecordName;
      recordName = recordName ?? resolvedRecordName;
    } else if (isDefaultRecordDisplay(recordDisplay, event)) {
      recordDisplay = resolvedRecord.displayName;
    }
  } else if (isDefaultRecordDisplay(recordDisplay, event)) {
    recordDisplay = resolvedRecord.displayName;
  }

  physicalForm ??= resolvedRecord.physicalForm;
  siteId ??= resolvedRecord.siteId;
  if (siteId != null) {
    siteName ??= siteNameForId(siteId, siteLookup);
  }
  structureId ??= resolvedRecord.structureId ?? resolvedRecord.parentGroupId;
  structureName ??= resolvedRecord.structureName;

  final parentGroupId = resolvedRecord.parentGroupId;
  if ((siteName?.isEmpty ?? true) && parentGroupId != null) {
    final parentGroup = groupLookup[parentGroupId];
    siteId ??= parentGroup?.siteId;
    if (siteId != null) {
      siteName = siteNameForId(siteId, siteLookup);
    }
    if (recordDisplay == event.recordId && parentGroup != null) {
      recordDisplay = parentGroup.name;
    }
  }

  return ResolvedFallbackResult(
    recordDisplay: recordDisplay,
    recordName: recordName,
    physicalForm: physicalForm,
    siteId: siteId,
    siteName: siteName,
    structureId: structureId,
    structureName: structureName,
  );
}
