// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/operations/vessel.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/stream_cache.dart';

/// Repository for managing vessel records
class VesselRepository {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  // Stream cache to prevent duplicate Firestore subscriptions
  final _vesselsForOrgCache = StreamCache<String, List<Vessel>>();

  VesselRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  })  : _firestore = firestore,
        _logger = logger ?? LoggingService.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, ModelType.vessel.collectionPath);

  /// Watch vessels for an organization
  Stream<List<Vessel>> watchVesselsForOrg(String orgId) {
    // Cache streams by orgId to prevent duplicate Firestore subscriptions
    // StreamCache handles broadcast support and lazy subscription lifecycle
    return _vesselsForOrgCache.getOrCreate(orgId, () {
      try {
        // Avoid orderBy to prevent composite index requirements - sort in-memory
        return _collection
            .where('organizationId', isEqualTo: orgId)
            .snapshots()
            .map((snapshot) {
          final vessels = <Vessel>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              data['id'] = doc.id;
              vessels.add(Vessel.fromJson(data));
            } catch (e) {
              _logger.warning(
                'Failed to parse vessel ${doc.id}: $e',
                e,
              );
            }
          }
          // Sort in-memory by name ascending (alphabetically)
          vessels.sort((a, b) => a.name.compareTo(b.name));
          return vessels;
        });
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to watch vessels for org $orgId',
          e,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  /// Get all vessels for an organization
  Future<List<Vessel>> getVesselsForOrg(String orgId) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .orderBy('name', descending: false)
          .get();

      final vessels = <Vessel>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          vessels.add(Vessel.fromJson(data));
        } catch (e) {
          _logger.warning(
            'Failed to parse vessel ${doc.id}: $e',
            e,
          );
        }
      }
      return vessels;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get vessels for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get vessels by status
  Future<List<Vessel>> getVesselsByStatus(
    String orgId,
    VesselStatus status,
  ) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('statusId', isEqualTo: status.id)
          .orderBy('name', descending: false)
          .get();

      final vessels = <Vessel>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          vessels.add(Vessel.fromJson(data));
        } catch (e) {
          _logger.warning(
            'Failed to parse vessel ${doc.id}: $e',
            e,
          );
        }
      }
      return vessels;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get vessels by status ${status.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a vessel by ID
  Future<Vessel?> getVesselById(String vesselId) async {
    try {
      final doc = await _collection.doc(vesselId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      data['id'] = doc.id;
      return Vessel.fromJson(data);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get vessel $vesselId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new vessel
  Future<String> createVessel(Vessel vessel) async {
    try {
      final needsId = vessel.id.isEmpty || vessel.id == '__missing__';
      final docRef = needsId ? _collection.doc() : _collection.doc(vessel.id);
      final vesselToSave =
          needsId ? vessel.copyWith(id: docRef.id) : vessel;

      if (!vesselToSave.validate()) {
        throw ArgumentError('Invalid vessel data');
      }

      await docRef.set(vesselToSave.toJson());
      return docRef.id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create vessel', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing vessel
  Future<void> updateVessel(Vessel vessel) async {
    try {
      if (!vessel.validate()) {
        throw ArgumentError('Invalid vessel data');
      }

      await _collection.doc(vessel.id).update(vessel.toJson());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update vessel ${vessel.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a vessel
  Future<void> deleteVessel(String vesselId) async {
    try {
      await _collection.doc(vesselId).delete();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete vessel $vesselId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update vessel status
  Future<void> updateVesselStatus(
    String vesselId,
    VesselStatus status,
  ) async {
    try {
      await _collection.doc(vesselId).update({
        'statusId': status.id,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update vessel status for $vesselId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get vessels by home port
  Future<List<Vessel>> getVesselsByHomePort(
    String orgId,
    String siteId,
  ) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('homePortSiteId', isEqualTo: siteId)
          .orderBy('name', descending: false)
          .get();

      final vessels = <Vessel>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          vessels.add(Vessel.fromJson(data));
        } catch (e) {
          _logger.warning(
            'Failed to parse vessel ${doc.id}: $e',
            e,
          );
        }
      }
      return vessels;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get vessels by home port $siteId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get vessels with a specific capability
  Future<List<Vessel>> getVesselsByCapability(
    String orgId,
    String capability,
  ) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('capabilities', arrayContains: capability)
          .orderBy('name', descending: false)
          .get();

      final vessels = <Vessel>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          vessels.add(Vessel.fromJson(data));
        } catch (e) {
          _logger.warning(
            'Failed to parse vessel ${doc.id}: $e',
            e,
          );
        }
      }
      return vessels;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get vessels by capability $capability',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get vessels with minimum crew capacity
  Future<List<Vessel>> getVesselsByMinCrewCapacity(
    String orgId,
    int minCapacity,
  ) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('crewCapacity', isGreaterThanOrEqualTo: minCapacity)
          .orderBy('crewCapacity', descending: false)
          .get();

      final vessels = <Vessel>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          vessels.add(Vessel.fromJson(data));
        } catch (e) {
          _logger.warning(
            'Failed to parse vessel ${doc.id}: $e',
            e,
          );
        }
      }
      return vessels;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get vessels by min crew capacity $minCapacity',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Dispose the repository and clean up stream caches
  void dispose() {
    _vesselsForOrgCache.dispose();
  }
}
