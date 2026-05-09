// @tier: community
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

/// States for authentication
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state - checking auth status
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state - processing auth request
final class AuthLoading extends AuthState {
  final String message;

  const AuthLoading([this.message = 'Processing...']);

  @override
  List<Object?> get props => [message];
}

/// User is not authenticated
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// User is authenticated.
///
/// [CurrentUser] is the single source of truth for user profile data.
/// The [displayName] field here is ONLY used during initial sign-up to bridge
/// the race condition where Firebase's authStateChanges fires before
/// updateDisplayName completes. After the user is loaded in [CurrentUser],
/// use the profile data from there instead of this field.
final class AuthAuthenticated extends AuthState {
  final auth.User authUser;

  /// Explicit display name from sign-up, carried here because
  /// [authStateChanges] fires before [updateDisplayName] completes,
  /// so [authUser.displayName] may still be null at this point.
  ///
  /// **Important**: This is only for initial sign-up flow. Always prefer
  /// [CurrentUser] as the source of truth for user profile data after
  /// initial load.
  final String? displayName;

  const AuthAuthenticated({required this.authUser, this.displayName});

  AuthAuthenticated copyWith({String? displayName}) {
    return AuthAuthenticated(
      authUser: authUser,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => [authUser.uid, displayName];
}

/// Authentication error occurred
final class AuthError extends AuthState {
  final String message;
  final String? code;

  const AuthError({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Password reset email sent
final class AuthPasswordResetSent extends AuthState {
  final String email;

  const AuthPasswordResetSent({required this.email});

  @override
  List<Object?> get props => [email];
}
