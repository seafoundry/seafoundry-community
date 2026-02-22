// @tier: community
import 'package:flutter/material.dart';

import 'dialog_barrier.dart';

/// A wrapper widget that provides back button safety for dialogs.
///
/// Wraps dialog content with [PopScope] to handle browser back button
/// and system back gestures gracefully. Use this for dialogs that need
/// to prevent accidental dismissal or perform cleanup before closing.
///
/// ## Basic Usage
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => SafeDialog(
///     child: AlertDialog(
///       title: Text('My Dialog'),
///       content: Text('Content'),
///       actions: [...],
///     ),
///   ),
/// );
/// ```
///
/// ## With Confirmation
/// ```dart
/// SafeDialog(
///   canPop: false,
///   onPopInvokedWithResult: (didPop, result) {
///     if (didPop) return;
///     // Show confirmation or handle back press
///     _showExitConfirmation();
///   },
///   child: AlertDialog(...),
/// )
/// ```
///
/// ## With Async Check
/// ```dart
/// SafeDialog.withAsyncCheck(
///   canPopAsync: () async {
///     if (_hasUnsavedChanges) {
///       return await _showDiscardConfirmation();
///     }
///     return true;
///   },
///   child: AlertDialog(...),
/// )
/// ```
class SafeDialog extends StatelessWidget {
  const SafeDialog({
    super.key,
    required this.child,
    this.canPop = true,
    this.onPopInvokedWithResult,
  }) : _canPopAsync = null;

  /// Creates a SafeDialog with async pop check.
  ///
  /// Use this when you need to perform async operations (like showing
  /// a confirmation dialog) before deciding whether to allow the pop.
  const SafeDialog.withAsyncCheck({
    super.key,
    required this.child,
    required Future<bool> Function() canPopAsync,
  })  : canPop = false,
        onPopInvokedWithResult = null,
        _canPopAsync = canPopAsync;

  /// The dialog content to wrap.
  final Widget child;

  /// Whether the dialog can be popped via back button/gesture.
  ///
  /// Set to `false` to intercept back navigation and handle it manually
  /// via [onPopInvokedWithResult].
  final bool canPop;

  /// Callback invoked when a pop is attempted.
  ///
  /// [didPop] is `true` if the pop was allowed, `false` if it was blocked.
  /// Use this to show confirmations or perform cleanup.
  final PopInvokedWithResultCallback<Object?>? onPopInvokedWithResult;

  /// Async function to determine if pop should be allowed.
  final Future<bool> Function()? _canPopAsync;

  @override
  Widget build(BuildContext context) {
    if (_canPopAsync != null) {
      return _AsyncPopScopeDialog(
        canPopAsync: _canPopAsync,
        child: child,
      );
    }

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: child,
    );
  }
}

/// Internal widget for handling async pop checks.
class _AsyncPopScopeDialog extends StatefulWidget {
  const _AsyncPopScopeDialog({
    required this.canPopAsync,
    required this.child,
  });

  final Future<bool> Function()? canPopAsync;
  final Widget child;

  @override
  State<_AsyncPopScopeDialog> createState() => _AsyncPopScopeDialogState();
}

class _AsyncPopScopeDialogState extends State<_AsyncPopScopeDialog> {
  bool _isCheckingPop = false;

  Future<void> _handlePopInvoked(bool didPop, Object? result) async {
    if (didPop || _isCheckingPop) return;

    // Set guard synchronously before any await
    _isCheckingPop = true;
    if (mounted) setState(() {});

    try {
      final canPop = await widget.canPopAsync?.call() ?? true;
      if (!mounted) return;

      if (canPop) {
        Navigator.of(context).pop(result);
      }
    } finally {
      // Always reset the guard, even on error
      _isCheckingPop = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: widget.child,
    );
  }
}

/// Extension methods for showing safe dialogs.
extension SafeDialogExtensions on BuildContext {
  /// Shows a dialog wrapped in [SafeDialog] for back button safety.
  ///
  /// This is a convenience method equivalent to:
  /// ```dart
  /// showDialog(
  ///   context: context,
  ///   builder: (_) => SafeDialog(child: dialogBuilder(context)),
  /// );
  /// ```
  Future<T?> showSafeDialog<T>({
    required Widget Function(BuildContext context) builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    Color? barrierColor,
    bool canPop = true,
    PopInvokedWithResultCallback<Object?>? onPopInvokedWithResult,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      barrierColor: barrierColor ?? dialogBarrierColor(this),
      builder: (dialogContext) => SafeDialog(
        canPop: canPop,
        onPopInvokedWithResult: onPopInvokedWithResult,
        child: builder(dialogContext),
      ),
    );
  }

  /// Shows a dialog with async confirmation before allowing back navigation.
  Future<T?> showSafeDialogWithAsyncCheck<T>({
    required Widget Function(BuildContext context) builder,
    required Future<bool> Function() canPopAsync,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      barrierColor: barrierColor ?? dialogBarrierColor(this),
      builder: (dialogContext) => SafeDialog.withAsyncCheck(
        canPopAsync: canPopAsync,
        child: builder(dialogContext),
      ),
    );
  }
}
