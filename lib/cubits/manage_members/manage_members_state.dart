// @tier: community
part of 'manage_members_cubit.dart';

sealed class ManageMembersState {
  const ManageMembersState();
}

class ManageMembersInitial extends ManageMembersState {
  const ManageMembersInitial();
}

class ManageMembersLoading extends ManageMembersState {
  const ManageMembersLoading();
}

class ManageMembersLoaded extends ManageMembersState {
  final List<User> members;
  final List<Invitation> pendingInvitations;
  final Map<String, String> memberIntroNotes;
  final String currentUserId;
  final bool isSubmitting;
  final String? successMessage;
  final String? errorMessage;

  const ManageMembersLoaded({
    required this.members,
    required this.pendingInvitations,
    required this.memberIntroNotes,
    required this.currentUserId,
    this.isSubmitting = false,
    this.successMessage,
    this.errorMessage,
  });

  ManageMembersLoaded copyWith({
    List<User>? members,
    List<Invitation>? pendingInvitations,
    Map<String, String>? memberIntroNotes,
    String? currentUserId,
    bool? isSubmitting,
    String? successMessage,
    String? errorMessage,
  }) {
    return ManageMembersLoaded(
      members: members ?? this.members,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      memberIntroNotes: memberIntroNotes ?? this.memberIntroNotes,
      currentUserId: currentUserId ?? this.currentUserId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}

class ManageMembersError extends ManageMembersState {
  final String message;

  const ManageMembersError(this.message);
}
