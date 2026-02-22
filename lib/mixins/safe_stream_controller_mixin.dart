// @tier: community

import 'dart:async';

import 'package:seafoundry_app/services/logging_service.dart';

/// Mixin providing safe StreamController disposal patterns.
///
/// Provides methods to safely add events to StreamController sinks,
/// handling TOCTOU race conditions where the controller might close
/// between checking isClosed and calling add().
mixin SafeStreamControllerMixin {
  /// Safely add a value to a StreamController, handling closure race conditions.
  ///
  /// Returns true if the value was successfully added, false if the controller
  /// was closed (either before or during the add operation).
  ///
  /// This protects against TOCTOU (Time-Of-Check-Time-Of-Use) races where the
  /// controller might close between checking isClosed and calling add().
  bool tryAddToSink<T>(
    StreamController<T> controller,
    T value, {
    String? debugLabel,
  }) {
    try {
      controller.add(value);
      return true;
    } catch (e) {
      final label = debugLabel ?? 'StreamController';
      LoggingService.instance.debug('$label closed during add, value dropped');
      return false;
    }
  }
}
