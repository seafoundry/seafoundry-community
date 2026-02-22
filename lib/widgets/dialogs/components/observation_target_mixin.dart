// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/dialogs/components/observation_target_selector.dart';

/// Mixin for dialogs that need ObservationTargetController lifecycle management.
///
/// Use this alongside [SafeDialogMixin] for dialogs that work with
/// observation targets (e.g., coral observation dialogs).
///
/// Usage:
/// ```dart
/// class _MyDialogState extends State<MyDialog>
///     with SafeDialogMixin<MyDialog>, ObservationTargetMixin<MyDialog> {
///
///   late final _controller = registerTargetController(
///     ObservationTargetController(),
///   );
///
///   // ... controller is automatically cleaned up on dispose
/// }
/// ```
mixin ObservationTargetMixin<T extends StatefulWidget> on State<T> {
  final Set<ObservationTargetController> _targetControllers = {};

  /// Registers an [ObservationTargetController] for automatic cleanup on dispose.
  ///
  /// Returns the same controller for chaining.
  ObservationTargetController registerTargetController(
    ObservationTargetController controller,
  ) {
    _targetControllers.add(controller);
    return controller;
  }

  /// Manually releases a controller when it should be cleared before dispose.
  void releaseTargetController(ObservationTargetController controller) {
    controller.clear();
    _targetControllers.remove(controller);
  }

  @override
  @mustCallSuper
  void dispose() {
    for (final controller in _targetControllers) {
      controller.clear();
    }
    _targetControllers.clear();
    super.dispose();
  }
}
