// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility functions for working with Firestore documents.
///
/// These helpers address common issues when parsing Firestore documents
/// into application models.
abstract final class FirestoreDocumentHelpers {
  /// Injects the Firestore document ID into the document's JSON data.
  ///
  /// Firestore's `DocumentSnapshot.data()` does NOT include the document ID,
  /// but our model `fromJson` methods expect it as `json['id']`. This helper
  /// merges the document ID into the data to prevent null errors during parsing.
  ///
  /// **Usage:**
  /// ```dart
  /// // Instead of:
  /// final event = Event.fromJson(doc.data()!);  // id will be null!
  ///
  /// // Use:
  /// final event = Event.fromJson(injectDocumentId(doc));
  /// ```
  ///
  /// **Edge Cases:**
  /// - If `doc.data()` is null (deleted document), returns `{'id': doc.id}`
  /// - If data already contains an 'id' field, `doc.id` will override it
  ///   (Firestore document ID is authoritative)
  static Map<String, dynamic> injectDocumentId(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return {'id': doc.id};
    return {...data, 'id': doc.id};
  }

  /// Injects the document ID from a raw data map and document ID string.
  ///
  /// Use this when you have the data and ID separately (e.g., from a
  /// transaction read or batch operation).
  ///
  /// **Usage:**
  /// ```dart
  /// final data = snapshot.data();
  /// final event = Event.fromJson(injectId(data, snapshot.id));
  /// ```
  static Map<String, dynamic> injectId(
    Map<String, dynamic>? data,
    String documentId,
  ) {
    if (data == null) return {'id': documentId};
    return {...data, 'id': documentId};
  }
}
