// @tier: community
// ignore_for_file: deprecated_member_use
// Web implementation using dart:html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Clears the Firestore persistence cache on web platforms.
///
/// Firestore on web uses IndexedDB for persistence. This function
/// deletes the IndexedDB database to clear the cache.
///
/// Note: The database name pattern is 'firestore/[DEFAULT]/{project-id}/main'
/// We use a pattern that matches common Firestore database names.
///
/// Returns true if the deletion was initiated.
Future<bool> clearFirestorePersistenceCache() async {
  final indexedDb = html.window.indexedDB;
  if (indexedDb == null) {
    return false;
  }

  // Firestore IndexedDB database names follow this pattern:
  // firestore/[DEFAULT]/{project-id}/main
  // We'll delete databases matching common patterns
  final databaseNames = [
    'firestore/[DEFAULT]/seafoundryapp/main',
    'firestore/[DEFAULT]/seafoundry-app/main',
    'firestore/[DEFAULT]/seafoundry/main',
    // Add the demo database as well
    'firestore/[DEFAULT]/seafoundryapp-demo/main',
  ];

  var deleted = false;
  for (final dbName in databaseNames) {
    try {
      indexedDb.deleteDatabase(dbName);
      deleted = true;
    } catch (_) {
      // Ignore errors for databases that don't exist
    }
  }

  // Give the browser time to process the deletion
  await Future.delayed(const Duration(milliseconds: 100));

  return deleted;
}
