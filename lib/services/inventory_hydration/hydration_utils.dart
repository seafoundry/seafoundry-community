// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/group.dart';

/// Utility functions for inventory event hydration.

/// Resolves the site ID for a parent group reference.
///
/// Returns the [Group.siteId] if the parent is found in the lookup,
/// otherwise returns the [parentId] itself as a fallback.
String? siteIdForParent(String? parentId, Map<String, Group> groupLookup) {
  if (parentId == null || parentId.isEmpty) {
    return null;
  }
  final group = groupLookup[parentId];
  if (group != null) {
    return group.siteId;
  }
  return parentId;
}

/// Resolves a site name from its ID using the provided lookup.
///
/// Returns the site name if found, otherwise returns the [siteId] itself.
String? siteNameForId(String? siteId, Map<String, String> siteLookup) {
  if (siteId == null || siteId.isEmpty) {
    return null;
  }
  return siteLookup[siteId] ?? siteId;
}

/// Returns true if the record display is a default placeholder value.
///
/// A default display occurs when:
/// - The display is empty
/// - The display matches the raw record ID
/// - The display is formatted as "ModelType: recordId"
bool isDefaultRecordDisplay(String recordDisplay, Event event) {
  if (recordDisplay.isEmpty) return true;
  if (recordDisplay == event.recordId) return true;
  final modelLabel = event.recordModelType.displayName;
  if (event.recordId.isNotEmpty &&
      recordDisplay == '$modelLabel: ${event.recordId}') {
    return true;
  }
  return false;
}
