import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seafoundry_community/models/public_read_models/brand_profile.dart';

/// Repository for creating and updating brand profiles.
class BrandProfileRepository {
  BrandProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates or updates a brand profile for an organization.
  Future<void> upsertBrandProfile({
    required String organizationId,
    required String brandName,
    String? tagline,
    String? heroImageUrl,
    String? logoUrl,
    String? accentColor,
    bool kioskEnabled = false,
    bool published = true,
    Map<String, String>? socialMediaLinks,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('User must be logged in to create/update brand profiles');
    }

    final collectionRef = _firestore.collection('brand_profiles');

    // Check if profile exists
    final existing = await collectionRef
        .where('organizationId', isEqualTo: organizationId)
        .limit(1)
        .get();
    final now = DateTime.now().toIso8601String();
    final profileId = 'brand-$organizationId';

    if (existing.docs.isEmpty) {
      // Create new profile
      final brandProfile = BrandProfile(
        id: profileId,
        organizationId: organizationId,
        brandName: brandName,
        tagline: tagline,
        heroImageUrl: heroImageUrl,
        logoUrl: logoUrl,
        accentColor: accentColor,
        kioskEnabled: kioskEnabled,
        published: published,
        publishedAt: published ? now : null,
        socialMediaLinks: socialMediaLinks,
        createdAt: now,
        createdById: userId,
        updatedAt: now,
        updatedById: userId,
      );

      await collectionRef.doc(profileId).set(brandProfile.toJson());
    } else {
      // Update existing profile
      final existingDoc = existing.docs.first;
      final existingProfile = BrandProfile.fromJson(existingDoc.data());

      final updatedProfile = existingProfile.copyWith(
        brandName: brandName,
        tagline: tagline,
        heroImageUrl: heroImageUrl,
        logoUrl: logoUrl,
        accentColor: accentColor,
        kioskEnabled: kioskEnabled,
        published: published,
        publishedAt: published && existingProfile.publishedAt == null
            ? now
            : existingProfile.publishedAt,
        socialMediaLinks: socialMediaLinks,
        updatedAt: now,
        updatedById: userId,
      );

      await collectionRef.doc(existingDoc.id).update(updatedProfile.toJson());
    }
  }

  /// Deletes a brand profile for an organization.
  Future<void> deleteBrandProfile(String organizationId) async {
    final collectionRef = _firestore.collection('brand_profiles');

    final existing = await collectionRef
        .where('organizationId', isEqualTo: organizationId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await collectionRef.doc(existing.docs.first.id).delete();
    }
  }
}
