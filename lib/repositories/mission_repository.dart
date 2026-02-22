// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/mission.dart';
import 'package:seafoundry_app/models/mission_allocation.dart';
import 'package:seafoundry_app/models/records/archive_metadata.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/stream_cache.dart';

part 'mission_repository_allocations.dart';
part 'mission_repository_deliverables.dart';

/// Base class providing shared resources for mission repository mixins.
abstract class _MissionRepositoryBase {
  FirebaseFirestore get firestore;
  LoggingService get logger;
  CollectionReference<Map<String, dynamic>> get collection;
  Future<Mission?> getMissionById(String missionId);
}

/// Repository for managing mission records
class MissionRepository extends _MissionRepositoryBase
    with _MissionRepositoryDeliverables, _MissionRepositoryAllocations {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  // Stream caches to prevent duplicate Firestore subscriptions
  final _missionsForOrgCache = StreamCache<String, List<Mission>>();
  final _missionsInRangeCache = StreamCache<({String orgId, DateTime start, DateTime end}), List<Mission>>();

  MissionRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  })  : _firestore = firestore,
        _logger = logger ?? LoggingService.instance;

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  LoggingService get logger => _logger;

  @override
  CollectionReference<Map<String, dynamic>> get collection =>
      _resolver.collection(_firestore, ModelType.mission.collectionPath);

  CollectionReference<Map<String, dynamic>> get _collection => collection;

  bool _isArchivedMission(Mission mission) {
    final metadata = mission.metadata;
    return metadata?[kArchivedFlagKey] == true ||
        metadata?['isDeleted'] == true;
  }

  /// Watch missions for an organization
  Stream<List<Mission>> watchMissionsForOrg(String orgId) {
    // Cache streams by orgId to prevent duplicate Firestore subscriptions
    // StreamCache handles broadcast support and lazy subscription lifecycle
    return _missionsForOrgCache.getOrCreate(orgId, () {
      try {
        // Avoid orderBy to prevent composite index requirements - sort in-memory
        return _collection
            .where('organizationId', isEqualTo: orgId)
            .snapshots()
            .map((snapshot) {
          final missions = <Mission>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              data['id'] = doc.id;
              final mission = Mission.fromJson(data);
              if (_isArchivedMission(mission)) {
                continue;
              }
              missions.add(mission);
            } catch (e) {
              _logger.warning(
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
        _logger.error(
          'Failed to watch missions for org $orgId',
          e,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  /// Alias for watchMissionsForOrg
  Stream<List<Mission>> watchMissions(String orgId) => watchMissionsForOrg(orgId);

  /// Watch a single mission by ID
  Stream<Mission?> watchMission(String missionId) {
    return _collection.doc(missionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      data['id'] = doc.id;
      final mission = Mission.fromJson(data);
      if (_isArchivedMission(mission)) return null;
      return mission;
    });
  }

  /// Watch missions for a date range
  Stream<List<Mission>> watchMissionsInRange(
    String orgId,
    DateTime start,
    DateTime end,
  ) {
    // Normalize DateTimes to date-only (midnight UTC) to prevent cache misses
    // from microsecond-level differences in DateTime construction
    final normalizedStart = DateTime.utc(start.year, start.month, start.day);
    final normalizedEnd = DateTime.utc(end.year, end.month, end.day, 23, 59, 59);

    // Cache streams using type-safe Dart record key with normalized dates
    final cacheKey = (orgId: orgId, start: normalizedStart, end: normalizedEnd);
    return _missionsInRangeCache.getOrCreate(cacheKey, () {
      try {
        // Avoid orderBy to prevent composite index requirements - sort in-memory
        return _collection
            .where('organizationId', isEqualTo: orgId)
            .where(
              'scheduledDate',
              isGreaterThanOrEqualTo: normalizedStart.toIso8601String(),
            )
            .where('scheduledDate', isLessThanOrEqualTo: normalizedEnd.toIso8601String())
            .snapshots()
            .map((snapshot) {
          final missions = <Mission>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              data['id'] = doc.id;
              final mission = Mission.fromJson(data);
              if (_isArchivedMission(mission)) {
                continue;
              }
              missions.add(mission);
            } catch (e) {
              _logger.warning(
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
        _logger.error(
          'Failed to watch missions in range for org $orgId',
          e,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  /// Get upcoming missions
  Future<List<Mission>> getUpcomingMissions(
    String orgId, {
    int limit = 10,
  }) async {
    try {
      final now = DateTime.now();
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('scheduledDate', isGreaterThanOrEqualTo: now.toIso8601String())
          .orderBy('scheduledDate', descending: false)
          .limit(limit)
          .get();

      final missions = <Mission>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final mission = Mission.fromJson(data);
          if (_isArchivedMission(mission)) {
            continue;
          }
          missions.add(mission);
        } catch (e) {
          _logger.warning(
            'Failed to parse mission ${doc.id}: $e',
            e,
          );
        }
      }
      return missions;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get upcoming missions for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a mission by ID
  @override
  Future<Mission?> getMissionById(String missionId) async {
    try {
      final doc = await _collection.doc(missionId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      data['id'] = doc.id;
      final mission = Mission.fromJson(data);
      if (_isArchivedMission(mission)) return null;
      return mission;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new mission
  Future<String> createMission(Mission mission) async {
    try {
      // Generate doc ID first so validation passes (Record.validate requires non-empty id)
      final docId = mission.id.isNotEmpty ? mission.id : _collection.doc().id;
      final missionWithId = mission.copyWith(id: docId);

      if (!missionWithId.validate()) {
        throw ArgumentError('Invalid mission data');
      }

      await _collection.doc(docId).set(missionWithId.toJson());
      return docId;
    } catch (e, stackTrace) {
      _logger.error('Failed to create mission', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing mission
  Future<void> updateMission(Mission mission) async {
    try {
      if (!mission.validate()) {
        throw ArgumentError('Invalid mission data');
      }

      await _collection.doc(mission.id).update(mission.toJson());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update mission ${mission.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a mission
  Future<void> deleteMission(String missionId) async {
    try {
      await archiveMission(missionId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Archive a mission (keeps it in the active collection but marks it archived).
  Future<void> archiveMission(
    String missionId, {
    String? archivedById,
    String? comment,
  }) async {
    final mission = await getMissionById(missionId);
    if (mission == null) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final metadata = <String, dynamic>{
      ...mission.metadata ?? const {},
      kArchivedFlagKey: true,
      kArchivedAtKey: now,
      kArchivedByIdKey: archivedById ?? mission.updatedById,
      kArchivedReasonTypeKey: kArchiveReasonTypeDeleted,
      if (comment != null) 'archiveComment': comment,
    };

    final archivedMission = mission.copyWith(
      metadata: metadata,
      updatedAt: now,
      updatedById: archivedById ?? mission.updatedById,
    );

    final payload = archivedMission.toJson();
    payload.remove('createdById');

    final batch = _firestore.batch();
    batch.update(_collection.doc(mission.id), payload);
    await batch.commit();
  }

  /// Update mission status
  Future<void> updateMissionStatus(
    String missionId,
    MissionStatus status,
  ) async {
    try {
      await _collection.doc(missionId).update({
        'statusId': status.id,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update mission status for $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Add a task to a mission
  Future<void> addTaskToMission(String missionId, String taskId) async {
    try {
      final mission = await getMissionById(missionId);
      if (mission == null) {
        throw StateError('Mission $missionId not found');
      }

      if (mission.taskIds.contains(taskId)) {
        return; // Task already linked
      }

      await _collection.doc(missionId).update({
        'taskIds': FieldValue.arrayUnion([taskId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to add task $taskId to mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Remove a task from a mission
  Future<void> removeTaskFromMission(String missionId, String taskId) async {
    try {
      await _collection.doc(missionId).update({
        'taskIds': FieldValue.arrayRemove([taskId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to remove task $taskId from mission $missionId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get missions for a specific site
  Future<List<Mission>> getMissionsForSite(
    String orgId,
    String siteId, {
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('siteIds', arrayContains: siteId)
          .orderBy('scheduledDate', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final missions = <Mission>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final mission = Mission.fromJson(data);
          if (_isArchivedMission(mission)) {
            continue;
          }
          missions.add(mission);
        } catch (e) {
          _logger.warning(
            'Failed to parse mission ${doc.id}: $e',
            e,
          );
        }
      }
      return missions;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get missions for site $siteId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get missions assigned to a specific crew member
  Future<List<Mission>> getMissionsForCrewMember(
    String orgId,
    String userId, {
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('crewUserIds', arrayContains: userId)
          .orderBy('scheduledDate', descending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final missions = <Mission>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final mission = Mission.fromJson(data);
          if (_isArchivedMission(mission)) {
            continue;
          }
          missions.add(mission);
        } catch (e) {
          _logger.warning(
            'Failed to parse mission ${doc.id}: $e',
            e,
          );
        }
      }
      return missions;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get missions for crew member $userId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get missions by status
  Future<List<Mission>> getMissionsByStatus(
    String orgId,
    MissionStatus status, {
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('statusId', isEqualTo: status.id)
          .orderBy('scheduledDate', descending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final missions = <Mission>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final mission = Mission.fromJson(data);
          if (_isArchivedMission(mission)) {
            continue;
          }
          missions.add(mission);
        } catch (e) {
          _logger.warning(
            'Failed to parse mission ${doc.id}: $e',
            e,
          );
        }
      }
      return missions;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get missions by status ${status.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get missions for a specific vessel
  Future<List<Mission>> getMissionsForVessel(
    String orgId,
    String vesselId, {
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('vesselId', isEqualTo: vesselId)
          .orderBy('scheduledDate', descending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final missions = <Mission>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final mission = Mission.fromJson(data);
          if (_isArchivedMission(mission)) {
            continue;
          }
          missions.add(mission);
        } catch (e) {
          _logger.warning(
            'Failed to parse mission ${doc.id}: $e',
            e,
          );
        }
      }
      return missions;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get missions for vessel $vesselId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Dispose the repository and clean up stream caches
  void dispose() {
    _missionsForOrgCache.dispose();
    _missionsInRangeCache.dispose();
  }

  /// Get missions for a vessel within a date range
  Future<List<Mission>> getMissionsForVesselInRange(
    String orgId,
    String vesselId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('vesselId', isEqualTo: vesselId)
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: start.toIso8601String(),
          )
          .where('scheduledDate', isLessThanOrEqualTo: end.toIso8601String())
          .orderBy('scheduledDate', descending: false)
          .get();

      final missions = <Mission>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final mission = Mission.fromJson(data);
          if (_isArchivedMission(mission)) {
            continue;
          }
          missions.add(mission);
        } catch (e) {
          _logger.warning(
            'Failed to parse mission ${doc.id}: $e',
            e,
          );
        }
      }
      return missions;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get missions for vessel $vesselId in range',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
