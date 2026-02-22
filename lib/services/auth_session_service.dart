// @tier: community
import 'package:seafoundry_app/services/logging_service.dart';

/// Tracks transient auth session transitions like sign-out in progress.
///
/// Repositories use this to suppress expected permission errors while
/// Firebase auth tokens are being invalidated during logout.
class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();

  bool _isSigningOut = false;

  bool get isSigningOut => _isSigningOut;

  void beginSignOut() {
    if (_isSigningOut) {
      return;
    }
    _isSigningOut = true;
    LoggingService.instance.debug('AuthSessionService: sign-out started');
  }

  void endSignOut() {
    if (!_isSigningOut) {
      return;
    }
    _isSigningOut = false;
    LoggingService.instance.debug('AuthSessionService: sign-out ended');
  }
}
