// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';

/// Interface contract for GroupRepository.
///
/// This mirrors the concrete repository API used in production so concrete
/// repositories can implement it and tests can mock it.
abstract class IGroupRepository {
  /// Stream all groups for the organization.
  Stream<List<Group>> get streamAll;

  /// Stream groups for a URL path using client-side filtering.
  Stream<List<Group>> streamRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Stream a single group for a URL path.
  Stream<Group?> streamRecordForUrlPath(String urlPath);

  /// Stream groups for a specific site.
  Stream<List<Group>> groupsForSite(Site site, {bool shallow = false});

  /// Get all groups.
  Future<List<Group>> getAll();

  /// Get a single group by ID.
  Future<Group?> getRecordForId(String id);

  /// Get groups for a URL path.
  Future<List<Group>> getRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Create a new group.
  Future<Group> createRecord(
    Group partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  });

  /// Move a group between parents.
  Future<Group> moveRecord({
    required Group record,
    required GraphNodeRecord fromParent,
    required GraphNodeRecord toParent,
    required Transaction transaction,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Update an existing group.
  Future<void> updateRecord(Group record, {WriteBatch? batch});

  /// Delete a group.
  Future<void> deleteRecord(Group record, {WriteBatch? batch});

  /// Update a group and emit correction events for changes.
  Future<Group> updateGroupWithCorrection({
    required Group originalGroup,
    required Group updatedGroup,
    String? notes,
  });

  /// Find a group by name within a specific site using case-insensitive matching.
  ///
  /// Returns the first matching group or null if not found.
  Future<Group?> findByNameInSite(String siteId, String groupName);
}
