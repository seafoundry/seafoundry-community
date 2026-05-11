import 'dart:async';

/// Generic stream caching helper that manages broadcast StreamControllers
/// with lazy subscription support.
///
/// This helper extracts common stream caching patterns to avoid code duplication
/// across repositories and services. It manages the lifecycle of StreamControllers,
/// including lazy subscription, cleanup, and disposal.
///
/// **Key Features:**
/// - Lazy subscription: Source stream is only subscribed when first listener attaches
/// - Broadcast support: Returned streams are always broadcast, supporting multiple listeners
/// - Error propagation: Errors from source stream are propagated to all listeners
/// - Automatic cleanup: Subscriptions are cancelled when last listener detaches
/// - Error recovery: If streamFactory throws, error is added to stream and cache entry is cleaned up
///
/// Example usage:
/// ```dart
/// final cache = StreamCache<String, List<User>>();
/// final usersStream = cache.getOrCreate(
///   'all_users',
///   () => firestore.collection('users').snapshots().map(...),
/// );
/// ```
class StreamCache<K, V> {
  /// Map of cache keys to their stream controllers
  final Map<K, StreamController<V>> _controllers = {};

  /// Map of cache keys to their active subscriptions
  final Map<K, StreamSubscription<V>> _subscriptions = {};

  /// Get or create a cached stream for the given key.
  ///
  /// If a stream already exists for [key], returns the existing stream.
  /// Otherwise, creates a new broadcast StreamController with lazy subscription.
  ///
  /// The [streamFactory] is called only when the first listener subscribes,
  /// and the subscription is cancelled when the last listener unsubscribes.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this cached stream
  /// - [streamFactory]: Factory function that creates the source stream
  ///
  /// Returns a broadcast stream that can have multiple listeners.
  Stream<V> getOrCreate(K key, Stream<V> Function() streamFactory) {
    // Return existing stream if available
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream;
    }

    // Create new stream controller with lazy subscription.
    // IMPORTANT: Controller is kept alive after last listener unsubscribes
    // because widgets may still hold stream references. Cleanup happens
    // via dispose() or explicit remove().
    final controller = StreamController<V>.broadcast(
      onListen: () {
        // Only subscribe if not already subscribed (handles re-subscription)
        if (!_subscriptions.containsKey(key)) {
          try {
            final subscription = streamFactory().listen(
              (data) {
                if (_controllers.containsKey(key) && !_controllers[key]!.isClosed) {
                  _controllers[key]!.add(data);
                }
              },
              onError: (error) {
                if (_controllers.containsKey(key) && !_controllers[key]!.isClosed) {
                  _controllers[key]!.addError(error);
                }
              },
            );
            _subscriptions[key] = subscription;
          } catch (error, stackTrace) {
            // If streamFactory() throws synchronously, add error to controller
            // and clean up the broken cache entry
            if (_controllers.containsKey(key) && !_controllers[key]!.isClosed) {
              _controllers[key]!.addError(error, stackTrace);
            }
            // Remove broken entry to allow retry on next getOrCreate call
            _controllers.remove(key);
          }
        }
      },
      onCancel: () {
        // Cancel upstream subscription but KEEP controller alive.
        // Widgets may still hold stream references and need to receive
        // updates when they re-subscribe.
        _subscriptions[key]?.cancel();
        _subscriptions.remove(key);
        // DO NOT remove controller - cleanup happens via dispose() or remove()
      },
    );

    _controllers[key] = controller;
    return controller.stream;
  }

  /// Remove a specific cache entry, cancelling its subscription and closing
  /// the controller.
  ///
  /// This is useful when you know a cached stream is no longer needed and
  /// want to clean it up immediately rather than waiting for all listeners
  /// to unsubscribe.
  void remove(K key) {
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);

    _controllers[key]?.close();
    _controllers.remove(key);
  }

  /// Remove cache entries that match the given predicate.
  ///
  /// This is useful for selective invalidation, such as clearing all caches
  /// for a specific organization when switching organizations.
  ///
  /// Example:
  /// ```dart
  /// // Clear all caches for a specific org
  /// cache.removeWhere((key) => key.startsWith('org_123'));
  /// ```
  void removeWhere(bool Function(K key) predicate) {
    final keysToRemove = _controllers.keys.where(predicate).toList();
    for (final key in keysToRemove) {
      remove(key);
    }
  }

  /// Invalidate all cached streams without disposing the cache itself.
  ///
  /// This cancels all subscriptions and closes all controllers, but the
  /// StreamCache instance can still be used to create new cached streams.
  ///
  /// This is useful when you need to refresh all data (e.g., after org switch)
  /// without destroying the cache instance.
  void invalidateAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  /// Dispose all cached streams, cancelling all subscriptions and closing
  /// all controllers.
  ///
  /// This should be called when the owning object is disposed to prevent
  /// memory leaks. After calling dispose(), this StreamCache instance should
  /// not be used again.
  void dispose() {
    invalidateAll();
  }
}
