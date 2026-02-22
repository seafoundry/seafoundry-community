// @tier: community
// ignore_for_file: avoid_web_libraries_in_flutter
// Web implementation using dart:html
// ignore: deprecated_member_use
import 'dart:html' as html;

/// Clears IndexedDB Firestore cache on web platforms
void clearIndexedDbCache() {
  html.window.indexedDB?.deleteDatabase('firestore/[DEFAULT]/seafoundryapp/main');
}

/// Reloads the page on web platforms
void reloadPage() {
  html.window.location.reload();
}
