// @tier: community
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/js_error_utils.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'components/dialog_scroll_view.dart';

/// Base class for dialogs that perform async operations
///
/// This abstract class provides:
/// - Loading state management
/// - Error handling with retry
/// - Success/failure callbacks
/// - Consistent UI patterns
///
/// Usage:
/// ```dart
/// class MyAsyncDialog extends BaseAsyncDialog {
///   const MyAsyncDialog({super.key});
///
///   @override
///   String get title => 'My Dialog';
///
///   @override
///   Widget buildContent(BuildContext context) {
///     return Text('Dialog content here');
///   }
///
///   @override
///   Future<void> performAsyncOperation(BuildContext context) async {
///     // Do async work here
///     await Future.delayed(Duration(seconds: 2));
///   }
/// }
/// ```
abstract class BaseAsyncDialog extends StatefulWidget {
  const BaseAsyncDialog({super.key});

  @override
  State<BaseAsyncDialog> createState() => _BaseAsyncDialogState();
}

abstract class BaseAsyncDialogState<T extends BaseAsyncDialog> extends State<T>
    with SafeDialogMixin<T> {
  bool _isLoading = false;
  String? _error;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await initialize();
    } catch (e, stackTrace) {
      LoggingService.instance.error('Dialog initialization failed', e, stackTrace);
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> initialize() async {
    // Default: no initialization needed
  }

  String get title;
  Widget? get titleIcon => null;
  double? get dialogWidth => null;
  double? get dialogMaxHeight => null;
  bool get showCloseButton => true;
  String get primaryActionLabel => 'Save';

  Widget buildContent(BuildContext context);

  List<Widget> buildActions(BuildContext context) {
    return [
      TextButton(
        onPressed: _isLoading ? null : popDialog,
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : () => _performOperation(),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(primaryActionLabel),
      ),
    ];
  }

  Future<void> performAsyncOperation(BuildContext context);

  void onSuccess() {
    popDialog(true);
  }

  /// Called when operation fails
  void onError(dynamic error) {
    // Default: show error in UI
    final message = _resolveErrorMessage(error);
    setState(() {
      _error = message;
    });
  }

  Future<void> _performOperation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await performAsyncOperation(context);
      if (mounted) {
        onSuccess();
      }
    } catch (e, stackTrace) {
      final resolvedError = _resolveError(e);
      LoggingService.instance.error(
        'Async operation failed in ${widget.runtimeType}',
        resolvedError,
        stackTrace,
      );
      if (mounted) {
        onError(resolvedError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Object? _resolveError(Object? error) {
    if (error == null || !kIsWeb) return error;
    return unwrapJsError(error) ?? error;
  }

  String _resolveErrorMessage(Object? error) {
    if (error == null) return 'Unknown error';
    final resolved = _resolveError(error) ?? error;
    final jsDescription = describeJsError(resolved);
    if (jsDescription != null && jsDescription.isNotEmpty) {
      return jsDescription;
    }
    final message = getJsProperty(resolved, 'message');
    if (message is String && message.isNotEmpty) {
      return message;
    }
    final code = getJsProperty(resolved, 'code');
    if (code != null) {
      final codeText = code.toString();
      if (codeText.isNotEmpty) {
        return codeText;
      }
    }
    return resolved.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(),
      content: _buildContent(),
      actions: _isInitializing ? [] : buildActions(context),
    );
  }

  Widget _buildTitle() {
    final titleWidget = Text(title);

    if (titleIcon == null && !showCloseButton) {
      return titleWidget;
    }

    return Row(
      children: [
        if (titleIcon != null) ...[titleIcon!, const SizedBox(width: 8)],
        Expanded(child: titleWidget),
        if (showCloseButton && !_isLoading)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: popDialog,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isInitializing) {
      return SizedBox(
        width: dialogWidth ?? 400,
        height: 200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        width: dialogWidth ?? 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                });
                _initialize();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final content = buildContent(context);

    if (dialogWidth != null || dialogMaxHeight != null) {
      return SizedBox(
        width: dialogWidth,
        height: dialogMaxHeight,
        child: dialogMaxHeight != null
            ? DialogScrollView(child: content)
            : content,
      );
    }

    return content;
  }

  /// Utility method to show a snackbar
  void showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;

    showDialogSnackBar(message, isError: isError, isSuccess: !isError);
  }

  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  String? get error => _error;

  void clearError() {
    setState(() {
      _error = null;
    });
  }

  /// Update loading state
  void setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }
}

class _BaseAsyncDialogState extends BaseAsyncDialogState<BaseAsyncDialog> {
  @override
  String get title => 'Dialog';

  @override
  Widget buildContent(BuildContext context) {
    return const Text('Override buildContent in your dialog');
  }

  @override
  Future<void> performAsyncOperation(BuildContext context) async {
    // Default implementation - override in subclasses
  }
}
