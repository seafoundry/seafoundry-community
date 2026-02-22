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

  /// Override to provide initialization logic
  Future<void> initialize() async {
    // Default: no initialization needed
  }

  /// The dialog title
  String get title;

  /// Optional icon for the title
  Widget? get titleIcon => null;

  /// Dialog width (null for default)
  double? get dialogWidth => null;

  /// Dialog max height (null for default)
  double? get dialogMaxHeight => null;

  /// Whether to show a close button in the title
  bool get showCloseButton => true;

  /// Label for the primary action button
  String get primaryActionLabel => 'Save';

  /// Build the main content of the dialog
  Widget buildContent(BuildContext context);

  /// Build the dialog actions
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

  /// Perform the main async operation
  Future<void> performAsyncOperation(BuildContext context);

  /// Called when operation succeeds
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

  /// Check if we're currently loading
  bool get isLoading => _isLoading;

  /// Check if there's an error
  bool get hasError => _error != null;

  /// Get the current error message
  String? get error => _error;

  /// Clear the current error
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

/// Mixin for dialogs that need form validation
mixin FormValidationMixin<T extends StatefulWidget> on State<T> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  /// Validate the form
  bool validateForm() {
    return formKey.currentState?.validate() ?? false;
  }

  /// Save the form
  void saveForm() {
    formKey.currentState?.save();
  }

  /// Reset the form
  void resetForm() {
    formKey.currentState?.reset();
  }
}

/// Mixin for dialogs that handle file operations
mixin FileOperationsMixin<T extends StatefulWidget> on State<T> {
  /// Format file size for display
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get file extension
  String getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Validate file type
  bool isValidFileType(String fileName, List<String> allowedExtensions) {
    final extension = getFileExtension(fileName);
    return allowedExtensions.contains(extension);
  }
}