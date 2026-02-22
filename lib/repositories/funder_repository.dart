// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/operations/funder.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for managing funder records
class FunderRepository {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  FunderRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  })  : _firestore = firestore,
        _logger = logger ?? LoggingService.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, ModelType.funder.collectionPath);

  /// Watch active funders for an organization
  Stream<List<Funder>> watchActiveFundersForOrg(String orgId) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _collection
          .where('organizationId', isEqualTo: orgId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        final funders = <Funder>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            funders.add(Funder.fromJson(data));
          } catch (e) {
            _logger.warning(
              'Failed to parse funder ${doc.id}: $e',
              e,
            );
          }
        }
        // Sort in-memory by name ascending (alphabetically)
        funders.sort((a, b) => a.name.compareTo(b.name));
        return funders;
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to watch funders for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Watch all funders for an organization
  Stream<List<Funder>> watchAllFunders(String orgId) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _collection
          .where('organizationId', isEqualTo: orgId)
          .snapshots()
          .map((snapshot) {
        final funders = <Funder>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            funders.add(Funder.fromJson(data));
          } catch (e) {
            _logger.warning('Failed to parse funder ${doc.id}: $e', e);
          }
        }
        // Sort in-memory by name ascending (alphabetically)
        funders.sort((a, b) => a.name.compareTo(b.name));
        return funders;
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to watch all funders for org $orgId', e, stackTrace);
      rethrow;
    }
  }

  /// Alias for watchAllFunders
  Stream<List<Funder>> watchFunders(String orgId) => watchAllFunders(orgId);

  /// Get all active funders for an organization
  Future<List<Funder>> getActiveFunders(String orgId) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('isActive', isEqualTo: true)
          .orderBy('name', descending: false)
          .get();

      final funders = <Funder>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          funders.add(Funder.fromJson(data));
        } catch (e) {
          _logger.warning(
            'Failed to parse funder ${doc.id}: $e',
            e,
          );
        }
      }
      return funders;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active funders for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all funders (including inactive) for an organization
  Future<List<Funder>> getAllFunders(String orgId) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .orderBy('name', descending: false)
          .get();

      final funders = <Funder>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          funders.add(Funder.fromJson(data));
        } catch (e) {
          _logger.warning(
            'Failed to parse funder ${doc.id}: $e',
            e,
          );
        }
      }
      return funders;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get all funders for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a funder by ID
  Future<Funder?> getFunderById(String funderId) async {
    try {
      final doc = await _collection.doc(funderId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      data['id'] = doc.id;
      return Funder.fromJson(data);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get funder $funderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new funder
  Future<String> createFunder(Funder funder) async {
    try {
      final needsId = funder.id.isEmpty || funder.id == '__missing__';
      final docRef = needsId ? _collection.doc() : _collection.doc(funder.id);
      final funderToSave = needsId ? funder.copyWith(id: docRef.id) : funder;

      if (!funderToSave.validate()) {
        throw ArgumentError('Invalid funder data');
      }

      await docRef.set(funderToSave.toJson());
      return docRef.id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create funder', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing funder
  Future<void> updateFunder(Funder funder) async {
    try {
      if (!funder.validate()) {
        throw ArgumentError('Invalid funder data');
      }

      await _collection.doc(funder.id).update(funder.toJson());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update funder ${funder.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a funder
  Future<void> deleteFunder(String funderId) async {
    try {
      await _collection.doc(funderId).delete();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete funder $funderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
