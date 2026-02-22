// @tier: community
/// Interface for singleton services that need cleanup on app termination
abstract class DisposableSingleton {
  /// Release all resources (timers, streams, subscriptions)
  void dispose();

  /// Unique identifier for this singleton (for debugging/logging)
  String get singletonId;
}
