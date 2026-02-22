// @tier: community
part of 'mission_repository.dart';

/// Mixin providing deliverable-related methods for MissionRepository.
///
/// Deliverable link/unlink operations use Firestore's atomic array operations
/// (arrayUnion/arrayRemove) to prevent lost updates with concurrent modifications.
mixin _MissionRepositoryDeliverables on _MissionRepositoryBase {
  /// Link a deliverable to a mission using atomic arrayUnion.
  ///
  /// Uses FieldValue.arrayUnion for atomic, idempotent addition that is safe
  /// for concurrent operations. No pre-read is needed since arrayUnion
  /// automatically handles duplicates.
  ///
  /// Throws [StateError] if the mission does not exist.
  Future<void> linkDeliverable(String missionId, String deliverableId) async {
    try {
      await collection.doc(missionId).update({
        'deliverableIds': FieldValue.arrayUnion([deliverableId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e, stackTrace) {
      // Convert not-found errors to StateError for API consistency
      if (e.code == 'not-found') {
        logger.error(
          'Mission $missionId not found when linking deliverable $deliverableId',
          e,
          stackTrace,
        );
        throw StateError('Mission $missionId not found');
      }
      logger.error(
        'Failed to link deliverable $deliverableId to mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to link deliverable $deliverableId to mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Unlink a deliverable from a mission using atomic arrayRemove.
  ///
  /// Uses FieldValue.arrayRemove for atomic, idempotent removal that is safe
  /// for concurrent operations.
  Future<void> unlinkDeliverable(String missionId, String deliverableId) async {
    try {
      await collection.doc(missionId).update({
        'deliverableIds': FieldValue.arrayRemove([deliverableId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      logger.error(
        'Failed to unlink deliverable $deliverableId from mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Watch missions that are linked to a specific deliverable
  Stream<List<Mission>> getMissionsForDeliverable(String deliverableId) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return collection
          .where('deliverableIds', arrayContains: deliverableId)
          .snapshots()
          .map((snapshot) {
        final missions = <Mission>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            missions.add(Mission.fromJson(data));
          } catch (e) {
            logger.warning(
              'Failed to parse mission ${doc.id}: $e',
              e,
            );
          }
        }
        // Sort by scheduledDate ascending (soonest first)
        missions.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        return missions;
      });
    } catch (e, stackTrace) {
      logger.error(
        'Failed to get missions for deliverable $deliverableId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
