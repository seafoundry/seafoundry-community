// @tier: community
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class InvitationRepository {
  InvitationRepository({
    required FirebaseFirestore firestore,
    required RecordRepository recordRepository,
  }) : db = firestore,
       _recordRepository = recordRepository,
       _resolver = FirestoreCollectionResolver.instance;

  final FirebaseFirestore db;
  final RecordRepository _recordRepository;
  final FirestoreCollectionResolver _resolver;

  CollectionReference<Map<String, dynamic>> get collectionRef =>
      _resolver.collection(db, ModelType.invitation.collectionPath);

  String _generateSecureToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Get the current origin domain for invitation links.
  /// On web, captures the current URL origin (e.g., http://localhost:5000 or https://provenance.seafoundry.com)
  /// This allows invitation emails to link back to the same domain the inviter is using.
  String? _getCurrentOriginDomain() {
    if (!kIsWeb) return null;
    try {
      // Uri.base gives us the current page URL on web
      final uri = Uri.base;
      // Return origin: scheme + host + port (if non-standard)
      return uri.origin;
    } catch (e) {
      LoggingService.instance.warning('Failed to get origin domain: $e');
      return null;
    }
  }

  Future<Invitation> createInvitation({
    required String email,
    required String organizationId,
    required String invitedById,
    String? roleId,
  }) async {
    final String invitationId = generateId(firestore: db);
    final DateTime expiresAt = DateTime.now().add(const Duration(days: 7));
    final String token = _generateSecureToken();
    final String? originDomain = _getCurrentOriginDomain();

    final invitation = Invitation(
      id: invitationId,
      email: email.toLowerCase().trim(),
      organizationId: organizationId,
      invitedById: invitedById,
      status: InvitationStatus.pending,
      role: _normalizeRoleId(roleId),
      expiresAt: expiresAt.toIso8601String(),
      createdById: invitedById,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      updatedById: invitedById,
      token: token,
      originDomain: originDomain,
    );

    await _recordRepository.createRecord(invitation);
    return invitation;
  }

  Future<List<Invitation>> getInvitationsForOrganization(
    String organizationId,
  ) async {
    final snapshot = await collectionRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RecordFactory.recordFromJson<Invitation>(doc.data()))
        .toList();
  }

  Future<List<Invitation>> getPendingInvitationsForEmail(
    String email, {
    String? organizationId,
  }) async {
    Query<Map<String, dynamic>> query = collectionRef
        .where('email', isEqualTo: email.toLowerCase().trim())
        .where('status', isEqualTo: 'pending');

    // Scope to organization when caller is not the invited user.
    // Without this, Firestore rules reject cross-org queries because
    // isOrgMemberOf cannot be guaranteed for all returned documents.
    if (organizationId != null) {
      query = query.where('organizationId', isEqualTo: organizationId);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => RecordFactory.recordFromJson<Invitation>(doc.data()))
        .toList();
  }

  Future<Invitation?> getInvitationById(String invitationId) async {
    try {
      final doc = await collectionRef.doc(invitationId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) {
        LoggingService.instance.warning(
          'Invitation $invitationId exists but has null data',
        );
        return null;
      }
      return RecordFactory.recordFromJson<Invitation>(data);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to fetch invitation by ID: $invitationId',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> updateInvitationStatus(
    String invitationId,
    String status,
  ) async {
    await collectionRef.doc(invitationId).update({'status': status});
  }

  Future<void> deleteInvitation(String invitationId) async {
    await collectionRef.doc(invitationId).delete();
  }

  Stream<List<Invitation>> streamInvitationsForOrganization(
    String organizationId,
  ) {
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return collectionRef
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .map(
          (snapshot) {
            final invitations = snapshot.docs
                .map((doc) {
                  return RecordFactory.recordFromJson<Invitation>(doc.data());
                })
                .whereType<Invitation>()
                .toList();
            // Sort in-memory by createdAt descending (newest first)
            invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return invitations;
          },
        );
  }

  Future<String?> acceptInvitationAtomic({
    required String invitationId,
    required String acceptingUserEmail,
    required String userId,
    String? roleId,
  }) async {
    return await db.runTransaction<String?>((transaction) async {
      final inviteRef = collectionRef.doc(invitationId);
      final inviteSnap = await transaction.get(inviteRef);

      if (!inviteSnap.exists) throw Exception('Invitation not found');

      final data = inviteSnap.data();
      if (data == null) {
        LoggingService.instance.warning(
          'Invitation $invitationId exists but has null data during accept',
        );
        throw Exception('Invitation missing data');
      }
      final invitation = RecordFactory.recordFromJson<Invitation>(data);

      // Verify email matches
      if (invitation.email.toLowerCase() != acceptingUserEmail.toLowerCase()) {
        throw Exception('Email does not match invitation');
      }

      // Check not expired
      if (invitation.isExpired) throw Exception('Invitation has expired');

      // Check status is pending
      if (invitation.status != InvitationStatus.pending) {
        throw Exception(
          'Invitation has already been ${invitation.status.name}',
        );
      }

      final normalizedRole = _normalizeRoleId(roleId ?? invitation.role);
      final normalizedEmail = acceptingUserEmail.toLowerCase().trim();

      final membershipRef = _resolver
          .collection(db, 'organizations')
          .doc(invitation.organizationId)
          .collection('members')
          .doc(userId);
      final membershipSnap = await transaction.get(membershipRef);

      if (!membershipSnap.exists) {
        transaction.set(membershipRef, {
          'uid': userId,
          if (normalizedEmail.isNotEmpty) 'email': normalizedEmail,
          'role': normalizedRole,
          'joinedAt': DateTime.now().toIso8601String(),
          'createdById': userId,
          'organizationId': invitation.organizationId,
          if (invitation.createdById.isNotEmpty) 'invitedById': invitation.createdById,
        });
      }

      // Update invitation status atomically
      transaction.update(inviteRef, {
        'status': InvitationStatus.accepted.name,
        'acceptedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return normalizedRole;
    });
  }

  String _normalizeRoleId(String? roleId) {
    final role = UserRole.fromId(roleId);
    return role?.id ?? UserRole.practitioner.id;
  }

  /// Resend invitation email via Cloud Function
  Future<void> resendInvitation(String invitationId) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('resendInvitationEmail');

    await callable.call<dynamic>({'invitationId': invitationId});
  }
}
