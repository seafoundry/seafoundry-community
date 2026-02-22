// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class OrganizationSearchResult {
  OrganizationSearchResult({required this.items, this.lastDocument});

  final List<Organization> items;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;

  bool get hasMore => lastDocument != null;
}

class OrganizationRepository {
  OrganizationRepository({required FirebaseFirestore firestore})
    : _firestore = firestore,
      _resolver = FirestoreCollectionResolver.instance;
  
  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver;
  
  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, ModelType.organization.collectionPath);

  Future<Organization?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return _mapOrganization(doc);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load organization $id',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<Organization?> resolveIdentifier(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;

    final byId = await getById(trimmed);
    if (byId != null) return byId;

    final normalized = trimmed.toLowerCase();

    final byDomain = await _findByField('domain', normalized);
    if (byDomain != null) return byDomain;

    final bySlug = await _findByField('slug', normalized);
    if (bySlug != null) return bySlug;

    final byUrlPath = await _findByField('urlPath', trimmed);
    if (byUrlPath != null) return byUrlPath;

    return null;
  }

  Future<OrganizationSearchResult> searchOrganizations({
    required String query,
    int limit = 20,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final normalized = query.trim().toLowerCase();

    // Simple approach: fetch organizations and filter client-side by name/domain
    // This works well for small datasets typical in this use case
    try {
      Query<Map<String, dynamic>> baseQuery = _collection.orderBy('name');

      if (startAfter != null) {
        baseQuery = baseQuery.startAfterDocument(startAfter);
      }

      // Fetch more than limit to account for client-side filtering
      baseQuery = baseQuery.limit(limit * 3);

      final snapshot = await baseQuery.get();

      final filtered = normalized.isEmpty
          ? snapshot.docs
          : snapshot.docs.where((doc) {
              final data = doc.data();
              final name = (data['name'] as String? ?? '').toLowerCase();
              final domain = (data['domain'] as String? ?? '').toLowerCase();
              final slug = (data['slug'] as String? ?? '').toLowerCase();
              return name.contains(normalized) ||
                  domain.contains(normalized) ||
                  slug.contains(normalized);
            });

      final organizations = filtered.take(limit).map(_mapOrganization).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return OrganizationSearchResult(
        items: organizations,
        lastDocument: lastDoc,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to search organizations',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Organization?> _findByField(String field, String value) async {
    try {
      final snapshot = await _collection
          .where(field, isEqualTo: value)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return _mapOrganization(snapshot.docs.first);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to find organization by $field',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> updateSupportedOrganismKinds({
    required String organizationId,
    required List<OrganismKind> kinds,
    String? updatedById,
  }) {
    final payload = <String, dynamic>{
      'supportedOrganismKinds': kinds.map((kind) => kind.name).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final updater = updatedById?.trim();
    if (updater != null && updater.isNotEmpty) {
      payload['updatedById'] = updater;
    }
    return _collection.doc(organizationId).update(payload);
  }

  Future<void> updateActivities({
    required String organizationId,
    required List<String> activityIds,
    String? updatedById,
  }) {
    final payload = <String, dynamic>{
      'activities': activityIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final updater = updatedById?.trim();
    if (updater != null && updater.isNotEmpty) {
      payload['updatedById'] = updater;
    }
    return _collection.doc(organizationId).update(payload);
  }

  Future<void> updateOrganization({
    required String organizationId,
    String? name,
    String? updatedById,
  }) {
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (name != null) 'nameLowercase': name.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final updater = updatedById?.trim();
    if (updater != null && updater.isNotEmpty) {
      payload['updatedById'] = updater;
    }
    return _collection.doc(organizationId).update(payload);
  }

  Organization _mapOrganization(DocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data();
    final data = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(raw);
    data['id'] ??= doc.id;
    return Organization.fromJson(data);
  }
}
