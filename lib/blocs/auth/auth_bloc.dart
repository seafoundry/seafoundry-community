import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seafoundry_app/blocs/auth/auth_state.dart';
import 'package:seafoundry_app/navigation/web_location_stub.dart'
    if (dart.library.html) 'package:seafoundry_app/navigation/web_location_web.dart';
import 'package:seafoundry_app/repositories/auth/auth_repository.dart';
import 'package:seafoundry_app/services/auth_session_service.dart';
import 'package:seafoundry_app/services/cache_manager.dart';
import 'package:seafoundry_app/services/google_sign_in_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/password_recovery_service.dart';

/// BLoC for handling authentication status (signed in/out).
///
/// This bloc handles only authentication status. [CurrentUser] is the single
/// source of truth for user profile data (name, role, etc.). The [displayName]
/// field in [AuthAuthenticated] is only used during the initial sign-up flow
/// to bridge the race condition where Firebase's authStateChanges fires before
/// updateDisplayName completes - it should not be used as a source of truth
/// after the user is loaded in [CurrentUser].
class AuthBloc extends SafeCubit<AuthState> {
  final AuthRepository _authRepository;
  final GoogleSignInService _googleSignInService;
  final PasswordRecoveryService _passwordRecoveryService;
  StreamSubscription<User?>? _authStateSubscription;
  bool _hasAuthStateEmission = false;
  bool _isSigningOut = false;

  /// Temporarily stores the display name from signUp() so that
  /// _handleAuthStateChanged can include it in AuthAuthenticated.
  /// Cleared after first use.
  String? _pendingDisplayName;

  AuthBloc({
    required AuthRepository authRepository,
    GoogleSignInService? googleSignInService,
    PasswordRecoveryService? passwordRecoveryService,
  }) : _authRepository = authRepository,
       _googleSignInService =
           googleSignInService ?? GoogleSignInService.instance,
       _passwordRecoveryService =
           passwordRecoveryService ??
           PasswordRecoveryService(authRepository: authRepository),
       super(const AuthInitial());

