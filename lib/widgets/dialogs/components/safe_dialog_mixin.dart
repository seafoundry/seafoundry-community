import 'package:flutter/material.dart';

import '../../../services/logging_service.dart';
import '../../notifications/toast_overlay.dart';
import 'dialog_barrier.dart';

/// Unified mixin for safe dialog state management.
///
/// Consolidates [DialogLifecycleMixin] and [SafeAsyncMixin] into a single
/// pattern for handling:
/// - Safe navigation after async operations
/// - Safe setState calls
/// - Lifecycle-aware snackbar display
/// - Browser back button safety
///
/// Usage:
/// ```dart
/// class _MyDialogState extends State<MyDialog>
///     with SafeDialogMixin<MyDialog> {
///
///   Future<void> _save() async {
///     final result = await someAsyncOperation();
///     if (mounted) {
///       popDialog(result);
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return AlertDialog(
///       actions: [
///         TextButton(
///           onPressed: () => popDialog(),
///           child: const Text('Cancel'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
mixin SafeDialogMixin<T extends StatefulWidget> on State<T> {
  NavigatorState? _navigator;
  ScaffoldMessengerState? _messenger;

  /// Captured navigator for safe async access
  NavigatorState? get dialogNavigator => _navigator;

  /// Captured messenger for safe async access
  ScaffoldMessengerState? get dialogMessenger => _messenger;

  /// Safely access context after async operations.
  /// Returns null if the widget is no longer mounted.
  BuildContext? get safeContext => mounted ? context : null;

  @override
  @mustCallSuper
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = safeDialogNavigatorOf(context);
    _messenger = safeDialogMessengerOf(context);
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Pops the current dialog safely using the captured navigator.
  ///
  /// This is safe to call after async operations even if the widget tree
  /// has changed, as it uses the captured [NavigatorState] rather than
  /// looking it up from context.
  void popDialog<R>([R? result]) {
    if (_navigator == null) {
      LoggingService.instance.warning(
        'popDialog called but navigator is null - dialog may not have been '
        'properly initialized or was already disposed',
      );
      return;
    }
    _navigator!.pop(result);
  }

  /// Safely navigate using context only if widget is still mounted.
  void safeNavigatePop<R>([R? result]) {
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  // ---------------------------------------------------------------------------
  // State Management
  // ---------------------------------------------------------------------------

  /// Safely call setState only if the widget is still mounted.
  ///
  /// Use this after async operations to prevent "setState called after dispose"
  /// errors.
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  /// Execute a callback with the context only if the widget is still mounted.
  void withSafeContext(void Function(BuildContext context) callback) {
    if (mounted) {
      callback(context);
    }
  }

  /// Execute an async callback with the context if the widget is still mounted.
  Future<void> withSafeContextAsync(
    Future<void> Function(BuildContext context) callback,
  ) async {
    if (mounted) {
      await callback(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Async Operations
  // ---------------------------------------------------------------------------

  /// Safely execute an async operation with automatic error handling.
  ///
  /// Returns null if the operation fails or the widget is unmounted.
  Future<R?> safeAsyncOperation<R>(
    Future<R> Function() operation, {
    void Function(Object error, StackTrace stackTrace)? onError,
    String? operationName,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      if (mounted) {
        LoggingService.instance.error(
          operationName ?? 'Dialog async operation failed',
          e,
          stackTrace,
        );
        onError?.call(e, stackTrace);
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Snackbar
  // ---------------------------------------------------------------------------

  /// Shows a SnackBar using the captured messenger (lifecycle-safe).
  ///
  /// If the messenger is unavailable, the call is a no-op.
  void showDialogSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    ToastOverlay.showText(
      context,
      message,
      isError: isError,
      isSuccess: isSuccess,
      backgroundColor: backgroundColor,
      duration: duration,
      action: action,
    );
  }

  /// Shows a snackbar safely using context (requires mounted check).
  void showSafeSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    withSafeContext((context) {
      ToastOverlay.showText(
        context,
        message,
        duration: duration,
        action: action,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Show Nested Dialogs
  // ---------------------------------------------------------------------------

  /// Show a dialog safely after an async operation.
  ///
  /// Returns null if the widget is unmounted.
  Future<R?> showSafeDialog<R>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    Color? barrierColor,
  }) async {
    if (!mounted) return null;

    return showDialog<R>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      barrierColor: barrierColor ?? dialogBarrierColor(context),
      builder: builder,
    );
  }
}

// -----------------------------------------------------------------------------
// Global Helper Functions (for backward compatibility and StatelessWidget use)
// -----------------------------------------------------------------------------

/// Returns the dialog-aware [NavigatorState], falling back to the root
/// navigator when the immediate context doesn't expose one.
NavigatorState? safeDialogNavigatorOf(BuildContext context) {
  return Navigator.maybeOf(context) ??
      Navigator.maybeOf(context, rootNavigator: true);
}

/// Returns the dialog-aware [ScaffoldMessengerState], falling back to the root
/// navigator's context when the immediate scope lacks a messenger.
ScaffoldMessengerState? safeDialogMessengerOf(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    return messenger;
  }
  final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
  if (rootNavigator != null) {
    return ScaffoldMessenger.maybeOf(rootNavigator.context);
  }
  return null;
}

/// Pops the current dialog (if possible) using dialog-aware navigator lookups.
///
/// Use this for StatelessWidget dialogs or when you don't have access to
/// the mixin's captured navigator.
void popSafeDialogContext(BuildContext context, [Object? result]) {
  if (!context.mounted) return;
  safeDialogNavigatorOf(context)?.pop(result);
}

/// Shows a snackbar scoped to the nearest dialog-friendly messenger, falling
/// back to the root navigator's messenger when needed.
///
/// Use this for StatelessWidget dialogs or when you don't have access to
/// the mixin's captured messenger.
void showSafeDialogSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
}) {
  if (!context.mounted) return;
  ToastOverlay.showText(
    context,
    message,
    isError: isError,
    isSuccess: isSuccess,
    backgroundColor: backgroundColor,
    duration: duration,
    action: action,
  );
}
