// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/auth_session_service.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for generic record operations across model types.
///
/// In production, inject via Provider/RepositoryProvider. The static singleton
/// methods are retained only for test harness compatibility.
///
/// See also:
/// - [RepositoryBase] for simple lookup data patterns
/// - [BaseInventoryRecordRepository] for org-scoped inventory with URL paths
class RecordRepository {
  RecordRepository({required this.db});

  // ---------------------------------------------------------------------------
  // Test-only singleton pattern
  //
  // These methods exist solely to support legacy test harnesses that were
  // written before provider-based DI was fully adopted. Production code should
  // NEVER use these - always inject RecordRepository via Provider.
  // ---------------------------------------------------------------------------

  static RecordRepository? _instance;

  /// Test-only: Access the configured singleton instance.
  @visibleForTesting
  static RecordRepository? get maybeInstance => _instance;

  /// Test-only: Configure a global instance for test harnesses.
  @visibleForTesting
  static void configure({required FirebaseFirestore firestore}) {
    _instance = RecordRepository(db: firestore);
  }

  /// Test-only: Clear the configured singleton instance.
  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  // ---------------------------------------------------------------------------

  final FirebaseFirestore db;
  final _resolver = FirestoreCollectionResolver.instance;

  /// Apply organization scoping to a collection query when organizationId is
  /// provided and the model type uses a root collection (not nested).
  Query<Map<String, dynamic>> _organizationQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
    ModelType modelType,
    String? organizationId,
  ) {
    if (organizationId != null && !_usesNestedCollection(modelType)) {
      return collectionRef.where('organizationId', isEqualTo: organizationId);
    }
    return collectionRef;
  }

  Stream<List<T>> streamRecordsForModelType<T extends Record>(
    ModelType modelType, {
    String? organizationId,
  }) {
    final collectionRef = _getCollectionRef(modelType, organizationId);
    final query = _organizationQuery(collectionRef, modelType, organizationId);
    return query
        .snapshots()
        .onErrorResume((error, stackTrace) {
          if (_shouldSuppressAuthError(error)) {
            LoggingService.instance.debug(
              'Suppressing ${modelType.name} stream error after sign out',
            );
            return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
          }
          LoggingService.instance.error(
            'Stream error for ${modelType.name} collection',
            error,
            stackTrace,
          );
          return Stream<QuerySnapshot<Map<String, dynamic>>>.error(
            error,
            stackTrace,
          );
        })
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecordFactory.recordFromJson<T>(doc.data()))
              .toList(),
        );
  }

  Future<List<T>> getRecordsForModelType<T extends Record>(
    ModelType modelType, {
    String? organizationId,
  }) async {
    final collectionRef = _getCollectionRef(modelType, organizationId);
    final query = _organizationQuery(collectionRef, modelType, organizationId);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => RecordFactory.recordFromJson<T>(doc.data()))
        .toList();
  }

  Stream<T?> streamRecord<T extends Record>(
    ModelType modelType,
    String id, {
    String? organizationId,
  }) {
    // Determine the correct collection reference
    final collectionRef = _getCollectionRef(modelType, organizationId);

    return collectionRef
        .doc(id)
        .snapshots()
        .onErrorResume((error, stackTrace) {
          if (_shouldSuppressAuthError(error)) {
            LoggingService.instance.debug(
              'Suppressing ${modelType.name} record stream error after sign out',
              {'id': id},
            );
            return Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
          }
          LoggingService.instance.error(
            'Record stream error for ${modelType.name} $id',
            error,
            stackTrace,
          );
          return Stream<DocumentSnapshot<Map<String, dynamic>>>.error(
            error,
            stackTrace,
          );
        })
        .map(
          (snapshot) {
            if (!snapshot.exists) {
              final message =
                  'Record snapshot missing for ${modelType.name} $id'
                  '${organizationId != null ? ' (org: $organizationId)' : ''}';
              LoggingService.instance.error(message);
              return null;
            }
            final data = snapshot.data();
            if (data == null) {
              LoggingService.instance.warning(
                'Document ${snapshot.id} exists but has null data',
                {'collection': modelType.collectionPath, 'docId': snapshot.id},
              );
              return null;
            }
            try {
              return RecordFactory.recordFromJson<T>(data);
            } catch (e, stackTrace) {
              LoggingService.instance.error(
                'Failed to parse ${modelType.name} document $id',
                e,
                stackTrace,
              );
              return null;
            }
          },
        );
  }

  bool _usesNestedCollection(ModelType modelType) {
    return modelType == ModelType.group ||
        modelType == ModelType.organismRecord ||
        modelType == ModelType.genet ||
        modelType == ModelType.zone ||
        modelType == ModelType.subplot;
  }

  bool _shouldSuppressAuthError(Object error) {
    if (!_isSignedOut()) {
      return false;
    }
    return _isPermissionError(error);
  }

  bool _isSignedOut() {
    try {
      return AuthSessionService.instance.isSigningOut ||
          FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return AuthSessionService.instance.isSigningOut;
    }
  }

  bool _isPermissionError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' || error.code == 'unauthenticated';
    }
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('permission') ||
        message.contains('unauthenticated');
  }

  /// Get the correct collection reference, using nested collection for certain model types
  CollectionReference<Map<String, dynamic>> _getCollectionRef(
    ModelType modelType,
    String? organizationId,
  ) {
    // Model types that use nested collections under organizations/{orgId}/
    final usesNestedCollection = _usesNestedCollection(modelType);

    if (usesNestedCollection && organizationId != null) {
      return _resolver.subcollection(
        db,
        ModelType.organization.collectionPath,
        organizationId,
        modelType.collectionPath,
      );
    }

    return _resolver.collection(db, modelType.collectionPath);
  }

  Future<T?> getRecord<T extends Record>(
    ModelType modelType,
    String id, {
    String? organizationId,
  }) async {
    final collectionRef = _getCollectionRef(modelType, organizationId);
    final snapshot = await collectionRef.doc(id).get();
    if (!snapshot.exists) {
      LoggingService.instance.debug(
        'Record not found for ${modelType.name} $id'
        '${organizationId != null ? ' (org: $organizationId)' : ''}',
      );
      return null;
    }
    final data = snapshot.data();
    if (data == null) {
      LoggingService.instance.warning(
        'Document ${snapshot.id} exists but has null data',
        {'collection': modelType.collectionPath, 'docId': snapshot.id},
      );
      return null;
    }
    try {
      return RecordFactory.recordFromJson<T>(data);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to parse ${modelType.name} document $id',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> createRecord<T extends Record>(
    T record, {
    WriteBatch? batch,
    String? organizationId,
  }) async {
    // Use organizationId from record if available (for InventoryRecord types)
    final orgId = organizationId ?? _extractOrganizationId(record);
    final collectionRef = _getCollectionRef(record.modelType, orgId);

    // Debug: Log the exact path being written for security rules debugging
    LoggingService.instance.debug('RecordRepository.createRecord:');
    LoggingService.instance.debug('   - modelType: ${record.modelType.name}');
    LoggingService.instance.debug('   - collectionRef.path: ${collectionRef.path}');
    LoggingService.instance.debug('   - doc path: ${collectionRef.doc(record.id).path}');

    if (batch == null) {
      await collectionRef.doc(record.id).set(record.toJson());
    } else {
      batch.set(collectionRef.doc(record.id), record.toJson());
    }
  }

  Future<void> updateRecord<T extends Record>(
    T record, {
    WriteBatch? batch,
    String? organizationId,
  }) async {
    // Use organizationId from record if available (for InventoryRecord types)
    final orgId = organizationId ?? _extractOrganizationId(record);
    final collectionRef = _getCollectionRef(record.modelType, orgId);
    final docRef = collectionRef.doc(record.id);
    
    if (batch == null) {
      await docRef.update(record.toJson());
    } else {
      batch.update(docRef, record.toJson());
    }
  }

  /// Extract organizationId from a record if it's an InventoryRecord
  String? _extractOrganizationId<T extends Record>(T record) {
    if (record is InventoryRecord) {
      return record.organizationId;
    }
    return null;
  }

  Future<Organization?> findOrganizationByDomain(String domain) async {
    final trimmed = domain.trim();
    if (trimmed.isEmpty) return null;

    Future<Organization?> queryByField(String field, String value) async {
      final snapshot = await _resolver
          .collection(db, ModelType.organization.collectionPath)
          .where(field, isEqualTo: value)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final data = Map<String, dynamic>.from(snapshot.docs.first.data());
      data['id'] = snapshot.docs.first.id;
      return Organization.fromJson(data);
    }

    final direct = await queryByField('domain', trimmed);
    if (direct != null) {
      return direct;
    }

    final lower = trimmed.toLowerCase();
    if (lower != trimmed) {
      final lowerMatch = await queryByField('domain', lower);
      if (lowerMatch != null) {
        return lowerMatch;
      }
    }

    final slugMatch = await queryByField('slug', lower);
    if (slugMatch != null) {
      return slugMatch;
    }

    return queryByField('urlPath', trimmed);
  }
}
