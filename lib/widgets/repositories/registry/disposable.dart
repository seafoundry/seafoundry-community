// @tier: community

/// Interface for objects that require explicit cleanup/disposal.
///
/// This interface provides a type-safe contract for objects that manage
/// resources (streams, subscriptions, controllers) that need to be cleaned up
/// when the object is no longer needed.
///
/// **Purpose**:
/// - Provides type-safe disposal instead of dynamic dispatch
/// - Makes disposal requirements explicit in the type system
/// - Enables compile-time checking for disposal capabilities
///
/// **Implementation Pattern**:
/// ```dart
/// class MyRepository implements Disposable {
///   final StreamController<Data> _controller = StreamController();
///
///   @override
///   void dispose() {
///     _controller.close();
///   }
/// }
/// ```
///
/// **Usage in Registry**:
/// ```dart
/// // Registry can check if an instance is Disposable before calling dispose
/// if (instance is Disposable) {
///   instance.dispose();
/// }
/// ```
///
/// **CRITICAL - Disposal Contract**:
///
/// Implementations MUST adhere to the following constraints:
///
/// 1. **No Dependency Access**: During dispose(), repositories MUST NOT access
///    other repositories or services from the registry. Only clean up directly-owned
///    resources (streams, subscriptions, controllers).
///
///    **Why?** The registry disposes instances in reverse creation order, which
///    approximates but does NOT guarantee dependency order. Accessing another
///    repository during dispose may fail if that repository was already disposed.
///
/// 2. **Synchronous Cleanup**: The dispose() method MUST be synchronous (void, not
///    Future\<void\>). Asynchronous cleanup creates race conditions during shutdown.
///
///    **Why?** Dart's event loop may not process async operations during app
///    termination. Synchronous dispose guarantees cleanup completes immediately.
///
/// 3. **Idempotent**: Calling dispose() multiple times MUST be safe (no-op on
///    subsequent calls).
///
///    **Why?** Error handling in the registry may result in duplicate dispose calls.
///    Use a boolean flag to guard against double-disposal.
///
/// 4. **No Exceptions**: Implementations SHOULD catch and log exceptions internally
///    rather than throwing. Exceptions during dispose can prevent cleanup of other
///    resources.
///
///    **Why?** The registry's dispose loop continues on exceptions, but throwing
///    exceptions during cleanup is an anti-pattern that complicates error handling.
///
/// **Example - Correct Implementation**:
/// ```dart
/// class MyRepository implements Disposable {
///   final StreamController<Data> _controller = StreamController();
///   StreamSubscription<Event>? _subscription;
///   bool _disposed = false;
///
///   @override
///   void dispose() {
///     if (_disposed) return; // Idempotent
///     _disposed = true;
///
///     try {
///       _subscription?.cancel(); // Clean up directly-owned resources
///       _subscription = null;
///       _controller.close();
///     } catch (e) {
///       debugPrint('Error disposing MyRepository: $e'); // Don't throw
///     }
///     // DO NOT call other repositories here!
///   }
/// }
/// ```
///
/// **Example - INCORRECT Implementation**:
/// ```dart
/// class BadRepository implements Disposable {
///   final OtherRepository _otherRepo; // Dependency
///
///   @override
///   void dispose() {
///     // WRONG: Accessing another repository during dispose
///     _otherRepo.cleanup(); // May fail if _otherRepo already disposed!
///   }
/// }
/// ```
///
/// **If You Need Pre-Dispose Coordination**:
/// If your repository requires cleanup that involves other services (e.g., flushing
/// data to another repository, sending telemetry), use one of these patterns:
///
/// 1. **Explicit Shutdown Sequence**: Call a shutdown method BEFORE dispose():
///    ```dart
///    await myRepository.shutdown(); // Async coordination with other services
///    registry.dispose(); // Synchronous cleanup only
///    ```
///
/// 2. **Pre-Dispose Callback**: Register cleanup logic outside the repository:
///    ```dart
///    void onAppTerminate() {
///      // Coordination logic here (can access all repositories)
///      await flushAllPendingData();
///      // Now safe to dispose
///      registry.dispose();
///    }
///    ```
abstract class Disposable {
  /// Releases any resources held by this object.
  ///
  /// After calling dispose, this object should not be used further.
  /// Implementations should:
  /// - Close all StreamControllers
  /// - Cancel all StreamSubscriptions
  /// - Clear any internal state/caches
  /// - Null out references to large objects
  /// - Be idempotent (safe to call multiple times)
  /// - NOT throw exceptions (catch and log internally)
  /// - NOT access other repositories or services
  void dispose();
}
