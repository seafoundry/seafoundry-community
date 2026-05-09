
/// Interface for objects that require explicit cleanup/disposal.
///
/// Provides a type-safe contract for objects that manage resources (streams,
/// subscriptions, controllers) that need to be cleaned up when no longer needed.
///
/// **Disposal contract**:
/// 1. Only clean up directly-owned resources -- do NOT access other repositories
///    or services (they may already be disposed).
/// 2. Must be synchronous (void, not `Future<void>`).
/// 3. Must be idempotent (safe to call multiple times).
/// 4. Should catch and log exceptions internally rather than throwing.
abstract class Disposable {
  /// Releases any resources held by this object.
  ///
  /// After calling dispose, this object should not be used further.
  void dispose();
}
