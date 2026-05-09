// @tier: community
import 'dart:async';

import 'package:rxdart/rxdart.dart';

/// Stream type classification for factory-based creation
enum StreamType {
  /// Record stream - typically 1:1 relationship, can be single-subscription
  record,

  /// Children stream - multiple listeners (parent + child nodes)
  children,

  /// Events stream - multiple listeners (UI + analytics)
  events,
}

/// Factory for creating stream controllers with appropriate configuration
///
/// **Purpose**: Centralizes stream controller creation to ensure consistent
/// broadcast/single-subscription behavior based on stream type. This prevents
/// "Stream already listened to" errors while maintaining memory efficiency.
///
/// **Design Decisions**:
/// - **Children/Events**: Use broadcast to support multiple listeners
///   during node initialization and UI updates
/// - **Record**: Keep single-subscription for 1:1 relationships (one node per record)
/// - **Sync vs Async**: Default to sync for immediate event processing, but allow
///   async for performance-critical paths
///
/// **Usage**:
/// ```dart
/// final factory = GraphStreamControllerFactory();
/// final childrenController = factory.create<List<GraphNode>>(
///   type: StreamType.children,
/// );
/// ```
class GraphStreamControllerFactory {
  const GraphStreamControllerFactory();

  /// Create a stream controller with appropriate configuration for the stream type
  ///
  /// [type] determines broadcast vs single-subscription behavior
  /// [sync] controls whether events are delivered synchronously (default: true)
  StreamController<T> create<T>({
    required StreamType type,
    bool sync = true,
  }) {
    switch (type) {
      case StreamType.children:
      case StreamType.events:
        // Broadcast for multi-listener scenarios
        return StreamController<T>.broadcast(sync: sync);

      case StreamType.record:
        // Keep single-subscription for 1:1 relationships
        return StreamController<T>(sync: sync);
    }
  }
}

/// Extension to convert streams to broadcast based on type
extension StreamBroadcastExtension<T> on Stream<T> {
  /// Convert stream to broadcast if needed for the given stream type
  ///
  /// **Usage**: Call after `.map()` or other transformations that create
  /// single-subscription streams, when multiple listeners are expected
  ///
  /// ```dart
  /// return repository.streamAll()
  ///     .map((records) => ...)
  ///     .toBroadcastIfNeeded(StreamType.children);
  /// ```
  Stream<T> toBroadcastIfNeeded(StreamType type) {
    switch (type) {
      case StreamType.children:
      case StreamType.events:
        // Use shareReplay(maxSize: 1) instead of shareValue() to cache latest value
        // and replay to new subscribers. This is critical because GraphNode subscribes twice:
        // 1. During initial CombineLatestStream.first
        // 2. After load completes via _subscribeToEvents()
        //
        // shareValue() uses refCount() which disconnects when subscriber count reaches 0.
        // This causes issues because CombineLatestStream.first disposes immediately after
        // getting one value, and in the gap before _subscribeToEvents() subscribes,
        // Firestore data emissions are lost.
        //
        // shareReplay(maxSize: 1) keeps the connection alive and replays the latest value.
        return shareReplay(maxSize: 1);

      case StreamType.record:
        // Keep single-subscription for 1:1 relationships
        return this;
    }
  }
}

