// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';
import 'package:seafoundry_app/models/public_read_models/media_asset.dart';
import 'package:seafoundry_app/models/public_read_models/public_playlist.dart';
import 'package:seafoundry_app/models/public_read_models/public_digest.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';

import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Read-only helper for public-facing models.
class PublicReadModelsService {
  PublicReadModelsService({
    FirebaseFirestore? firestore,
    FirestoreCollectionResolver? resolver,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _resolver = resolver ?? FirestoreCollectionResolver.instance;

  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver;

  Future<BrandProfile?> fetchBrandProfile(
    String organizationId, {
    bool preview = false,
  }) async {
    final query = _brandProfileQuery(organizationId, preview: preview);
    final snapshot = await query.limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return BrandProfile.fromJson(snapshot.docs.first.data());
  }

  Stream<List<MediaAsset>> streamPublicMedia(
    String organizationId, {
    bool preview = false,
  }) {
    Query<Map<String, dynamic>> query;
    if (preview) {
      query = _resolver
          .collection(_firestore, 'media_assets')
          .where('organizationId', isEqualTo: organizationId);
    } else {
      query = _resolver
          .subcollection(_firestore, 'public_orgs', organizationId, 'media')
          .orderBy('publishedAt', descending: true);
    }

    return query.snapshots().map(
      (snap) => snap.docs.map((d) => MediaAsset.fromJson(d.data())).toList(),
    );
  }

  Stream<BrandProfile?> streamBrandProfile(
    String organizationId, {
    bool preview = false,
  }) {
    final query = _brandProfileQuery(organizationId, preview: preview).limit(1);
    return query.snapshots().map((snap) {
      if (snap.docs.isEmpty) return null;
      return BrandProfile.fromJson(snap.docs.first.data());
    });
  }

  Future<PublicPlaylist?> fetchPlaylist(
    String organizationId,
    String playlistId,
  ) async {
    final doc = await _resolver
        .subcollection(_firestore, 'public_orgs', organizationId, 'playlists')
        .doc(playlistId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return PublicPlaylist.fromJson(data);
  }

  Future<PublicDigest?> fetchLatestDigest(String organizationId) async {
    final query = await _resolver
        .subcollection(_firestore, 'public_orgs', organizationId, 'digests')
        .where('published', isEqualTo: true)
        .orderBy('weekOf', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final data = query.docs.first.data();
    return PublicDigest.fromJson(data);
  }

  Stream<List<PublicImpactPoint>> streamImpactPoints(String organizationId) {
    return _resolver
        .subcollection(
          _firestore,
          'public_orgs',
          organizationId,
          'impact_points',
        )
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => PublicImpactPoint.fromJson(doc.data()))
              .toList(),
        );
  }

  Future<PublicImpactPoint?> fetchImpactPointForSite({
    required String organizationId,
    required String siteId,
    required PublicImpactPointType pointType,
  }) async {
    final pointId = '${pointType.name}_$siteId';
    final doc = await _resolver
        .subcollection(_firestore, 'public_orgs', organizationId, 'impact_points')
        .doc(pointId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return PublicImpactPoint.fromJson(data);
  }

  Query<Map<String, dynamic>> _brandProfileQuery(
    String organizationId, {
    required bool preview,
  }) {
    if (preview) {
      return _resolver
          .collection(_firestore, 'brand_profiles')
          .where('organizationId', isEqualTo: organizationId);
    }
    return _resolver.subcollection(
      _firestore,
      'public_orgs',
      organizationId,
      'brand_profiles',
    );
  }
}
