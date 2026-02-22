// @tier: community
// Stub implementation for non-web platforms

/// Clears the Firestore persistence cache.
///
/// On non-web platforms, Firestore manages its own persistence layer
/// and there's no direct way to clear it without using the Firestore API.
///
/// Returns false to indicate cache clearing is not supported.
Future<bool> clearFirestorePersistenceCache() async {
  // Non-web platforms use Firestore's native persistence
  // which requires calling FirebaseFirestore.instance.clearPersistence()
  // This should be done at the repository level with the Firestore instance
  return false;
}
