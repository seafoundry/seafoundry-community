// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for managing permit records
class PermitRepository {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  PermitRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  }) : _firestore = firestore,
       _logger = logger ?? LoggingService.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, ModelType.permit.collectionPath);

  /// Watch permits for an organization
  Stream<List<Permit>> watchPermitsForOrg(String orgId) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _collection
          .where('organizationId', isEqualTo: orgId)
          .snapshots()
          .map((snapshot) {
            final permits = <Permit>[];
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                permits.add(Permit.fromJson(data));
              } catch (e) {
                _logger.warning('Failed to parse permit ${doc.id}: $e', e);
              }
            }
            // Sort by validTo ascending (soonest expiring first)
            permits.sort((a, b) => a.validTo.compareTo(b.validTo));
            return permits;
          });
    } catch (e, stackTrace) {
      _logger.error('Failed to watch permits for org $orgId', e, stackTrace);
      rethrow;
    }
  }

  /// Alias for watchPermitsForOrg
  Stream<List<Permit>> watchPermits(String orgId) => watchPermitsForOrg(orgId);

  /// Watch active permits for an organization
  Stream<List<Permit>> watchActivePermits(String orgId) {
    try {
      final now = DateTime.now().toIso8601String();
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _collection
          .where('organizationId', isEqualTo: orgId)
          .where('validFrom', isLessThanOrEqualTo: now)
          .where('validTo', isGreaterThanOrEqualTo: now)
          .snapshots()
          .map((snapshot) {
            final permits = <Permit>[];
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                permits.add(Permit.fromJson(data));
              } catch (e) {
                _logger.warning('Failed to parse permit ${doc.id}: $e', e);
              }
            }
            // Sort by validTo ascending (soonest expiring first)
            permits.sort((a, b) => a.validTo.compareTo(b.validTo));
            return permits;
          });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to watch active permits for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
  
  /// Get active permits for an organization
  Future<List<Permit>> getActivePermits(String orgId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('validFrom', isLessThanOrEqualTo: now)
          .where('validTo', isGreaterThanOrEqualTo: now)
          .orderBy('validTo', descending: false)
          .get();

      final permits = <Permit>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          permits.add(Permit.fromJson(data));
        } catch (e) {
          _logger.warning('Failed to parse permit ${doc.id}: $e', e);
        }
      }
      return permits;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active permits for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get permits expiring soon (within 90 days)
  Future<List<Permit>> getExpiringSoonPermits(
    String orgId, {
    int warningDays = 90,
  }) async {
    try {
      final now = DateTime.now();
      final warningDate = now.add(Duration(days: warningDays));

      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('validTo', isGreaterThanOrEqualTo: now.toIso8601String())
          .where('validTo', isLessThanOrEqualTo: warningDate.toIso8601String())
          .orderBy('validTo', descending: false)
          .get();

      final permits = <Permit>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          permits.add(Permit.fromJson(data));
        } catch (e) {
          _logger.warning('Failed to parse permit ${doc.id}: $e', e);
        }
      }
      return permits;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get expiring permits for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a permit by ID
  Future<Permit?> getPermitById(String permitId) async {
    try {
      final doc = await _collection.doc(permitId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      data['id'] = doc.id;
      return Permit.fromJson(data);
    } catch (e, stackTrace) {
      _logger.error('Failed to get permit $permitId', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new permit
  Future<String> createPermit(Permit permit) async {
    try {
      final needsId = permit.id.isEmpty || permit.id == '__missing__';
      final docRef = needsId ? _collection.doc() : _collection.doc(permit.id);
      final permitToSave = needsId ? permit.copyWith(id: docRef.id) : permit;

      if (!permitToSave.validate()) {
        throw ArgumentError('Invalid permit data');
      }

      await docRef.set(permitToSave.toJson());
      return docRef.id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create permit', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing permit
  Future<void> updatePermit(Permit permit) async {
    try {
      if (!permit.validate()) {
        throw ArgumentError('Invalid permit data');
      }

      await _collection.doc(permit.id).update(permit.toJson());
    } catch (e, stackTrace) {
      _logger.error('Failed to update permit ${permit.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a permit
  Future<void> deletePermit(String permitId) async {
    try {
      await _collection.doc(permitId).delete();
    } catch (e, stackTrace) {
      _logger.error('Failed to delete permit $permitId', e, stackTrace);
      rethrow;
    }
  }

  /// Get permits covering a specific site
  Future<List<Permit>> getPermitsForSite(
    String orgId,
    String siteId, {
    bool activeOnly = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('siteIds', arrayContains: siteId);

      if (activeOnly) {
        final now = DateTime.now().toIso8601String();
        query = query
            .where('validFrom', isLessThanOrEqualTo: now)
            .where('validTo', isGreaterThanOrEqualTo: now);
      }

      final snapshot = await query.orderBy('validTo', descending: false).get();
      final permits = <Permit>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          permits.add(Permit.fromJson(data));
        } catch (e) {
          _logger.warning('Failed to parse permit ${doc.id}: $e', e);
        }
      }
      return permits;
    } catch (e, stackTrace) {
      _logger.error('Failed to get permits for site $siteId', e, stackTrace);
      rethrow;
    }
  }

  /// Get permits by type
  Future<List<Permit>> getPermitsByType(
    String orgId,
    PermitType type, {
    bool activeOnly = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('typeId', isEqualTo: type.id);

      if (activeOnly) {
        final now = DateTime.now().toIso8601String();
        query = query
            .where('validFrom', isLessThanOrEqualTo: now)
            .where('validTo', isGreaterThanOrEqualTo: now);
      }

      final snapshot = await query.orderBy('validTo', descending: false).get();
      final permits = <Permit>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          permits.add(Permit.fromJson(data));
        } catch (e) {
          _logger.warning('Failed to parse permit ${doc.id}: $e', e);
        }
      }
      return permits;
    } catch (e, stackTrace) {
      _logger.error('Failed to get permits by type ${type.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Add a site to a permit
  Future<void> addSiteToPermit(String permitId, String siteId) async {
    try {
      final permit = await getPermitById(permitId);
      if (permit == null) {
        throw StateError('Permit $permitId not found');
      }

      if (permit.siteIds.contains(siteId)) {
        return; // Site already covered
      }

      await _collection.doc(permitId).update({
        'siteIds': FieldValue.arrayUnion([siteId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to add site $siteId to permit $permitId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Remove a site from a permit
  Future<void> removeSiteFromPermit(String permitId, String siteId) async {
    try {
      await _collection.doc(permitId).update({
        'siteIds': FieldValue.arrayRemove([siteId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to remove site $siteId from permit $permitId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Extend permit validity
  Future<void> extendPermitValidity(
    String permitId,
    DateTime newValidTo,
  ) async {
    try {
      await _collection.doc(permitId).update({
        'validTo': newValidTo.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to extend permit $permitId validity',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Watch permits by authorized activity
  Stream<List<Permit>> watchPermitsByActivity(
    String orgId,
    String activity, {
    bool activeOnly = false,
  }) {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('authorizedActivities', arrayContains: activity);

      if (activeOnly) {
        final now = DateTime.now().toIso8601String();
        query = query
            .where('validFrom', isLessThanOrEqualTo: now)
            .where('validTo', isGreaterThanOrEqualTo: now);
      }

      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return query
          .snapshots()
          .map((snapshot) {
        final permits = <Permit>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            permits.add(Permit.fromJson(data));
          } catch (e) {
            _logger.warning('Failed to parse permit ${doc.id}: $e', e);
          }
        }
        // Sort by validTo ascending (soonest expiring first)
        permits.sort((a, b) => a.validTo.compareTo(b.validTo));
        return permits;
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to watch permits by activity $activity for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get permits by authorized activity
  Future<List<Permit>> getPermitsByActivity(
    String orgId,
    String activity, {
    bool activeOnly = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('authorizedActivities', arrayContains: activity);

      if (activeOnly) {
        final now = DateTime.now().toIso8601String();
        query = query
            .where('validFrom', isLessThanOrEqualTo: now)
            .where('validTo', isGreaterThanOrEqualTo: now);
      }

      final snapshot = await query.orderBy('validTo', descending: false).get();
      final permits = <Permit>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          permits.add(Permit.fromJson(data));
        } catch (e) {
          _logger.warning('Failed to parse permit ${doc.id}: $e', e);
        }
      }
      return permits;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get permits by activity $activity for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
