// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/site_baseline.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Firestore-backed service that stores and retrieves environmental baselines
/// per site (optionally scoped to an organism). Baselines are cached to limit
/// network chatter when monitoring dialogs repeatedly query the same site.
class SiteBaselineService {
  SiteBaselineService({
    required FirebaseFirestore firestore,
    Duration cacheTtl = const Duration(minutes: 10),
    FirestoreCollectionResolver? resolver,
  }) : _firestore = firestore,
       _cacheTtl = cacheTtl,
       _resolver = resolver ?? FirestoreCollectionResolver.instance;

  static const String collectionPath = 'site_baselines';

  final FirebaseFirestore _firestore;
  final Duration _cacheTtl;
  final FirestoreCollectionResolver _resolver;
  final Map<String, _CachedBaseline> _cache = {};

  /// Loads a baseline for the provided site (and optional organism). Results
  /// are cached until [cacheTtl] expires unless [forceRefresh] is true. When an
  /// organism-specific baseline is missing, the method optionally falls back to
  /// the site-wide baseline (controlled by [fallbackToSite]).
  Future<SiteBaseline?> getBaseline({
    required String siteId,
    OrganismKind? organismKind,
    bool forceRefresh = false,
    bool fallbackToSite = true,
  }) async {
    final key = _cacheKey(siteId, organismKind);
    final now = DateTime.now();
    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null && now.isBefore(cached.expiresAt)) {
        if (cached.baseline != null ||
            !fallbackToSite ||
            organismKind == null) {
          return cached.baseline;
        }
        // Cached null but fallback is allowed—continue to Firestore lookup.
      }
    }

    final doc = await _docRef(siteId, organismKind).get();
    if (doc.exists) {
      final baseline = SiteBaseline.fromJson(doc.data() ?? const {}, siteId);
      _writeCache(key, baseline);
      return baseline;
    }

    if (fallbackToSite && organismKind != null) {
      final fallbackBaseline = await getBaseline(
        siteId: siteId,
        organismKind: null,
        forceRefresh: forceRefresh,
        fallbackToSite: false,
      );
      if (fallbackBaseline != null) {
        _writeCache(key, fallbackBaseline);
      }
      return fallbackBaseline;
    }

    _writeCache(key, null);
    return null;
  }

  /// Stream updates for a particular baseline document. Useful when monitoring
  /// screens need live updates after a user edits baseline metadata.
  Stream<SiteBaseline?> baselineStream({
    required String siteId,
    OrganismKind? organismKind,
  }) {
    return _docRef(siteId, organismKind).snapshots().map((snapshot) {
      final baseline = snapshot.exists
          ? SiteBaseline.fromJson(snapshot.data() ?? const {}, siteId)
          : null;
      _writeCache(_cacheKey(siteId, organismKind), baseline);
      return baseline;
    });
  }

  /// Creates or updates a baseline in Firestore.
  Future<void> upsertBaseline(SiteBaseline baseline) async {
    final payload = baseline.toJson();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    if (baseline.updatedBy != null && baseline.updatedBy!.isNotEmpty) {
      payload['updatedBy'] = baseline.updatedBy;
    }
    final reference = _docRef(baseline.siteId, baseline.organismKind);
    await reference.set(payload, SetOptions(merge: true));
    _writeCache(
      _cacheKey(baseline.siteId, baseline.organismKind),
      baseline.copyWith(updatedAt: DateTime.now()),
    );
  }

  /// Deletes the stored baseline for the specified site/organism, if any.
  Future<void> deleteBaseline({
    required String siteId,
    OrganismKind? organismKind,
  }) async {
    await _docRef(siteId, organismKind).delete();
    _cache.remove(_cacheKey(siteId, organismKind));
  }

  /// Lists all baselines (optionally filtered by [siteId]).
  Future<List<SiteBaseline>> listBaselines({String? siteId}) async {
    Query<Map<String, dynamic>> query = _resolver.collection(
      _firestore,
      collectionPath,
    );
    if (siteId != null && siteId.trim().isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId.trim());
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              SiteBaseline.fromJson(doc.data(), doc.data()['siteId'] ?? doc.id),
        )
        .toList(growable: false);
  }

  /// Clears all cached baselines (primarily for tests).
  void clearCache() => _cache.clear();

  DocumentReference<Map<String, dynamic>> _docRef(
    String siteId,
    OrganismKind? organismKind,
  ) {
    final docId = SiteBaseline.documentId(siteId, organismKind: organismKind);
    return _resolver.collection(_firestore, collectionPath).doc(docId);
  }

  void _writeCache(String key, SiteBaseline? baseline) {
    _cache[key] = _CachedBaseline(
      baseline: baseline,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
  }

  String _cacheKey(String siteId, OrganismKind? organismKind) {
    return '${siteId.trim()}::${organismKind?.name ?? 'global'}';
  }
}

class _CachedBaseline {
  _CachedBaseline({required this.baseline, required this.expiresAt});

  final SiteBaseline? baseline;
  final DateTime expiresAt;
}
