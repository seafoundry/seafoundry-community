// @tier: community
// NOTE: This file is the community entry point template - patched during sync
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/life_stage_constraint_service.dart';
import 'package:seafoundry_app/services/physical_form_constraint_service.dart';

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

  // Initialize constraint services
  try {
    await PhysicalFormConstraintService.instance.initialize();
    await LifeStageConstraintService.instance.initialize();
    logger.info('Constraint services initialized');
  } catch (error, stackTrace) {
    logger.error('Failed to initialize constraint services', error, stackTrace);
  }

  runApp(const App());
}
