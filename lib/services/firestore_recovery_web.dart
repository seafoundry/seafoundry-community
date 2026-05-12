// ignore_for_file: deprecated_member_use
// Web implementation using dart:html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../firebase_options.dart';

/// Clears the Firestore persistence cache on web platforms.
///
/// Firestore on web uses IndexedDB for persistence. This function
/// deletes the IndexedDB databases that match the Firestore naming
/// pattern for the configured project.
///
/// The database name pattern is `firestore/[DEFAULT]/{project-id}/main`,
/// so we derive the project ID at runtime from `firebase_options.dart`.
///
/// Returns true if the deletion was initiated.
Future<bool> clearFirestorePersistenceCache() async {
  final indexedDb = html.window.indexedDB;
  if (indexedDb == null) {
    return false;
  }

  final projectId = DefaultFirebaseOptions.web.projectId;
  final databaseNames = <String>{
    'firestore/[DEFAULT]/$projectId/main',
    'firestore/[DEFAULT]/$projectId-demo/main',
  };

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
