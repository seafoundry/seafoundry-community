import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:seafoundry_community/services/logging_service.dart';

/// Describes the mode used by a [GraphRepositoryStreamController].
enum GraphRepositoryStreamMode {
  /// Forward events immediately (default production behaviour).
  immediate,

  /// Hold events until [`flush`] or [`resume`] is invoked.
  manualFlush,

  /// Delay propagation until a scheduled flush window elapses.
  ///
  /// (Initial implementation treats this as manual flush with optional
  /// deferred triggers; future revisions can expand behaviour.)
  deferred,
}

/// Metadata describing the stream being wrapped. Useful for diagnostics.
class GraphRepositoryStreamMetadata {
  const GraphRepositoryStreamMetadata({
    required this.collectionName,
    required this.entity,
    required this.debugLabel,
  });

  final String collectionName;
  final GraphRepositoryStreamEntity entity;
  final String debugLabel;
}

/// High-level entity classification for graph-backed streams.
enum GraphRepositoryStreamEntity {
  organization,
  site,
  zone,
  subplot,
  group,
  coral,
  event,
  other,
}

/// Snapshot of controller diagnostics for harness assertions and logging.
class GraphRepositoryStreamDiagnostics {
  const GraphRepositoryStreamDiagnostics({
    required this.isPaused,
    required this.pendingItemCount,
    required this.lastEmittedAt,
    required this.mode,
  });

  final bool isPaused;
  final int pendingItemCount;
  final DateTime? lastEmittedAt;
  final GraphRepositoryStreamMode mode;
}

/// Public interface exposed to tests for manipulating wrapped streams.
abstract class GraphRepositoryStreamToken<T> {
  Stream<T> get stream;

  Future<void> flush();

  void inject(T value);

  GraphRepositoryStreamDiagnostics diagnostics();

  Future<void> dispose();
}

/// Factory signature used by GraphRepository to wrap repository streams.
typedef GraphRepositoryStreamControllerFactory =
    GraphRepositoryStreamController<T> Function<T>(
      Stream<T> source,
      GraphRepositoryStreamMetadata metadata,
    );

/// Internal controller implementation used to orchestrate repository streams.
class GraphRepositoryStreamController<T>
    implements GraphRepositoryStreamToken<T> {
  GraphRepositoryStreamController(
    Stream<T> source,
    this._metadata, {
    GraphRepositoryStreamMode mode = GraphRepositoryStreamMode.immediate,
    this.maxQueueLength = 50,
    this.deferredFlushInterval,
  }) : _mode = mode,
       _controller = StreamController<T>.broadcast(),
       _queue = ListQueue<T>(maxQueueLength) {
    _isPaused = mode != GraphRepositoryStreamMode.immediate;
    _subscription = source.listen(
      _handleData,
      onError: _controller.addError,
      onDone: () {
        if (!_controller.isClosed) {
          _controller.close();
        }
      },
    );
  }

  final GraphRepositoryStreamMetadata _metadata;
  final int maxQueueLength;
  final Duration? deferredFlushInterval;
  final GraphRepositoryStreamMode _mode;

  late bool _isPaused;
  bool _isDisposed = false;
  DateTime? _lastEmittedAt;

  final ListQueue<T> _queue;
  final StreamController<T> _controller;
  StreamSubscription<T>? _subscription;
  Timer? _deferredTimer;

  @override
  Stream<T> get stream => _controller.stream;

  @override
  Future<void> flush() async {
    if (_isDisposed || _queue.isEmpty) {
      return;
    }

    final pendingValues = <T>[];
    while (_queue.isNotEmpty) {
      pendingValues.add(_queue.removeFirst());
    }

    for (final value in pendingValues) {
      _emit(value);
    }
  }

  @override
  void inject(T value) {
    if (_isDisposed) {
      return;
    }
    if (_isPaused) {
      _enqueue(value);
    } else {
      _emit(value);
    }
  }

  @override
  GraphRepositoryStreamDiagnostics diagnostics() {
    return GraphRepositoryStreamDiagnostics(
      isPaused: _isPaused,
      pendingItemCount: _queue.length,
      lastEmittedAt: _lastEmittedAt,
      mode: _mode,
    );
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _cancelDeferredTimer();
    await _subscription?.cancel();
    _subscription = null;
    _queue.clear();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void _handleData(T event) {
    if (_isDisposed) {
      return;
    }

    if (_isPaused) {
      _enqueue(event);
      if (_mode == GraphRepositoryStreamMode.deferred &&
          deferredFlushInterval != null) {
        _scheduleDeferredFlush();
      }
      return;
    }

    _emit(event);
  }

  void _emit(T value) {
    if (_isDisposed) return;
    _lastEmittedAt = DateTime.now();
    _controller.add(value);
  }

  void _enqueue(T value) {
    if (_queue.length == maxQueueLength) {
      final removed = _queue.removeFirst();
      LoggingService.instance.warning(
        'GraphRepositoryStreamController overflow (${_metadata.debugLabel}); '
        'dropping oldest value of type ${removed.runtimeType}.',
      );
    }
    _queue.addLast(value);
  }

  void _scheduleDeferredFlush() {
    if (deferredFlushInterval == null) {
      return;
    }
    _cancelDeferredTimer();
    _deferredTimer = Timer(deferredFlushInterval!, () {
      if (_isDisposed) {
        return;
      }
      _isPaused = false;
      unawaited(flush());
      if (_mode == GraphRepositoryStreamMode.deferred) {
        _isPaused = true;
      }
    });
  }

  void _cancelDeferredTimer() {
    _deferredTimer?.cancel();
    _deferredTimer = null;
  }
}

const Object _scopeKey = Object();

/// Zone-scoped helper used by harnesses to capture created controllers.
class GraphRepositoryStreamControllerScope {
  GraphRepositoryStreamControllerScope._(this.factory);

  final GraphRepositoryStreamControllerFactory factory;
  final List<GraphRepositoryStreamController<dynamic>> _controllers = [];

  static GraphRepositoryStreamControllerScope? get current =>
      Zone.current[_scopeKey] as GraphRepositoryStreamControllerScope?;

  static R runWithFactory<R>({
    required GraphRepositoryStreamControllerFactory factory,
    required R Function() body,
  }) {
    final scope = GraphRepositoryStreamControllerScope._(factory);
    return runZoned(body, zoneValues: {_scopeKey: scope});
  }

  void register<T>(GraphRepositoryStreamController<T> controller) {
    _controllers.add(controller);
  }

  List<GraphRepositoryStreamController<dynamic>> get controllers =>
      List.unmodifiable(_controllers);

}

/// Convenience helper for tests wanting manual flush semantics by default.
GraphRepositoryStreamController<T> manualFlushGraphStreamControllerFactory<T>(
  Stream<T> source,
  GraphRepositoryStreamMetadata metadata,
) {
  return GraphRepositoryStreamController<T>(
    source,
    metadata,
    mode: GraphRepositoryStreamMode.manualFlush,
  );
}

@visibleForTesting
GraphRepositoryStreamController<T> immediateGraphStreamControllerFactory<T>(
  Stream<T> source,
  GraphRepositoryStreamMetadata metadata,
) {
  return GraphRepositoryStreamController<T>(
    source,
    metadata,
    mode: GraphRepositoryStreamMode.immediate,
  );
}
