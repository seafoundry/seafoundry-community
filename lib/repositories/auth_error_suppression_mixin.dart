// @tier: community
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seafoundry_app/services/auth_session_service.dart';

/// Mixin that provides auth-error suppression helpers for Firestore repositories.
///
/// During sign-out, Firestore streams may emit permission-denied errors as the
/// auth token is revoked. These errors are expected and should be silently
/// suppressed rather than surfaced to the UI. This mixin centralises the
/// detection logic so every repository uses the same rules.
///
/// Used by [InventoryRecordRepository], [EventRepository], and
/// [RecordRepository].
mixin AuthErrorSuppressionMixin {
  /// Returns `true` when the user is signing out (or already signed out) AND
  /// the [error] is a permission/unauthenticated error.
  ///
  /// Callers should treat a `true` result as "swallow the error silently".
  bool shouldSuppressAuthError(Object error) {
    if (!isSignedOut()) {
      return false;
    }
    return isPermissionError(error);
  }

  /// Whether the current Firebase Auth session indicates the user is signed out
  /// or in the process of signing out.
  bool isSignedOut() {
    try {
      return AuthSessionService.instance.isSigningOut ||
          FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return AuthSessionService.instance.isSigningOut;
    }
  }

  /// Whether [error] represents a Firestore permission-denied or
  /// unauthenticated error.
  bool isPermissionError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    }
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('permission') ||
        message.contains('unauthenticated');
  }
}
