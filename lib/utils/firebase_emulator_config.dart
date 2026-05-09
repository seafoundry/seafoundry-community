import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Shared Firebase emulator configuration utilities.
///
/// Used by [main.dart] for SDK-level emulator setup and
/// HTTP endpoint resolution.
class FirebaseEmulatorConfig {
  const FirebaseEmulatorConfig._();

  static const bool useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static const int authPort = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9555,
  );

  static const int firestorePort = int.fromEnvironment(
    'FIREBASE_FIRESTORE_EMULATOR_PORT',
    defaultValue: 58080,
  );

  static const int storagePort = int.fromEnvironment(
    'FIREBASE_STORAGE_EMULATOR_PORT',
    defaultValue: 59199,
  );

  static const int functionsPort = int.fromEnvironment(
    'FIREBASE_FUNCTIONS_EMULATOR_PORT',
    defaultValue: 5001,
  );

  static String resolveHost() {
    const hostOverride = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    if (hostOverride.isNotEmpty) {
      return hostOverride;
    }
    if (kIsWeb) {
      return 'localhost';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      default:
        return 'localhost';
    }
  }
}
