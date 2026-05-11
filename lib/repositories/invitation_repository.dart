import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class InvitationRepository {
  InvitationRepository({
    required FirebaseFirestore firestore,
  }) : db = firestore;

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get collectionRef =>
      db.collection(ModelType.invitation.collectionPath);

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

      final membershipRef = db
          .collection('organizations')
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
}