  Future<void> initialize() async {
    emit(const AuthLoading('Checking authentication...'));

    // Listen to auth state changes
    await _authStateSubscription?.cancel();
    _hasAuthStateEmission = false;
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) {
        _hasAuthStateEmission = true;
        _handleAuthStateChanged(user: user, allowFallback: false);
      },
      onError: (error, stackTrace) {
        _hasAuthStateEmission = true;
        LoggingService.instance.error(
          'Auth state stream error - falling back to unauthenticated',
          error,
          stackTrace,
        );
        emit(const AuthUnauthenticated());
      },
    );

    // Fallback: if authStateChanges doesn't emit, resolve from current user.
    unawaited(_resolveInitialAuthState());
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthLoading('Signing in...'));

    try {
      await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // AuthStateChanged will handle the success case
    } on FirebaseAuthException catch (e, st) {
      LoggingService.instance.error('Sign in failed', e, st);
      emit(
        AuthError(
          message: _getAuthErrorMessage(e),
          code: _normalizeAuthCode(e.code),
        ),
      );
    } catch (e, st) {
      // Handle Firebase REST API errors that aren't wrapped as FirebaseAuthException
      final extractedCode = _extractErrorCode(e);
      final message = _getAuthErrorMessageFromCode(extractedCode);
      if (message != null) {
        emit(AuthError(message: message, code: extractedCode));
      } else {
        LoggingService.instance.error('Sign in failed', e, st);
        emit(AuthError(message: 'Sign in failed. Please try again.'));
      }
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    emit(const AuthLoading('Creating account...'));

    try {
      final normalizedDisplayName = displayName.trim();
      final normalizedEmail = email.trim();

      // Store the display name BEFORE creating the user, because
      // createUserWithEmailAndPassword triggers authStateChanges
      // before updateDisplayName can complete.
      if (normalizedDisplayName.isNotEmpty) {
        _pendingDisplayName = normalizedDisplayName;
      }

      final credential = await _authRepository.signUpWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      if (normalizedDisplayName.isNotEmpty) {
        await credential.user?.updateDisplayName(normalizedDisplayName);
      }

      // AuthStateChanged will handle the success case
    } on FirebaseAuthException catch (e, st) {
      _pendingDisplayName = null;
      LoggingService.instance.error('Sign up failed', e, st);
      emit(
        AuthError(
          message: _getAuthErrorMessage(e),
          code: _normalizeAuthCode(e.code),
        ),
      );
    } catch (e, st) {
      _pendingDisplayName = null;
      final extractedCode = _extractErrorCode(e);
      final message = _getAuthErrorMessageFromCode(extractedCode);
      if (message != null) {
        emit(AuthError(message: message, code: extractedCode));
      } else {
        LoggingService.instance.error('Sign up failed', e, st);
        emit(AuthError(message: 'Sign up failed. Please try again.'));
      }
    }
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthLoading('Signing in with Google...'));

    // Google Sign-In on web requires using the JavaScript API renderButton method
    // For now, show an error message directing users to use email/password
    if (kIsWeb) {
      emit(
        const AuthError(
          message:
              'Google Sign-In is not yet available on web. Please use email and password to sign in.',
        ),
      );
      return;
    }

    try {
      // Use GoogleSignInService which ensures initialization is complete
      final GoogleSignInAccount googleUser = await _googleSignInService
          .authenticate();

      await _authenticateWithGoogleUser(googleUser);
    } on GoogleSignInNotReadyException catch (e) {
      LoggingService.instance.warning('Google sign in not ready', e);
      emit(
        AuthError(
          message:
              'Google Sign-In is temporarily unavailable. Please try again or use email and password.',
          code: 'google-sign-in-not-ready',
        ),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        emit(const AuthUnauthenticated());
        return;
      }
      LoggingService.instance.info('Google sign in failed', e);
      emit(
        AuthError(
          message: 'Google sign in failed: ${e.description ?? e.code.name}',
          code: e.code.name,
        ),
      );
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _getAuthErrorMessage(e), code: e.code));
    } catch (e) {
      LoggingService.instance.info('Google sign in failed', e);
      emit(AuthError(message: 'Google sign in failed: $e'));
    }
  }

  Future<void> completeGoogleSignIn({
    required GoogleSignInAccount googleUser,
  }) async {
    emit(const AuthLoading('Signing in with Google...'));

    try {
      await _authenticateWithGoogleUser(googleUser);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _getAuthErrorMessage(e), code: e.code));
    } catch (e) {
      LoggingService.instance.info('Google sign in failed', e);
      emit(AuthError(message: 'Google sign in failed: $e'));
    }
  }

  Future<void> _authenticateWithGoogleUser(
    GoogleSignInAccount googleUser,
  ) async {
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    // On web, authorizationForScopes can throw errors since renderButton()
    // handles authentication differently from mobile platforms.
    // For Firebase Auth, we only need the idToken - skip authorization on web.
    String? accessToken;
    if (!kIsWeb) {
      try {
        final clientAuthorization = await googleUser.authorizationClient
            .authorizationForScopes(const ['email', 'profile']);
        accessToken = clientAuthorization?.accessToken;
      } catch (error) {
        LoggingService.instance.warning(
          'Failed to fetch Google client authorization',
          error,
        );
      }
    }

    if (idToken == null && accessToken == null) {
      emit(
        const AuthError(
          message: 'Google sign in failed: Missing Google auth tokens.',
        ),
      );
      return;
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );

    // Sign in with credential using AuthRepository
    await _authRepository.signInWithCredential(credential);
    // AuthStateChanged will handle the success case
  }

  Future<void> sendPasswordReset({required String email}) async {
    emit(const AuthLoading('Sending password reset...'));

    try {
      await _passwordRecoveryService.sendReset(email: email);
      emit(AuthPasswordResetSent(email: email));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _getAuthErrorMessage(e), code: e.code));
    } on PasswordRecoveryCooldownException catch (e) {
      emit(
        AuthError(
          message:
              'Please wait ${e.remaining.inSeconds}s before requesting another reset email.',
          code: 'password-reset-cooldown',
        ),
      );
    } catch (e) {
      emit(AuthError(message: 'Failed to send password reset: $e'));
    }
  }

  Future<void> signOut() async {
    if (_isSigningOut) {
      LoggingService.instance.debug('AuthBloc.signOut called while already signing out');
      return;
    }
    _isSigningOut = true;
    AuthSessionService.instance.beginSignOut();
    emit(const AuthLoading('Signing out...'));

    const cleanupTimeout = Duration(seconds: 5);
    final fallbackTimer = Timer(
      cleanupTimeout + const Duration(seconds: 1),
      () {
        if (isClosed) return;
        if (state is AuthLoading) {
          LoggingService.instance.warning(
            'AuthBloc sign out fallback triggered; forcing unauthenticated state',
          );
          emit(const AuthUnauthenticated());
        }
      },
    );
    try {
      try {
        CacheManager.instance.clearAllCaches();
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to clear caches during sign out',
          e,
          stackTrace,
        );
      }
      // Sign out from Firebase Auth first
      await _authRepository.signOut().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          LoggingService.instance.warning(
            'Firebase sign out timed out during logout',
          );
        },
      );

      // Sign out from Google (non-blocking with timeout)
      unawaited(
        _googleSignInService
            .signOut()
            .timeout(
              const Duration(seconds: 4),
              onTimeout: () {
                LoggingService.instance.warning(
                  'Google Sign-In sign out timed out during logout',
                );
              },
            )
            .catchError((error) {
              LoggingService.instance.warning(
                'Google Sign-In sign out failed during logout: $error',
              );
            }),
      );

      // CRITICAL: Clear URL hash on web after sign out to prevent stale routes
      // on subsequent login. Without this, the URL may retain paths like
      // deep links that the next user may not have access to.
      if (kIsWeb) {
        try {
          replaceHistoryState('/');
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to replace history state during sign out',
            e,
          );
        }
      }

      // Explicitly emit unauthenticated state after sign out completes.
      // Don't rely solely on authStateChanges stream as it may not fire
      // reliably on web.
      emit(const AuthUnauthenticated());
    } catch (e) {
      LoggingService.instance.error('Sign out failed', e);
      // Check actual Firebase auth state before deciding what to emit.
      // If Firebase still has a valid user, sign out didn't actually complete
      // and we should show an error rather than forcing to login screen.
      final currentUser = _authRepository.currentFirebaseUser;
      if (currentUser != null) {
        // User is still authenticated - sign out failed, show error
        emit(
          const AuthError(
            message: 'Sign out failed. Please check your connection and try again.',
            code: 'sign-out-failed',
          ),
        );
      } else {
        // User is actually signed out (perhaps partial success), proceed
        emit(const AuthUnauthenticated());
      }
    } finally {
      fallbackTimer.cancel();
      AuthSessionService.instance.endSignOut();
      _isSigningOut = false;
    }
  }

  void clearError() {
    emit(const AuthUnauthenticated());
  }

  Future<void> _resolveInitialAuthState() async {
    final delay = kIsWeb
        ? const Duration(milliseconds: 750)
        : const Duration(milliseconds: 200);
    await Future.delayed(delay);
    if (_hasAuthStateEmission || isClosed) {
      return;
    }
    LoggingService.instance.warning(
      'Auth state stream did not emit; using current user fallback',
    );
    _handleAuthStateChanged(allowFallback: true);
  }

  void _handleAuthStateChanged({
    User? user,
    bool allowFallback = false,
  }) {
    if (_isSigningOut && user != null) {
      LoggingService.instance.debug(
        'Auth state change ignored during sign out',
      );
      return;
    }
    final resolvedUser =
        user ?? (allowFallback ? _authRepository.currentFirebaseUser : null);
    if (resolvedUser != null) {
      final pendingName = _pendingDisplayName;
      _pendingDisplayName = null;
      emit(AuthAuthenticated(
        authUser: resolvedUser,
        displayName: pendingName,
      ));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    final message = _getAuthErrorMessageFromCode(e.code);
    return message ?? e.message ?? 'Authentication failed. Please try again.';
  }

  String? _getAuthErrorMessageFromCode(String? code) {
    final normalizedCode = _normalizeAuthCode(code);
    switch (normalizedCode) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'missing-email':
        return 'Please enter your email address.';
      case 'missing-password':
        return 'Please enter your password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled for this project.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for authentication.';
      case 'invalid-api-key':
      case 'api-key-http-referrer-blocked':
      case 'app-not-authorized':
        return 'Invalid or blocked Firebase API key for this domain.';
      case 'configuration-not-found':
      case 'project-not-found':
      case 'invalid-app-id':
        return 'Firebase configuration mismatch for this build.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return null;
    }
  }

  /// Extract error code from various error formats
  String? _extractErrorCode(Object error) {
    if (error is FirebaseAuthException) {
      return _normalizeAuthCode(error.code);
    }
    if (error is FirebaseException) {
      return _normalizeAuthCode(error.code);
    }

    final errorString = error.toString();
    final authMatch = RegExp(r'auth/([a-z-]+)').firstMatch(errorString);
    if (authMatch != null) {
      return _normalizeAuthCode(authMatch.group(1));
    }

    for (final entry in _restApiErrorCodeMap.entries) {
      if (errorString.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  String? _normalizeAuthCode(String? code) {
    if (code == null) return null;
    return _restApiErrorCodeMap[code] ?? code;
  }

  static const Map<String, String> _restApiErrorCodeMap = {
    'INVALID_LOGIN_CREDENTIALS': 'invalid-credential',
    'INVALID_PASSWORD': 'wrong-password',
    'EMAIL_NOT_FOUND': 'user-not-found',
    'EMAIL_EXISTS': 'email-already-in-use',
    'ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL':
        'account-exists-with-different-credential',
    'CREDENTIAL_ALREADY_IN_USE': 'credential-already-in-use',
    'OPERATION_NOT_ALLOWED': 'operation-not-allowed',
    'PASSWORD_LOGIN_DISABLED': 'operation-not-allowed',
    'TOO_MANY_ATTEMPTS_TRY_LATER': 'too-many-requests',
    'INVALID_EMAIL': 'invalid-email',
    'MISSING_EMAIL': 'missing-email',
    'MISSING_PASSWORD': 'missing-password',
    'WEAK_PASSWORD': 'weak-password',
    'USER_DISABLED': 'user-disabled',
    'INVALID_API_KEY': 'invalid-api-key',
    'API_KEY_INVALID': 'invalid-api-key',
    'API_KEY_HTTP_REFERRER_BLOCKED': 'api-key-http-referrer-blocked',
    'APP_NOT_AUTHORIZED': 'app-not-authorized',
    'UNAUTHORIZED_DOMAIN': 'unauthorized-domain',
    'CONFIGURATION_NOT_FOUND': 'configuration-not-found',
    'PROJECT_NOT_FOUND': 'project-not-found',
    'INVALID_APP_ID': 'invalid-app-id',
  };

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
