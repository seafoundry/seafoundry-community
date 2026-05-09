import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/models/graph/graph_node_streams.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Manages the graph node cache with improved performance and consistency
///
/// This service provides:
/// - Thread-safe cache operations
/// - Automatic cleanup of stale nodes
/// - Memory pressure handling
class GraphCacheManager {
  GraphCacheManager({
    this.maxCacheSize = 1000,
    this.staleTimeout = const Duration(minutes: 30),
    GraphCacheManagerConfig config = const GraphCacheManagerConfig.production(),
  }) : _config = config;

  final int maxCacheSize;
  final Duration staleTimeout;
  final GraphCacheManagerConfig _config;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Completer<GraphNode?>> _pendingLoads = {};
  Timer? _cleanupTimer;

  void startCleanupTimer() {
    if (!_config.enableCleanupTimer) {
      return;
    }
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanupStaleEntries(),
    );
  }

  /// Add a node to the cache
  void add(String urlPath, GraphNode node) {
    if (_cache.length >= maxCacheSize) {
      _evictOldestEntry();
    }

    _cache[urlPath] = _CacheEntry(node: node, lastAccessed: DateTime.now());

    LoggingService.instance.graphNodeDebug(
      'Added node to cache: $urlPath (cache size: ${_cache.length})',
    );
  }

  /// Get a node from the cache
  GraphNode? get(String urlPath) {
    final entry = _cache[urlPath];
    if (entry == null) return null;

    // Update access time
    entry.lastAccessed = DateTime.now();

    // Check if node is still valid
    if (entry.node.isClosed) {
      _cache.remove(urlPath);
      return null;
    }

    return entry.node;
  }

  /// Remove a node from the cache
  /// If [closeNode] is true, the node will be closed before removal (default: false)
  void remove(String urlPath, {bool closeNode = false}) {
    final entry = _cache[urlPath];
    if (entry != null) {
      if (closeNode) {
        entry.node.close();
      }
      _cache.remove(urlPath);
      LoggingService.instance.graphNodeDebug(
        'Removed node from cache: $urlPath (closed: $closeNode, cache size: ${_cache.length})',
      );
    }
  }

  /// Default timeout for pending loads
  static const Duration defaultLoadTimeout = Duration(seconds: 30);

  /// Register a pending load to prevent duplicate loads.
  ///
  /// The [timeout] parameter controls how long to wait before considering
  /// the load as failed. Defaults to 30 seconds.
  Future<GraphNode?> registerPendingLoad(
    String urlPath,
    Future<GraphNode?> Function() loader, {
    Duration timeout = defaultLoadTimeout,
  }) async {
    // Check if already loading
    final existing = _pendingLoads[urlPath];
    if (existing != null) {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('CacheManager: Waiting for existing load: $urlPath');
      }
      return existing.future;
    }

    if (kDebugMode) {
      LoggingService.instance.graphNodeDebug('CacheManager: Starting new load: $urlPath');
    }
    // Create new completer
    final completer = Completer<GraphNode?>();
    _pendingLoads[urlPath] = completer;

    // Start timeout timer for cleanup
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        LoggingService.instance.error(
          'GraphCacheManager: Load timeout for $urlPath after ${timeout.inSeconds}s',
        );
        _pendingLoads.remove(urlPath);
        completer.completeError(
          TimeoutException('Node load timed out: $urlPath', timeout),
        );
      }
    });

    loader().then((node) {
      timer.cancel();
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('CacheManager: Loader completed for $urlPath: ${node?.id}');
      }
      if (!completer.isCompleted) {
        completer.complete(node);
      }
    }).catchError((Object e, StackTrace stackTrace) {
      timer.cancel();
      LoggingService.instance.error('CacheManager: Loader FAILED for $urlPath', e, stackTrace);
      if (!completer.isCompleted) {
        completer.completeError(e, stackTrace);
      }
    }).whenComplete(() {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('CacheManager: Removing pending load: $urlPath');
      }
      _pendingLoads.remove(urlPath);
    });

    return completer.future;
  }

  /// Clear the entire cache
  void clear() {
    final entries = _config.cloneEntriesDuringClear
        ? List<_CacheEntry>.from(_cache.values)
        : _cache.values;

    for (final entry in entries) {
      entry.node.close();
    }
    _cache.clear();
    _pendingLoads.clear();
    LoggingService.instance.info('Cleared graph cache');
  }

  void _cleanupStaleEntries() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _cache.forEach((path, entry) {
      if (now.difference(entry.lastAccessed) > staleTimeout ||
          entry.node.isClosed) {
        toRemove.add(path);
      }
    });

    for (final path in toRemove) {
      remove(path);
    }

    if (toRemove.isNotEmpty) {
      LoggingService.instance.graphNodeDebug(
        'Cleaned up ${toRemove.length} stale cache entries',
      );
    }
  }

  void _evictOldestEntry() {
    if (_cache.isEmpty) return;

    String? oldestPath;
    DateTime? oldestTime;

    _cache.forEach((path, entry) {
      if (oldestTime == null || entry.lastAccessed.isBefore(oldestTime!)) {
        oldestPath = path;
        oldestTime = entry.lastAccessed;
      }
    });

    if (oldestPath != null) {
      // Close the node when evicting to ensure proper cleanup
      remove(oldestPath!, closeNode: true);
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    clear();
  }
}

class GraphCacheManagerConfig {
  const GraphCacheManagerConfig._({
    required this.enableCleanupTimer,
    required this.cloneEntriesDuringClear,
  });

  const GraphCacheManagerConfig.production()
    : this._(enableCleanupTimer: true, cloneEntriesDuringClear: true);

  const GraphCacheManagerConfig.test()
    : this._(enableCleanupTimer: false, cloneEntriesDuringClear: true);

  final bool enableCleanupTimer;
  final bool cloneEntriesDuringClear;
}

class _CacheEntry {
  _CacheEntry({required this.node, required this.lastAccessed});

  final GraphNode node;
  DateTime lastAccessed;
}
