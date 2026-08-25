import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/services/logging_service.dart';

/// Result of a safe provider read operation.
///
/// Contains either the successfully read providers or an error widget
/// to display when providers are unavailable.
class SafeProviderResult<T> {
  final T? value;
  final bool success;
  final String? errorMessage;

  const SafeProviderResult.success(this.value)
      : success = true,
        errorMessage = null;

  const SafeProviderResult.failure(this.errorMessage)
      : value = null,
        success = false;
}

/// Extension on BuildContext for safe provider reads in StatelessWidgets.
///
/// Use these methods when you need to read providers that might not be
/// available during navigation transitions (e.g., back button press).
///
/// Example usage in StatelessWidget:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final repos = context.safeReadAll(() => (
///     context.read<SiteRepository>(),
///     context.read<GroupRepository>(),
///   ));
///   if (repos == null) return const SizedBox.shrink();
///
///   final (siteRepo, groupRepo) = repos;
///   // Use the repos...
/// }
/// ```
extension SafeContextRead on BuildContext {
  /// Reads a provider, returning null if not found instead of throwing.
  ///
  /// Use this for optional provider access in dialogs where the provider
  /// may not be available in the widget tree. This is silent (no logging)
  /// since the absence is expected and intentional.
  ///
  /// Example:
  /// ```dart
  /// final siteRepository = context.maybeRead<SiteRepository>();
  /// if (siteRepository != null) {
  ///   // Use repository
  /// }
  /// ```
  T? maybeRead<T>() {
    try {
      return read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Safely reads a single provider, returning null if not found.
  ///
  /// Logs a warning when the provider is not found, which helps with debugging
  /// navigation-related issues. Use [maybeRead] instead if the absence is
  /// expected and intentional (e.g., optional providers in dialogs).
  T? safeRead<T>() {
    try {
      return read<T>();
    } on ProviderNotFoundException catch (e) {
      LoggingService.instance.warning(
        'Provider not found during context.safeRead<$T>',
        {'error': e.toString()},
      );
      return null;
    }
  }

  /// Safely reads multiple providers at once, returning null if any are missing.
  ///
  /// The [reader] callback should read all required providers synchronously.
  /// If any provider throws [ProviderNotFoundException], returns null.
  ///
  /// This is more efficient than multiple [safeRead] calls when you need
  /// all-or-nothing semantics.
  R? safeReadAll<R>(R Function() reader) {
    try {
      return reader();
    } on ProviderNotFoundException catch (e) {
      LoggingService.instance.warning(
        'Provider not found during context.safeReadAll',
        {'error': e.toString()},
      );
      return null;
    }
  }
}

/// Mixin that provides safe provider reading for StatefulWidgets.
///
/// Use this mixin to handle ProviderNotFoundException gracefully when
/// the widget tree rebuilds during async operations (e.g., auth state changes
/// causing RepositoriesProvider disposal).
///
/// Example usage:
/// ```dart
/// class _MySpreadsheetState extends State<MySpreadsheet>
///     with SafeProviderReadMixin {
///
///   Future<void> _loadData() async {
///     final result = safeReadProviders(() => (
///       context.read<SiteRepository>(),
///       context.read<GroupRepository>(),
///     ));
///
///     if (!result.success) {
///       setState(() => _error = result.errorMessage);
///       return;
///     }
///
///     final (siteRepo, groupRepo) = result.value!;
///     // Use the repos...
///   }
/// }
/// ```
mixin SafeProviderReadMixin<T extends StatefulWidget> on State<T> {
  /// Safely reads providers from the context.
  ///
  /// Returns a [SafeProviderResult] containing either the value from [reader]
  /// or an error message if providers are unavailable.
  ///
  /// The [reader] callback should read all required providers synchronously.
  /// If a [ProviderNotFoundException] is thrown, this method catches it and
  /// returns a failure result with a user-friendly error message.
  SafeProviderResult<R> safeReadProviders<R>(R Function() reader) {
    if (!mounted) {
      return const SafeProviderResult.failure('Widget no longer mounted');
    }

    try {
      final value = reader();
      return SafeProviderResult.success(value);
    } on ProviderNotFoundException catch (e) {
      LoggingService.instance.warning(
        'Provider not found - likely auth state transition',
        {'error': e.toString(), 'widget': T.toString()},
      );
      return const SafeProviderResult.failure(
        'Session expired. Please refresh the page.',
      );
    }
  }

  /// Convenience method that sets error state if providers are unavailable.
  ///
  /// Returns true if providers were read successfully, false otherwise.
  /// If false is returned, [onError] is called with the error message.
  bool tryReadProviders<R>(
    R Function() reader,
    void Function(R value) onSuccess,
    void Function(String error) onError,
  ) {
    final result = safeReadProviders(reader);
    if (result.success) {
      onSuccess(result.value as R);
      return true;
    } else {
      onError(result.errorMessage ?? 'Unknown error');
      return false;
    }
  }
}
