// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';


/// Read-only helper for public-facing models.
class PublicReadModelsService {
  PublicReadModelsService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<BrandProfile?> fetchBrandProfile(
    String organizationId, {
    bool preview = false,
  }) async {
    final query = _brandProfileQuery(organizationId, preview: preview);
    final snapshot = await query.limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return BrandProfile.fromJson(snapshot.docs.first.data());
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

  Query<Map<String, dynamic>> _brandProfileQuery(
    String organizationId, {
    required bool preview,
  }) {
    if (preview) {
      return _firestore
          .collection('brand_profiles')
          .where('organizationId', isEqualTo: organizationId);
    }
    return _firestore
        .collection('public_orgs')
        .doc(organizationId)
        .collection('brand_profiles');
  }
}
