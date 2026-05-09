// @tier: community
// Web-specific implementation for browser location manipulation
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Sets the URL hash fragment in the browser
void setLocationHash(String hash) {
  web.window.location.hash = hash;
}

/// Replaces the browser history state without navigation
void replaceHistoryState(String url) {
  web.window.history.replaceState(''.toJS, '', url);
}
