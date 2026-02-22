// @tier: community
import 'package:flutter/material.dart';

/// Mixin to handle TextEditingController lifecycle automatically
///
/// This mixin provides a standardized way to manage TextEditingController instances
/// in widgets, ensuring they are properly disposed when the widget is disposed.
///
/// Usage:
/// ```dart
/// class MyWidget extends StatefulWidget { ... }
///
/// class _MyWidgetState extends State<MyWidget> with ControllerLifecycleMixin {
///   @override
///   void initState() {
///     super.initState();
///     final controller = TextEditingController();
///     registerController(controller);
///   }
///   // Controller is automatically disposed on dispose
/// }
/// ```
mixin ControllerLifecycleMixin<T extends StatefulWidget> on State<T> {
  final List<TextEditingController> _controllers = [];

  /// Register a controller to be automatically disposed
  void registerController(TextEditingController controller) {
    _controllers.add(controller);
  }

  /// Unregister and dispose a specific controller
  void unregisterController(TextEditingController controller) {
    controller.dispose();
    _controllers.remove(controller);
  }

  /// Dispose all registered controllers
  void disposeAllControllers() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    disposeAllControllers();
    super.dispose();
  }
}

/// Mixin for widgets that need automatic keep alive with controllers
mixin AutoKeepAliveControllerMixin<T extends StatefulWidget>
    on State<T>, AutomaticKeepAliveClientMixin<T> {
  final List<TextEditingController> _controllers = [];

  /// Register a controller to be automatically disposed
  void registerController(TextEditingController controller) {
    _controllers.add(controller);
  }

  /// Dispose all registered controllers
  void disposeAllControllers() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    disposeAllControllers();
    super.dispose();
  }
}
