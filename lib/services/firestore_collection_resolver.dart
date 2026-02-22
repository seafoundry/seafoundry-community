// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Centralized service for resolving Firestore collection references
///
/// All repositories should use this service instead of directly accessing
/// FirebaseFirestore collections.
class FirestoreCollectionResolver {
  static final FirestoreCollectionResolver instance = FirestoreCollectionResolver._();
  FirestoreCollectionResolver._();

  /// Wrap a document snapshot stream with error logging
  Stream<DocumentSnapshot<Map<String, dynamic>>> wrapDocumentStream(
    DocumentReference<Map<String, dynamic>> docRef,
  ) {
    if (kDebugMode) {
      debugPrint('📡 STREAM SETUP: ${docRef.path}');
    }
    return docRef.snapshots().handleError((error, stackTrace) {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔴 STREAM ERROR: ${docRef.path}');
        debugPrint('   Error: $error');
        if (error is FirebaseException) {
          debugPrint('   Code: ${error.code}');
        }
        debugPrint('');
      }
      LoggingService.instance.error(
        'Firestore stream error [${docRef.path}]',
        error,
        stackTrace,
      );
      throw error;
    });
  }

  /// Wrap a collection snapshot stream with error logging
  Stream<QuerySnapshot<Map<String, dynamic>>> wrapCollectionStream(
    Query<Map<String, dynamic>> query,
    String debugPath,
  ) {
    if (kDebugMode) {
      debugPrint('📡 STREAM SETUP (collection): $debugPath');
    }
    return query.snapshots().handleError((error, stackTrace) {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔴 STREAM ERROR (collection): $debugPath');
        debugPrint('   Error: $error');
        if (error is FirebaseException) {
          debugPrint('   Code: ${error.code}');
        }
        debugPrint('');
      }
      LoggingService.instance.error(
        'Firestore collection stream error [$debugPath]',
        error,
        stackTrace,
      );
      throw error;
    });
  }

  /// Get a collection reference
  ///
  /// Example:
  /// ```dart
  /// final collection = FirestoreCollectionResolver.instance.collection(
  ///   firestore,
  ///   'corals',
  /// );
  /// ```
  CollectionReference<Map<String, dynamic>> collection(
    FirebaseFirestore firestore,
    String collectionPath,
  ) {
    return firestore.collection(collectionPath);
  }

  /// Get a document reference
  ///
  /// Example:
  /// ```dart
  /// final doc = FirestoreCollectionResolver.instance.document(
  ///   firestore,
  ///   'organizations/org123',
  /// );
  /// ```
  DocumentReference<Map<String, dynamic>> document(
    FirebaseFirestore firestore,
    String documentPath,
  ) {
    // Split path into collection and document segments
    final segments = documentPath.split('/');
    if (segments.length < 2 || segments.length % 2 != 0) {
      throw ArgumentError('Invalid document path: $documentPath');
    }

    return firestore.doc(documentPath);
  }

  /// Get a subcollection reference
  ///
  /// Example:
  /// ```dart
  /// final subcol = FirestoreCollectionResolver.instance.subcollection(
  ///   firestore,
  ///   'users',
  ///   'user123',
  ///   'training',
  /// );
  /// // Result: users/user123/training
  /// ```
  CollectionReference<Map<String, dynamic>> subcollection(
    FirebaseFirestore firestore,
    String parentCollectionPath,
    String parentDocumentId,
    String subcollectionName,
  ) {
    return firestore
        .collection(parentCollectionPath)
        .doc(parentDocumentId)
        .collection(subcollectionName);
  }

  /// Get a collection group query
  ///
  /// Collection groups query across all collections with the same name,
  /// regardless of the document path.
  ///
  /// Example:
  /// ```dart
  /// final query = FirestoreCollectionResolver.instance.collectionGroup(
  ///   firestore,
  ///   'organism_records',
  /// );
  /// ```
  Query<Map<String, dynamic>> collectionGroup(
    FirebaseFirestore firestore,
    String collectionId,
  ) {
    return firestore.collectionGroup(collectionId);
  }

  /// Generate a new document ID
  ///
  /// This generates IDs from a temporary collection.
  String generateId(FirebaseFirestore firestore) {
    return firestore.collection('temp').doc().id;
  }
}
