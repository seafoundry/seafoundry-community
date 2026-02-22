// @tier: community
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Mixin for automatic stream subscription lifecycle management in Cubits/Blocs.
///
/// ## Overview
/// Provides standardized stream subscription handling for Cubits and Blocs.
/// All subscriptions registered with this mixin are automatically cancelled
/// when the Cubit/Bloc is closed, preventing memory leaks.
///
/// Note: For StatefulWidget stream management, use the separate
/// `StreamSubscriptionMixin` in `lib/mixins/stream_subscription_mixin.dart`.
///
/// ## Usage
/// ```dart
/// class MyCubit extends Cubit<MyState> with CubitStreamSubscriptionMixin {
///   MyCubit(this._repository) : super(const MyInitial());
///
///   final MyRepository _repository;
///
///   void startListening() {
///     // Simple listening with automatic lifecycle management
///     listen(
///       _repository.streamData(),
///       onData: (data) => emit(MyLoaded(data)),
///     );
///
///     // For streams that may be re-subscribed, use listenWithKey
///     listenWithKey(
///       'taskTypes',
///       _repository.streamTaskTypes(),
///       onData: (types) => emit(state.copyWith(taskTypes: types)),
///     );
///   }
///
///   // No need to override close() - subscriptions cancelled automatically
/// }
/// ```
///
/// ## Implementation Notes
/// - All subscriptions are stored and cancelled on close()
/// - Error handling is built-in with logging
/// - Use `listenWithKey` when you may re-subscribe to the same logical stream
mixin CubitStreamSubscriptionMixin on Closable {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, StreamSubscription<dynamic>> _keyedSubscriptions = {};

  /// Add a subscription to be automatically cancelled on close.
  ///
  /// Use this when you need to configure the subscription manually.
  /// For simple cases, prefer [listen] which creates the subscription for you.
  void addSubscription(StreamSubscription<dynamic> subscription) {
    _subscriptions.add(subscription);
  }

  /// Subscribe to a stream with automatic lifecycle management.
  ///
  /// This is the preferred method for subscribing to streams as it handles
  /// both subscription creation and error logging automatically.
  ///
  /// [stream] - The stream to subscribe to
  /// [onData] - Callback invoked for each data event
  /// [onError] - Optional custom error handler (default logs to LoggingService)
  /// [onDone] - Optional callback when the stream closes
  /// [cancelOnError] - Whether to cancel subscription on error (default: false)
  StreamSubscription<T> listen<T>(
    Stream<T> stream, {
    required void Function(T data) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError ?? _defaultErrorHandler,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    addSubscription(subscription);
    return subscription;
  }

  /// Subscribe to a stream with a key, automatically cancelling any previous
  /// subscription with the same key.
  ///
  /// Use this when you may re-subscribe to the same logical stream (e.g., when
  /// query parameters change). The key identifies the logical subscription,
  /// and calling this method with the same key will cancel the previous
  /// subscription before creating a new one.
  ///
  /// ```dart
  /// // Calling this twice with 'taskTypes' will cancel the first subscription
  /// listenWithKey('taskTypes', _repo.streamTaskTypes(orgId), onData: _onData);
  /// listenWithKey('taskTypes', _repo.streamTaskTypes(newOrgId), onData: _onData);
  /// ```
  StreamSubscription<T> listenWithKey<T>(
    String key,
    Stream<T> stream, {
    required void Function(T data) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) {
    // Cancel existing subscription with this key
    _keyedSubscriptions[key]?.cancel();

    final subscription = stream.listen(
      onData,
      onError: onError ?? _defaultErrorHandler,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    _keyedSubscriptions[key] = subscription;
    return subscription;
  }

  void _defaultErrorHandler(Object error, StackTrace stackTrace) {
    LoggingService.instance.error(
      'CubitStreamSubscriptionMixin: Stream error in $runtimeType',
      error,
      stackTrace,
    );
  }

  /// Cancel a specific keyed subscription.
  ///
  /// Returns true if a subscription with the given key was found and cancelled.
  bool cancelSubscription(String key) {
    final subscription = _keyedSubscriptions.remove(key);
    if (subscription != null) {
      subscription.cancel();
      return true;
    }
    return false;
  }

  /// Cancel all subscriptions and clear the lists.
  ///
  /// Called automatically on [close]. Can also be called manually to
  /// reset subscriptions before starting new ones.
  Future<void> cancelAllSubscriptions() async {
    // Cancel all subscriptions in parallel for efficiency
    await Future.wait([
      ..._subscriptions.map((s) => s.cancel()),
      ..._keyedSubscriptions.values.map((s) => s.cancel()),
    ]);
    _subscriptions.clear();
    _keyedSubscriptions.clear();
  }

  /// The number of active subscriptions (both regular and keyed).
  ///
  /// Useful for testing and debugging.
  @visibleForTesting
  int get subscriptionCount =>
      _subscriptions.length + _keyedSubscriptions.length;

  @override
  Future<void> close() async {
    await cancelAllSubscriptions();
    return super.close();
  }
}
