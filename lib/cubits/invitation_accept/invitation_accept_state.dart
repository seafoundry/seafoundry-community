// @tier: community
part of 'invitation_accept_cubit.dart';

/// Enum representing the acceptance workflow states
enum InvitationAcceptStatus {
  loading,
  success,
  error,
}

sealed class InvitationAcceptState extends Equatable {
  const InvitationAcceptState();

  @override
  List<Object?> get props => [];
}

final class InvitationAcceptInitial extends InvitationAcceptState {
  const InvitationAcceptInitial();
}

final class InvitationAcceptLoading extends InvitationAcceptState {
  const InvitationAcceptLoading();
}

final class InvitationAcceptSuccess extends InvitationAcceptState {
  const InvitationAcceptSuccess({
    this.organizationName,
  });

  final String? organizationName;

  @override
  List<Object?> get props => [organizationName];
}

final class InvitationAcceptError extends InvitationAcceptState {
  const InvitationAcceptError({
    required this.message,
  });

  final String message;

  @override
  List<Object?> get props => [message];
}
