class UserIdentity {
  const UserIdentity._();

  static String? normalizeEmail(String? email) {
    if (email == null) return null;
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  static String normalizeUserDocId(String userId) => userId.trim();
}
