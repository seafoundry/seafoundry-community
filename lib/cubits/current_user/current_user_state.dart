import 'package:equatable/equatable.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/models/user.dart';

sealed class CurrentUserState extends Equatable {
  const CurrentUserState();

  @override
  List<Object?> get props => [];
}

final class CurrentUserInitial extends CurrentUserState {}

final class CurrentUserLoading extends CurrentUserState {
  final String? message;
  const CurrentUserLoading([this.message]);

  @override
  List<Object?> get props => [message];
}

final class CurrentUserUninitialized extends CurrentUserState {
  final String uuid;

  const CurrentUserUninitialized({required this.uuid});

  @override
  List<Object?> get props => [uuid];
}

final class CurrentUserLoadedUser extends CurrentUserState {
  final User user;

  const CurrentUserLoadedUser({required this.user});

  @override
  List<Object?> get props => [user];
}

final class CurrentUserOrganizationUninitialized extends CurrentUserState {
  final User user;

  const CurrentUserOrganizationUninitialized({required this.user});

  @override
  List<Object?> get props => [user];
}

final class CurrentUserLoaded extends CurrentUserState {
  final User user;
  final Organization organization;
  final String? targetPath;

  const CurrentUserLoaded({
    required this.user,
    required this.organization,
    this.targetPath,
  });

  @override
  List<Object?> get props => [user, organization, targetPath];
}

final class CurrentUserError extends CurrentUserState {
  final String message;

  const CurrentUserError({required this.message});

  @override
  List<Object?> get props => [message];
}
