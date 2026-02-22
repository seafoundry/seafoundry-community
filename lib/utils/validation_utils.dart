// @tier: community
/// Shared validation utilities for the application.
///
/// Centralizes common validation logic to maintain DRY principles.
class ValidationUtils {
  ValidationUtils._();

  /// Email validation regex pattern.
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Validates an email address format.
  ///
  /// Returns `false` if:
  /// - The email is empty (after trimming)
  /// - The email doesn't match the standard email pattern
  ///
  /// The email is trimmed before validation.
  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    return _emailRegex.hasMatch(trimmed);
  }
}
