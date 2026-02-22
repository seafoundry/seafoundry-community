// @tier: community
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/common/global_error_boundary_stub.dart'
    if (dart.library.html) 'package:seafoundry_app/widgets/common/global_error_boundary_web.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Detects if an error is a Firestore internal assertion failure
bool _isFirestoreInternalAssertionError(Object error) {
  final errorString = error.toString();
  return errorString.contains('INTERNAL ASSERTION FAILED');
}

/// Detects if an error is a transient error that occurs during auth transitions
/// (sign-out, user switch). These errors should not show the error screen -
/// the app will naturally transition to the auth screen.
bool _isTransientAuthTransitionError(Object error) {
  final errorString = error.toString();

  // Provider not found - happens when widgets try to read from disposed providers
  // during sign-out teardown
  if (errorString.contains('ProviderNotFoundException') ||
      errorString.contains('Could not find the correct Provider')) {
    return true;
  }

  // Cubit/Bloc closed - happens when listeners fire on closed cubits during teardown
  if (errorString.contains('Cannot emit new states after calling close') ||
      errorString.contains('Bad state: Cannot add new events after calling close')) {
    return true;
  }

  // Widget disposed errors during teardown
  if (errorString.contains('A disposed member should not be used') ||
      errorString.contains('This widget has been unmounted')) {
    return true;
  }

  // Null check errors on context during teardown
  if (errorString.contains('Null check operator used on a null value') &&
      errorString.contains('context')) {
    return true;
  }

  return false;
}

/// Global error boundary that catches uncaught errors at the app level.
///
/// Specifically detects Firestore internal assertion errors and provides
/// a user-friendly error screen with cache clearing options.
class GlobalErrorBoundary extends StatefulWidget {
  const GlobalErrorBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  Object? _error;
  bool _isFirestoreCacheError = false;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _setupErrorHandling();
  }

  void _setupErrorHandling() {
    // Override FlutterError.onError to catch errors during layout/paint phase
    // This complements ErrorWidget.builder which only catches build-time errors
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Skip transient errors during auth transitions
      if (_isTransientAuthTransitionError(details.exception)) {
        LoggingService.instance.debug(
          'GlobalErrorBoundary (onError): Ignoring transient auth transition error: ${details.exception}',
        );
        return;
      }

      // Log and handle the error
      LoggingService.instance.error(
        'GlobalErrorBoundary (onError): Flutter error during ${details.library ?? "unknown"}',
        details.exception,
        details.stack,
      );

      // Call original handler for crash reporting etc.
      originalOnError?.call(details);
    };

    // Override the default ErrorWidget.builder to capture build-time errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Skip transient errors that occur during auth transitions (sign-out, user switch).
      // These are expected during teardown and the app will naturally transition to auth screen.
      if (_isTransientAuthTransitionError(details.exception)) {
        LoggingService.instance.debug(
          'GlobalErrorBoundary: Ignoring transient auth transition error: ${details.exception}',
        );
        // Show loading indicator while app transitions to auth screen.
        // Use SizedBox.expand + ColoredBox to fill screen without Material ancestor.
        return const SizedBox.expand(
          child: ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }

      _handleError(details.exception, details.stack);
      // Show loading indicator while state updates (instead of blank white screen).
      // Use SizedBox.expand + ColoredBox to fill screen without Material ancestor.
      return const SizedBox.expand(
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    // Don't set error state for transient auth transition errors -
    // the app will naturally transition to the auth screen
    if (_isTransientAuthTransitionError(error)) {
      return;
    }

    LoggingService.instance.error(
      'GlobalErrorBoundary caught error',
      error,
      stackTrace,
    );

    final isFirestoreError = _isFirestoreInternalAssertionError(error);

    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _error = error;
          _isFirestoreCacheError = isFirestoreError;
        });
      }
    });
  }

  Future<void> _clearCacheAndReload() async {
    if (!kIsWeb) return;

    setState(() => _isClearing = true);

    try {
      LoggingService.instance.info(
        'Clearing IndexedDB cache and reloading...',
      );
      clearIndexedDbCache();
      // Small delay to ensure IndexedDB deletion is processed
      await Future.delayed(const Duration(milliseconds: 500));
      reloadPage();
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to clear cache',
        e,
        stackTrace,
      );
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  void _tryAgain() {
    if (kIsWeb) {
      reloadPage();
    } else {
      // On non-web platforms, just reset the error state
      setState(() {
        _error = null;
        _isFirestoreCacheError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(
        error: _error!,
        isFirestoreCacheError: _isFirestoreCacheError,
        isClearing: _isClearing,
        onClearCache: _clearCacheAndReload,
        onTryAgain: _tryAgain,
      );
    }

    return widget.child;
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.error,
    required this.isFirestoreCacheError,
    required this.isClearing,
    required this.onClearCache,
    required this.onTryAgain,
  });

  final Object error;
  final bool isFirestoreCacheError;
  final bool isClearing;
  final VoidCallback onClearCache;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: UI.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: UI.screenPaddingAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIcon(),
                    UI.spacingVerticalLg,
                    _buildTitle(),
                    UI.spacingVerticalMd,
                    _buildMessage(),
                    UI.spacingVerticalXl,
                    _buildActions(),
                    if (!isFirestoreCacheError) ...[
                      UI.spacingVerticalXl,
                      _buildErrorDetails(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return UI.roundedIcon(
      isFirestoreCacheError ? Icons.storage_outlined : Icons.error_outline,
      size: UI.iconSizeXl,
      backgroundColor: UI.errorColor.withValues(alpha: 0.1),
      iconColor: UI.errorColor,
    );
  }

  Widget _buildTitle() {
    final title = isFirestoreCacheError
        ? 'Database Cache Error'
        : 'Something went wrong';
    return UIText.h2(title, textAlign: TextAlign.center);
  }

  Widget _buildMessage() {
    final message = isFirestoreCacheError
        ? 'The local database cache appears to be corrupted. '
            'This can happen after browser updates or storage issues. '
            'Clearing the cache should resolve this problem.'
        : 'An unexpected error occurred. Please try again.';
    return UIText.bodyMedium(
      message,
      textAlign: TextAlign.center,
      color: UI.textSecondaryColor,
    );
  }

  Widget _buildActions() {
    if (isClearing) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          UI.spacingVerticalMd,
          UIText.bodySmall(
            'Clearing cache...',
            color: UI.textSecondaryColor,
          ),
        ],
      );
    }

    return Column(
      children: [
        if (isFirestoreCacheError && kIsWeb)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onClearCache,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Clear Cache & Reload'),
            ),
          ),
        if (isFirestoreCacheError && kIsWeb) UI.spacingVerticalMd,
        SizedBox(
          width: double.infinity,
          child: isFirestoreCacheError && kIsWeb
              ? OutlinedButton.icon(
                  onPressed: onTryAgain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                )
              : FilledButton.icon(
                  onPressed: onTryAgain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
        ),
      ],
    );
  }

  Widget _buildErrorDetails() {
    return Container(
      padding: UI.paddingMd,
      decoration: UI.roundedBox(
        color: UI.surfaceColor,
        borderRadius: UI.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UI.iconSmall(Icons.code, color: UI.textSecondaryColor),
              UI.spacingHorizontalSm,
              UIText.h6('Error Details'),
            ],
          ),
          UI.spacingVerticalSm,
          SelectableText(
            error.toString(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: UI.fontSizeXs,
              color: UI.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
