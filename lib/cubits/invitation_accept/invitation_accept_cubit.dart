// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/models/invitation.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/constants/organization_constants.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/user_identity.dart';

part 'invitation_accept_state.dart';

/// Cubit for managing the invitation acceptance workflow.
///
/// Handles validation, email matching, expiry checks, organization tier limits,
/// and the atomic acceptance of invitations.
class InvitationAcceptCubit extends SafeCubit<InvitationAcceptState> {
  InvitationAcceptCubit({
    required FirebaseFirestore firestore,
    required RecordRepository recordRepository,
    required CurrentUser currentUserCubit,
    required String invitationId,
    required String userEmail,
    required String userId,
  })  : _firestore = firestore,
        _recordRepository = recordRepository,
        _currentUserCubit = currentUserCubit,
        _invitationId = invitationId,
        _userEmail = userEmail,
        _userId = userId,
        super(const InvitationAcceptInitial());

  final FirebaseFirestore _firestore;
  final RecordRepository _recordRepository;
  final CurrentUser _currentUserCubit;
  final String _invitationId;
  final String _userEmail;
  final String _userId;

  /// Process the invitation acceptance workflow.
  ///
  /// This validates the invitation, checks email matching, expiry,
  /// organization limits, and accepts the invitation atomically.
  Future<void> processInvitation() async {
    if (state is InvitationAcceptLoading) return;

    if (!communityInvitationsEnabled) {
      emit(const InvitationAcceptError(
        message: 'Invitations are disabled in the open-source build.',
      ));
      return;
    }

    emit(const InvitationAcceptLoading());

    try {
      final resolver = FirestoreCollectionResolver.instance;

      // Fetch invitation
      final invitationDoc = await resolver
          .collection(_firestore, 'invitations')
          .doc(_invitationId)
          .get();

      if (!invitationDoc.exists) {
        emit(const InvitationAcceptError(
          message: 'This invitation link is invalid or has been removed.',
        ));
        return;
      }

      final invitationData = invitationDoc.data();
      if (invitationData == null) {
        emit(const InvitationAcceptError(
          message: 'Could not load invitation details.',
        ));
        return;
      }

      final invitation = RecordFactory.recordFromJson<Invitation>(invitationData);

      // Check if invitation email matches user email
      if (invitation.email.toLowerCase() != _userEmail.toLowerCase()) {
        emit(InvitationAcceptError(
          message:
              'This invitation was sent to a different email address (${invitation.email}). '
              'Please sign in with that email to accept the invitation.',
        ));
        return;
      }

      // Check if invitation is expired
      if (invitation.isExpired) {
        emit(const InvitationAcceptError(
          message: 'This invitation has expired. Please request a new invitation.',
        ));
        return;
      }

      // Check if invitation is already used
      if (invitation.status != InvitationStatus.pending) {
        // If the invitation was already accepted and the email matches,
        // treat this as success (user likely just completed onboarding)
        if (invitation.status == InvitationStatus.accepted &&
            invitation.email.toLowerCase() == _userEmail.toLowerCase()) {
          final orgName = await _fetchOrganizationName(invitation.organizationId);
          emit(InvitationAcceptSuccess(organizationName: orgName));
          return;
        }

        // Otherwise show error for other statuses
        emit(InvitationAcceptError(
          message: 'This invitation has already been ${invitation.status.name}.',
        ));
        return;
      }

      // Get organization name and tier for success message / gating
      final orgDoc = await resolver
          .collection(_firestore, 'organizations')
          .doc(invitation.organizationId)
          .get();

      String? organizationName;
      if (orgDoc.exists && orgDoc.data() != null) {
        final orgData = orgDoc.data()!;
        organizationName = orgData['name'] as String?;
        final orgTier = Tier.fromString(orgData['tier'] as String?);
        final memberCount = safeInt(orgData['memberCount']) ?? 0;

        if (orgTier == Tier.community &&
            memberCount >= communityMemberLimit) {
          emit(InvitationAcceptError(
            message:
                'This organization has reached the $communityMemberLimit-member limit for Community tier.',
          ));
          return;
        }
      }

      // Accept the invitation
      final invitationRepository = InvitationRepository(
        firestore: _firestore,
        recordRepository: _recordRepository,
      );

      final assignedRole = await invitationRepository.acceptInvitationAtomic(
        invitationId: invitation.id,
        acceptingUserEmail: _userEmail,
        userId: _userId,
        roleId: invitation.role,
      );
      final normalizedRole =
          UserRole.fromId(assignedRole)?.id ?? UserRole.practitioner.id;

      LoggingService.instance.info(
        'InvitationAcceptCubit: Accepted invitation ${invitation.id}, assigned role: $assignedRole',
      );

      // Update user's organizationId if they don't have one
      final currentState = _currentUserCubit.state;
      if (currentState is CurrentUserLoaded) {
        final user = currentState.user;
        final userDocId = UserIdentity.normalizeUserDocId(user.id);
        final updates = <String, dynamic>{
          'role': normalizedRole,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (user.organizationId.isEmpty ||
            user.organizationId == Missing.string) {
          updates['organizationId'] = invitation.organizationId;
        }
        await resolver
            .collection(_firestore, 'users')
            .doc(userDocId)
            .update(updates);
        LoggingService.instance.info(
          'InvitationAcceptCubit: Updated user role to $normalizedRole for ${user.email}',
        );
        if (updates.containsKey('organizationId')) {
          LoggingService.instance.info(
            'InvitationAcceptCubit: Updated user organizationId to ${invitation.organizationId}',
          );
        }
      }

      emit(InvitationAcceptSuccess(organizationName: organizationName));

      // Reload user data to reflect new organization
      if (currentState is CurrentUserLoaded) {
        await _currentUserCubit.loadUser(currentState.user.id);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to accept invitation', e, stackTrace);
      emit(InvitationAcceptError(
        message: 'Failed to accept invitation: ${e.toString()}',
      ));
    }
  }

  Future<String?> _fetchOrganizationName(String organizationId) async {
    try {
      final resolver = FirestoreCollectionResolver.instance;
      final orgDoc = await resolver
          .collection(_firestore, 'organizations')
          .doc(organizationId)
          .get();

      if (orgDoc.exists && orgDoc.data() != null) {
        return orgDoc.data()!['name'] as String?;
      }
    } catch (e) {
      LoggingService.instance.warning(
        'InvitationAcceptCubit: Failed to fetch organization name for $organizationId',
      );
    }
    return null;
  }
}
