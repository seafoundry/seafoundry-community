// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Repository for managing neutral [ReproductiveEvent] records. These events
/// live in the top-level `reproductive_events` collection so they can be shared
/// across organisms and referenced by cohorts/provenances.
class ReproductiveEventRepository {
  ReproductiveEventRepository({
    required this.organization,
    required this.user,
    required FirebaseFirestore firestore,
    OrganismContext? organismContext,
  }) : _firestore = firestore,
       _resolver = FirestoreCollectionResolver.instance,
       organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral);

  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver;
  final Organization organization;
  final User user;
  final OrganismContext organismContext;

  CollectionReference<Map<String, dynamic>> get collectionRef =>
      _resolver.collection(_firestore, ModelType.reproductiveEvent.collectionPath);

  /// Apply organization scoping to any collection query.
  Query<Map<String, dynamic>> _organizationQuery(
    CollectionReference<Map<String, dynamic>> collection,
  ) {
    return collection.where('organizationId', isEqualTo: organization.id);
  }

  Future<ReproductiveEvent> createEvent(
    ReproductiveEvent event, {
    String? id,
  }) async {
    final docId =
        id ?? (event.id.isNotEmpty ? event.id : collectionRef.doc().id);
    final now = DateTimeConverter.nowAsIso8601String();
    final baseMetadata = event.metadata == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(event.metadata!);
    final metadata = {
      ...baseMetadata,
      'organismKind': baseMetadata['organismKind'] ?? organismContext.kind.name,
    };

    final normalized = event.copyWith(
      id: docId,
      createdAt: now,
      createdById: user.id,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      metadata: metadata,
    );

    await collectionRef.doc(docId).set(normalized.toJson());
    return normalized;
  }

  Future<ReproductiveEvent> updateEvent(ReproductiveEvent event) async {
    if (event.id.isEmpty) {
      throw ArgumentError('event.id cannot be empty when updating.');
    }
    final now = DateTimeConverter.nowAsIso8601String();
    final baseMetadata = event.metadata == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(event.metadata!);
    final metadata = {
      ...baseMetadata,
      'organismKind': baseMetadata['organismKind'] ?? organismContext.kind.name,
    };
    final normalized = event.copyWith(
      updatedAt: now,
      updatedById: user.id,
      metadata: metadata,
    );
    await collectionRef.doc(event.id).update(normalized.toJson());
    return normalized;
  }

  Future<void> deleteEvent(String eventId) async {
    await collectionRef.doc(eventId).delete();
  }

  Future<ReproductiveEvent?> getEvent(String eventId) async {
    final snapshot = await collectionRef.doc(eventId).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return ReproductiveEvent.fromJson(
      FirestoreDocumentHelpers.injectId(data, snapshot.id),
    );
  }

  Stream<List<ReproductiveEvent>> streamEvents({
    String? cohortId,
    String? provenanceId,
  }) {
    Query<Map<String, dynamic>> query = _organizationQuery(collectionRef).where(
      'organismKind',
      isEqualTo: organismContext.kind.name,
    );

    if (cohortId != null && cohortId.isNotEmpty) {
      query = query.where('cohortIds', arrayContains: cohortId);
    }
    if (provenanceId != null && provenanceId.isNotEmpty) {
      query = query.where(
        'provenanceLookup',
        arrayContains: provenanceId,
      );
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ReproductiveEvent.fromJson(
                FirestoreDocumentHelpers.injectDocumentId(doc),
              ))
          .where(
            (event) => _matchesFilters(
              event,
              cohortId: cohortId,
              provenanceId: provenanceId,
            ),
          )
          .toList(growable: false);
    });
  }

  Future<List<ReproductiveEvent>> fetchEvents({
    String? cohortId,
    String? provenanceId,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _organizationQuery(collectionRef).where(
      'organismKind',
      isEqualTo: organismContext.kind.name,
    );
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    if (cohortId != null && cohortId.isNotEmpty) {
      query = query.where('cohortIds', arrayContains: cohortId);
    }
    if (provenanceId != null && provenanceId.isNotEmpty) {
      query = query.where(
        'provenanceLookup',
        arrayContains: provenanceId,
      );
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ReproductiveEvent.fromJson(
              FirestoreDocumentHelpers.injectDocumentId(doc),
            ))
        .where(
          (event) => _matchesFilters(
            event,
            cohortId: cohortId,
            provenanceId: provenanceId,
          ),
        )
        .toList(growable: false);
  }

  bool _matchesFilters(
    ReproductiveEvent event, {
    String? cohortId,
    String? provenanceId,
  }) {
    if (cohortId != null && cohortId.isNotEmpty) {
      if (!event.cohortIds.contains(cohortId)) {
        return false;
      }
    }

    if (provenanceId != null && provenanceId.isNotEmpty) {
      final matchesProvenance =
          event.damProvenanceIds.contains(provenanceId) ||
          event.sireProvenanceIds.contains(provenanceId) ||
          event.outputProvenanceId == provenanceId;
      if (!matchesProvenance) {
        return false;
      }
    }

    return true;
  }
}
