// Generated Firebase configuration for the seafoundry-community demo project.
//
// If you are forking this repo to self-host, regenerate this file for your own
// Firebase project before running the app:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=YOUR_PROJECT_ID
//
// The values below are for the maintainer's project and are restricted by
// App Check + authorized-domain + HTTP-referrer rules. They are not secrets,
// but pointing your fork at them will not work — write paths require org
// membership in the seafoundry-community Firestore database.
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
    apiKey: 'AIzaSyCx1DSHSD69ssUyDSh1jJ2iY2vxdcDI47w',
    appId: '1:128847943875:web:7478e8158567b0ea23aa76',
    messagingSenderId: '128847943875',
    projectId: 'seafoundry-community-oss',
    authDomain: 'seafoundry-community-oss.firebaseapp.com',
    storageBucket: 'seafoundry-community-oss.firebasestorage.app',
  );
}
