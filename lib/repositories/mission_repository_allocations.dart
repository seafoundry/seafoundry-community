// @tier: community
part of 'mission_repository.dart';

/// Mixin providing allocation-related methods for MissionRepository.
///
/// All allocation mutations use Firestore transactions to prevent lost updates
/// when concurrent users modify allocations simultaneously.
mixin _MissionRepositoryAllocations on _MissionRepositoryBase {
  /// Add an allocation to a mission using a Firestore transaction.
  ///
  /// If an allocation for the same organism already exists, it will be replaced.
  /// Uses transactional read-modify-write to prevent concurrent update conflicts.
  Future<void> addAllocation(
    String missionId,
    MissionAllocation allocation,
  ) async {
    try {
      final docRef = collection.doc(missionId);
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Mission $missionId not found');
        }

        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        final mission = Mission.fromJson(data);
        final updatedMission = mission.addAllocation(allocation);

        transaction.update(docRef, {
          'plannedAllocations':
              updatedMission.plannedAllocations.map((a) => a.toJson()).toList(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });
    } catch (e, stackTrace) {
      logger.error(
        'Failed to add allocation for organism ${allocation.organismId} '
        'to mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Remove an allocation from a mission by organism ID using a Firestore transaction.
  ///
  /// Uses transactional read-modify-write to prevent concurrent update conflicts.
  Future<void> removeAllocation(String missionId, String organismId) async {
    try {
      final docRef = collection.doc(missionId);
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Mission $missionId not found');
        }

        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        final mission = Mission.fromJson(data);
        final updatedMission = mission.removeAllocation(organismId);

        transaction.update(docRef, {
          'plannedAllocations':
              updatedMission.plannedAllocations.map((a) => a.toJson()).toList(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });
    } catch (e, stackTrace) {
      logger.error(
        'Failed to remove allocation for organism $organismId '
        'from mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update all allocations for a mission using a Firestore transaction.
  ///
  /// This replaces all allocations atomically. Uses a transaction to ensure
  /// the mission exists and to provide atomic consistency.
  Future<void> updateAllocations(
    String missionId,
    List<MissionAllocation> allocations,
  ) async {
    try {
      final docRef = collection.doc(missionId);
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Mission $missionId not found');
        }

        transaction.update(docRef, {
          'plannedAllocations': allocations.map((a) => a.toJson()).toList(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });
    } catch (e, stackTrace) {
      logger.error(
        'Failed to update allocations for mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
