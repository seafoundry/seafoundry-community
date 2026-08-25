import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/group.dart';
import 'package:seafoundry_community/models/model_interfaces.dart';
import 'package:seafoundry_community/models/site.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';
import 'package:seafoundry_community/repositories/record_repository.dart';
import 'package:seafoundry_community/services/logging_service.dart';

/// Utility class for resolving parent nodes and records in structure dialogs.
///
/// This handles the complex logic of resolving parent relationships for
/// group creation and editing, supporting both cases where parent node
/// is provided and where it must be loaded from the record repository.
class ParentResolver {
  ParentResolver._();

  /// Resolves the parent record and node for the group dialog.
  ///
  /// Returns a tuple of (GroupParent, GraphNode) on success, or `null` if
  /// resolution fails. A `null` return indicates the dialog cannot be shown
  /// and the caller should display an appropriate error message.
  ///
  /// **Important:** A `null` return does NOT distinguish between:
  /// - Missing parent data (e.g., empty parentId on existing group)
  /// - Firestore errors during parent lookup
  /// - Parent node not found in graph
  ///
  /// All failure cases are logged before returning `null`. Callers should
  /// treat any `null` return as "unable to load parent" and show an error.
  ///
  /// Resolution logic:
  /// 1. If creating (no existingGroup): parentNode is required, extract its record
  /// 2. If editing: try to use parentNode if it matches, otherwise load from record
  ///
  /// Throws [ArgumentError] if creating a group without a parentNode.
  static Future<(GroupParent, GraphNode)?> resolveParentForGroupDialog({
    required GraphNode? parentNode,
    required Group? existingGroup,
    required RecordRepository recordRepository,
    required GraphRepository graphRepository,
  }) async {
    // Case 1: Creating a new group - parentNode is required
    if (existingGroup == null) {
      if (parentNode == null) {
        throw ArgumentError(
          'parentNode is required when creating a group',
        );
      }
      return (parentNode.initialRecord as GroupParent, parentNode);
    }

    // Case 2: Editing - try to use provided parentNode if it matches
    if (parentNode != null) {
      final parentRecord = parentNode.initialRecord;
      if (parentRecord is GroupParent) {
        final matchesParent =
            parentRecord.id == existingGroup.parentId ||
            (parentRecord is Site && parentRecord.id == existingGroup.siteId);
        if (matchesParent) {
          return (parentRecord, parentNode);
        }
      }
    }

    // Case 3: Editing without matching parentNode - resolve from record
    final groupParent = await _resolveGroupParentForEdit(
      recordRepository: recordRepository,
      existingGroup: existingGroup,
    );

    if (groupParent == null) {
      return null;
    }

    // Load the GraphNode for the resolved parent record
    final resolvedParentNode =
        await graphRepository.getNodeForUrlPath(groupParent.urlPath);

    if (resolvedParentNode == null) {
      LoggingService.instance.error(
        'Failed to load parent node for group edit: ${groupParent.urlPath}',
      );
      return null;
    }

    return (groupParent, resolvedParentNode);
  }

  /// Resolves the parent record for an existing group being edited.
  ///
  /// Returns `null` if the parent cannot be resolved. All failure cases are
  /// logged to maintain consistent error handling:
  /// - Empty parentId: Logged as warning (data integrity issue)
  /// - Firestore errors: Logged as error with stack trace
  ///
  /// Callers should treat `null` as "unable to resolve parent".
  static Future<GroupParent?> _resolveGroupParentForEdit({
    required RecordRepository recordRepository,
    required Group existingGroup,
  }) async {
    try {
      if (existingGroup.parentId.isEmpty) {
        LoggingService.instance.warning(
          'Cannot resolve parent for group edit: parentId is empty '
          '(groupId: ${existingGroup.id})',
        );
        return null;
      }
      if (existingGroup.parentId == existingGroup.siteId) {
        return await recordRepository.getRecord<Site>(
          ModelType.site,
          existingGroup.siteId,
        );
      }
      return await recordRepository.getRecord<Group>(
        ModelType.group,
        existingGroup.parentId,
        organizationId: existingGroup.organizationId,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to resolve parent for group edit '
        '(groupId: ${existingGroup.id}, parentId: ${existingGroup.parentId})',
        error,
        stackTrace,
      );
      return null;
    }
  }
}
