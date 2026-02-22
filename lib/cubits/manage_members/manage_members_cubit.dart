// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/constants/organization_constants.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/models/invitation.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/user_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

part 'manage_members_state.dart';

class ManageMembersCubit extends Cubit<ManageMembersState>
    with CubitStreamSubscriptionMixin {
  ManageMembersCubit({
    required this.userRepository,
    required this.invitationRepository,
    required this.organizationId,
    required this.currentUserId,
    required this.organizationTier,
  }) : super(const ManageMembersInitial());

  final UserRepository userRepository;
  final InvitationRepository invitationRepository;
  final String organizationId;
  final String currentUserId;
  final Tier organizationTier;

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin

  Future<void> loadData() async {
    emit(const ManageMembersLoading());

    try {
      final members = await userRepository.getOrganizationMembers(organizationId);
      final invitations = await invitationRepository.getInvitationsForOrganization(organizationId);
      final pendingInvitations = invitations.where((i) => i.status == InvitationStatus.pending).toList();

      // Load intro notes for members
      final introNotesMap = <String, String>{};
      for (final member in members) {
        final intro = await userRepository.getUserIntro(member.id);
        if (intro?.note != null && intro!.note!.isNotEmpty) {
          introNotesMap[member.id] = intro.note!;
        }
      }

      if (isClosed) return;
      emit(ManageMembersLoaded(
        members: members,
        pendingInvitations: pendingInvitations,
        memberIntroNotes: introNotesMap,
        currentUserId: currentUserId,
      ));
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        LoggingService.instance.warning(
          'Permission denied loading members: ${e.message}',
        );
        if (isClosed) return;
        emit(const ManageMembersError(
          'You do not have permission to manage members.',
        ));
        return;
      }
      LoggingService.instance.error('Failed to load members', e, stackTrace);
      if (isClosed) return;
      emit(ManageMembersError('Failed to load members: $e'));
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to load members', error, stackTrace);
      if (isClosed) return;
      emit(ManageMembersError('Failed to load members: $error'));
    }
  }

  void startRealtimeUpdates() {
    // Use keyed subscriptions for automatic cleanup on re-subscription
    listenWithKey<List<User>>(
      'members',
      userRepository.streamOrganizationMembers(organizationId),
      onData: _onMembersUpdated,
      onError: (error, stackTrace) {
        LoggingService.instance.error(
          'Error in members stream',
          error,
          stackTrace,
        );
      },
    );

    listenWithKey<List<Invitation>>(
      'invitations',
      invitationRepository.streamInvitationsForOrganization(organizationId),
      onData: _onInvitationsUpdated,
      onError: (error, stackTrace) {
        LoggingService.instance.error(
          'Error in invitations stream',
          error,
          stackTrace,
        );
      },
    );
  }

  void _onMembersUpdated(List<User> members) async {
    if (isClosed) return;

    final introNotesMap = <String, String>{};
    for (final member in members) {
      final intro = await userRepository.getUserIntro(member.id);
      if (intro?.note != null && intro!.note!.isNotEmpty) {
        introNotesMap[member.id] = intro.note!;
      }
    }

    final currentState = state;
    if (currentState is ManageMembersLoaded && !isClosed) {
      emit(currentState.copyWith(
        members: members,
        memberIntroNotes: introNotesMap,
      ));
    }
  }

  void _onInvitationsUpdated(List<Invitation> invitations) {
    if (isClosed) return;

    final pending = invitations.where((i) => i.status == InvitationStatus.pending).toList();
    final currentState = state;
    if (currentState is ManageMembersLoaded && !isClosed) {
      emit(currentState.copyWith(pendingInvitations: pending));
    }
  }

  Future<void> sendInvitation({
    required String email,
    required String roleId,
  }) async {
    LoggingService.instance.info(
      '📧 sendInvitation called: email=$email, roleId=$roleId, orgId=$organizationId, userId=$currentUserId',
    );

    final currentState = state;
    if (currentState is! ManageMembersLoaded) {
      LoggingService.instance.warning(
        '📧 sendInvitation aborted: state is not ManageMembersLoaded (${currentState.runtimeType})',
      );
      return;
    }

    final normalizedEmail = email.toLowerCase().trim();

    // Check if user is already a member
    if (currentState.members.any((m) => m.email.toLowerCase() == normalizedEmail)) {
      emit(currentState.copyWith(
        errorMessage: 'This email is already a member of your organization',
      ));
      return;
    }

    // Check for duplicate pending invitations
    if (currentState.pendingInvitations.any((i) => i.email.toLowerCase() == normalizedEmail)) {
      emit(currentState.copyWith(
        errorMessage: 'An invitation has already been sent to this email',
      ));
      return;
    }

    final role = UserRole.fromId(roleId) ?? UserRole.practitioner;
    if (organizationTier == Tier.pro) {
      final adminCount = _countRoleInRoster(currentState, UserRole.admin);
      final practitionerCount =
          _countRoleInRoster(currentState, UserRole.practitioner);
      if (role == UserRole.admin && adminCount >= 2) {
        emit(currentState.copyWith(
          errorMessage: 'Current tier is limited to 2 admin seats.',
        ));
        return;
      }
      if (role == UserRole.practitioner && practitionerCount >= 3) {
        emit(currentState.copyWith(
          errorMessage: 'Current tier is limited to 3 practitioner seats.',
        ));
        return;
      }
    }

    if (organizationTier == Tier.community &&
        currentState.members.length + currentState.pendingInvitations.length >=
            communityMemberLimit) {
      emit(currentState.copyWith(
        errorMessage:
            'Community tier is limited to $communityMemberLimit members. Remove a member to invite someone new.',
      ));
      return;
    }

    emit(currentState.copyWith(isSubmitting: true, errorMessage: null));
    LoggingService.instance.info('📧 sendInvitation: starting Firestore write...');

    try {
      await invitationRepository.createInvitation(
        email: normalizedEmail,
        organizationId: organizationId,
        roleId: roleId,
        invitedById: currentUserId,
      );

      LoggingService.instance.info('📧 sendInvitation: SUCCESS - Invitation created for $normalizedEmail');

      await loadData();

      if (isClosed) return;
      final newState = state;
      if (newState is ManageMembersLoaded) {
        emit(newState.copyWith(
          successMessage: 'Invitation sent to $email',
          isSubmitting: false,
        ));
      }
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        LoggingService.instance.warning(
          '📧 sendInvitation: PERMISSION DENIED - ${e.message}',
        );
        if (isClosed) return;
        emit(currentState.copyWith(
          errorMessage: 'You do not have permission to send invitations.',
          isSubmitting: false,
        ));
        return;
      }
      LoggingService.instance.error(
        '📧 sendInvitation: FAILED - $e',
        e,
        stackTrace,
      );
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to send invitation: $e',
        isSubmitting: false,
      ));
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        '📧 sendInvitation: FAILED - $error',
        error,
        stackTrace,
      );
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to send invitation: $error',
        isSubmitting: false,
      ));
    }
  }

  Future<void> resendInvitation(String invitationId) async {
    final currentState = state;
    if (currentState is! ManageMembersLoaded) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      await invitationRepository.resendInvitation(invitationId);
      LoggingService.instance.info('Resent invitation $invitationId');

      if (isClosed) return;
      emit(currentState.copyWith(
        successMessage: 'Invitation resent',
        isSubmitting: false,
      ));
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to resend invitation', error, stackTrace);
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to resend invitation: $error',
        isSubmitting: false,
      ));
    }
  }

  Future<void> cancelInvitation(String invitationId) async {
    final currentState = state;
    if (currentState is! ManageMembersLoaded) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      await invitationRepository.deleteInvitation(invitationId);
      LoggingService.instance.info('Cancelled invitation $invitationId');
      await loadData();
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to cancel invitation', error, stackTrace);
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to cancel invitation: $error',
        isSubmitting: false,
      ));
    }
  }

  Future<void> removeMember(User member) async {
    final currentState = state;
    if (currentState is! ManageMembersLoaded) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      await userRepository.removeUserFromOrganization(
        userId: member.id,
        organizationId: organizationId,
      );
      LoggingService.instance.info('Removed user ${member.id} from organization');
      await loadData();
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied' || error.code == 'PERMISSION_DENIED') {
        LoggingService.instance.warning(
          'Permission denied removing member: ${error.message}',
        );
        if (isClosed) return;
        emit(currentState.copyWith(
          errorMessage: 'You do not have permission to remove members.',
          isSubmitting: false,
        ));
        return;
      }
      LoggingService.instance.error('Failed to remove member', error, stackTrace);
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to remove member: $error',
        isSubmitting: false,
      ));
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to remove member', error, stackTrace);
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to remove member: $error',
        isSubmitting: false,
      ));
    }
  }

  Future<void> changeUserRole(User member, String newRoleId) async {
    final currentState = state;
    if (currentState is! ManageMembersLoaded) return;

    final newRole = UserRole.fromId(newRoleId) ?? UserRole.practitioner;
    final currentRole = UserRole.fromId(member.role) ?? UserRole.practitioner;
    if (organizationTier == Tier.pro) {
      final adminCount = currentState.members
          .where((m) => (UserRole.fromId(m.role) ?? UserRole.practitioner) == UserRole.admin)
          .length;
      final practitionerCount = currentState.members
          .where((m) => (UserRole.fromId(m.role) ?? UserRole.practitioner) == UserRole.practitioner)
          .length;
      if (newRole == UserRole.admin &&
          currentRole != UserRole.admin &&
          adminCount >= 2) {
        emit(currentState.copyWith(
          errorMessage: 'Current tier is limited to 2 admin seats.',
        ));
        return;
      }
      if (newRole == UserRole.practitioner &&
          currentRole != UserRole.practitioner &&
          practitionerCount >= 3) {
        emit(currentState.copyWith(
          errorMessage: 'Current tier is limited to 3 practitioner seats.',
        ));
        return;
      }
    }

    emit(currentState.copyWith(isSubmitting: true));

    try {
      await userRepository.updateUserRole(
        userId: member.id,
        roleId: newRoleId,
        organizationId: organizationId,
      );
      LoggingService.instance.info('Updated role for user ${member.id} to $newRoleId');
      await loadData();
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied' || error.code == 'PERMISSION_DENIED') {
        LoggingService.instance.warning(
          'Permission denied changing role: ${error.message}',
        );
        if (isClosed) return;
        emit(currentState.copyWith(
          errorMessage: 'You do not have permission to change member roles.',
          isSubmitting: false,
        ));
        return;
      }
      LoggingService.instance.error('Failed to change role', error, stackTrace);
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to change role: $error',
        isSubmitting: false,
      ));
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to change role', error, stackTrace);
      if (isClosed) return;
      emit(currentState.copyWith(
        errorMessage: 'Failed to change role: $error',
        isSubmitting: false,
      ));
    }
  }

  void clearMessages() {
    final currentState = state;
    if (currentState is ManageMembersLoaded) {
      emit(currentState.copyWith(
        successMessage: null,
        errorMessage: null,
      ));
    }
  }

  int _countRoleInRoster(ManageMembersLoaded state, UserRole role) {
    final memberCount = state.members
        .where((m) => (UserRole.fromId(m.role) ?? UserRole.practitioner) == role)
        .length;
    final inviteCount = state.pendingInvitations
        .where((i) => (UserRole.fromId(i.role) ?? UserRole.practitioner) == role)
        .length;
    return memberCount + inviteCount;
  }
}
