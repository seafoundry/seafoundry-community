// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/user_identity.dart';

/// Repository for managing users and organization membership
class UserRepository {
  UserRepository({
    required FirebaseFirestore firestore,
    required RecordRepository recordRepository,
  }) : _firestore = firestore,
       _recordRepository = recordRepository,
       _resolver = FirestoreCollectionResolver.instance;

  final FirebaseFirestore _firestore;
  final RecordRepository _recordRepository;
  final FirestoreCollectionResolver _resolver;
  
  CollectionReference<Map<String, dynamic>> get _collectionRef =>
      _resolver.collection(_firestore, 'users');

  String _resolveUserDocId(String userId) {
    return UserIdentity.normalizeUserDocId(userId);
  }

  /// Get all members of an organization
  Future<List<User>> getOrganizationMembers(String organizationId) async {
    try {
      final snapshot = await _collectionRef
          .where('organizationId', isEqualTo: organizationId)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return RecordFactory.recordFromJson<User>(doc.data());
            } catch (e) {
              LoggingService.instance.error(
                'Failed to parse user ${doc.id}',
                e,
              );
              return null;
            }
          })
          .whereType<User>()
          .toList();
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to get organization members', e, stackTrace);
      rethrow;
    }
  }

  /// Save or update a user's intro document at `/users/{userId}/intro/profile`.
  Future<void> saveUserIntro({
    required String userId,
    required UserIntro intro,
  }) async {
    try {
      final resolvedId = _resolveUserDocId(userId);
      await _collectionRef
          .doc(resolvedId)
          .collection('intro')
          .doc('profile')
          .set(intro.toMap(), SetOptions(merge: true));
      LoggingService.instance.info('Saved user intro for $userId');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to save user intro', e, stackTrace);
      rethrow;
    }
  }

  /// Fetch a user's intro document, if present.
  Future<UserIntro?> getUserIntro(String userId) async {
    try {
      final resolvedId = _resolveUserDocId(userId);
      final snap = await _collectionRef
          .doc(resolvedId)
          .collection('intro')
          .doc('profile')
          .get();
      final data = snap.data();
      if (data == null) return null;
      return UserIntro.fromMap(data);
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        LoggingService.instance.warning(
          'User intro fetch blocked by permissions',
          {'userId': userId},
        );
        return null;
      }
      LoggingService.instance.error('Failed to fetch user intro', e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to fetch user intro', e, stackTrace);
      return null;
    }
  }

  /// Stream of organization members
  Stream<List<User>> streamOrganizationMembers(String organizationId) {
    return _collectionRef
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) {
                try {
                  return RecordFactory.recordFromJson<User>(doc.data());
                } catch (e) {
                  LoggingService.instance.error(
                    'Failed to parse user ${doc.id}',
                    e,
                  );
                  return null;
                }
              })
              .whereType<User>()
              .toList(),
        );
  }

  /// Update user role
  Future<void> updateUserRole({
    required String userId,
    required String roleId,
    required String organizationId,
  }) async {
    try {
      final resolvedId = _resolveUserDocId(userId);
      final normalizedRole = UserRole.fromId(roleId)?.id ?? UserRole.practitioner.id;
      final membershipRef = await _resolveMembershipDocRef(
        organizationId: organizationId,
        userId: resolvedId,
      );

      final batch = _firestore.batch();
      batch.update(_collectionRef.doc(resolvedId), {
        'role': normalizedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (membershipRef != null) {
        batch.update(membershipRef, {
          'role': normalizedRole,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();

      LoggingService.instance.info('Updated role for user $userId to $normalizedRole');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to update user role', e, stackTrace);
      rethrow;
    }
  }

  /// Remove user from organization
  Future<void> removeUserFromOrganization({
    required String userId,
    required String organizationId,
  }) async {
    try {
      final resolvedId = _resolveUserDocId(userId);
      final membershipRef = await _resolveMembershipDocRef(
        organizationId: organizationId,
        userId: resolvedId,
      );

      final batch = _firestore.batch();
      batch.update(_collectionRef.doc(resolvedId), {
        'organizationId': FieldValue.delete(),
        'role': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (membershipRef != null) {
        batch.delete(membershipRef);
      }

      await batch.commit();

      LoggingService.instance.info('Removed user $userId from organization');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to remove user from organization',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveMembershipDocRef({
    required String organizationId,
    required String userId,
  }) async {
    if (organizationId.isEmpty) return null;
    final membersRef = _resolver
        .collection(_firestore, 'organizations')
        .doc(organizationId)
        .collection('members');
    final membershipRef = membersRef.doc(userId);
    final membershipDoc = await membershipRef.get();
    if (!membershipDoc.exists) {
      LoggingService.instance.warning(
        'Membership document not found for $userId in org $organizationId',
      );
      return null;
    }
    return membershipRef;
  }

  /// Get user by ID
  Future<User?> getUser(String userId) async {
    try {
      final resolvedId = _resolveUserDocId(userId);
      final user = await _recordRepository.getRecord<User>(
        ModelType.user,
        resolvedId,
      );
      return user;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to get user $userId', e, stackTrace);
      return null;
    }
  }

  /// Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final snapshot = await _collectionRef
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return RecordFactory.recordFromJson<User>(data);
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to get user by email', e, stackTrace);
      return null;
    }
  }

  /// Update user's organization and role
  Future<void> assignUserToOrganization({
    required String userId,
    required String organizationId,
    String? roleId,
  }) async {
    try {
      final resolvedId = _resolveUserDocId(userId);
      final normalizedRole = roleId != null
          ? (UserRole.fromId(roleId)?.id ?? UserRole.practitioner.id)
          : UserRole.practitioner.id;

      // Fetch user to get their email for the membership doc
      final user = await getUser(resolvedId);
      final userEmail = user?.email;

      final userUpdateData = <String, dynamic>{
        'organizationId': organizationId,
        'role': normalizedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Build membership document data
      final membershipData = <String, dynamic>{
        'uid': resolvedId,
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
        'role': normalizedRole,
        'joinedAt': DateTime.now().toIso8601String(),
        'organizationId': organizationId,
        'createdById': resolvedId,
      };

      // Create membership document reference
      final membershipRef = _resolver
          .collection(_firestore, 'organizations')
          .doc(organizationId)
          .collection('members')
          .doc(resolvedId);

      // Use batch to atomically update both documents
      final batch = _firestore.batch();
      batch.update(_collectionRef.doc(resolvedId), userUpdateData);
      batch.set(membershipRef, membershipData, SetOptions(merge: true));

      await batch.commit();

      LoggingService.instance.info(
        'Assigned user $userId to organization $organizationId with role $normalizedRole',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to assign user to organization', e, stackTrace);
      rethrow;
    }
  }

  /// Update user metadata
  Future<void> updateUserMetadata({
    required String userId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final resolvedId = _resolveUserDocId(userId);
      await _collectionRef.doc(resolvedId).update({
        'metadata': metadata,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggingService.instance.info('Updated metadata for user $userId');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to update user metadata', e, stackTrace);
      rethrow;
    }
  }
}
