// @tier: community
import 'package:seafoundry_app/repositories/auth/auth_repository.dart';

class PasswordRecoveryCooldownException implements Exception {
  PasswordRecoveryCooldownException(this.remaining);

  final Duration remaining;

  @override
  String toString() =>
      'Password recovery cooldown active (${remaining.inSeconds}s remaining)';
}

/// Service to throttle and resend password recovery emails.
class PasswordRecoveryService {
  PasswordRecoveryService({
    required AuthRepository authRepository,
    this.resendCooldown = const Duration(seconds: 60),
  }) : _authRepository = authRepository;

  final AuthRepository _authRepository;
  final Duration resendCooldown;
  final Map<String, DateTime> _lastSentByEmail = {};

  Future<void> sendReset({required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError('Email is required for password recovery');
    }

    final now = DateTime.now();
    final lastSent = _lastSentByEmail[normalized];
    if (lastSent != null) {
      final elapsed = now.difference(lastSent);
      if (elapsed < resendCooldown) {
        throw PasswordRecoveryCooldownException(resendCooldown - elapsed);
      }
    }

    await _authRepository.sendPasswordResetEmail(email: normalized);
    _lastSentByEmail[normalized] = now;
  }

  Duration? cooldownRemaining(String email) {
    final normalized = email.trim().toLowerCase();
    final lastSent = _lastSentByEmail[normalized];
    if (lastSent == null) return null;
    final elapsed = DateTime.now().difference(lastSent);
    if (elapsed >= resendCooldown) return null;
    return resendCooldown - elapsed;
  }
}
