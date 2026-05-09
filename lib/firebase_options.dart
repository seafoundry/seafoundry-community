// @tier: community
// Generated Firebase configuration for seafoundry-community project
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError('Android not configured yet');
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured yet');
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS not configured yet');
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDOZYEwVKRRxOrgHjtMrKPA-RAoqCcgx88',
    appId: '1:100349672583:web:b4c8b535eee2fcaeaa8c22',
    messagingSenderId: '100349672583',
    projectId: 'seafoundry-community',
    authDomain: 'seafoundry-community.firebaseapp.com',
    storageBucket: 'seafoundry-community.firebasestorage.app',
  );
}
