// @tier: community
// NOTE: This file is the community entry point template - patched during sync
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/physical_form_constraint_service.dart';
import 'package:seafoundry_app/utils/firebase_emulator_config.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LoggingService.instance.initialize();
  final logger = LoggingService.instance;
  logger.info('Starting SeaFoundry Community Edition');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  logger.info('Firebase initialized');

  // Connect to emulators when USE_FIREBASE_EMULATOR=true
  if (FirebaseEmulatorConfig.useEmulators) {
    final host = FirebaseEmulatorConfig.resolveHost();
    logger.info('Connecting to Firebase emulators at $host');

    await FirebaseAuth.instance.useAuthEmulator(
      host,
      FirebaseEmulatorConfig.authPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      FirebaseEmulatorConfig.firestorePort,
    );
    await FirebaseStorage.instance.useStorageEmulator(
      host,
      FirebaseEmulatorConfig.storagePort,
    );
    logger.info('Firebase emulators connected');
  }

  // Initialize constraint services
  try {
    await PhysicalFormConstraintService.instance.initialize();
    logger.info('Constraint services initialized');
  } catch (error, stackTrace) {
    logger.error('Failed to initialize constraint services', error, stackTrace);
  }

  runApp(const App());
}
