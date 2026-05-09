import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/graph/graph_node_events.dart';
import 'package:seafoundry_app/models/graph/graph_node_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/repositories.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';

/// Bundle of streams that feed a [GraphNode]'s reactive state.
class GraphNodeStreamBundle<T extends GraphNodeRecord> {
  const GraphNodeStreamBundle({
    required this.recordStream,
    required this.childrenStream,
    required this.eventsStream,
    required this.shallowEventsStream,
    required this.creatorStream,
  });

  final Stream<T?> recordStream;
  final Stream<List<GraphNode>> childrenStream;
  final Stream<List<Event>> eventsStream;
  final Stream<List<Event>> shallowEventsStream;
  final Stream<User?> creatorStream;

  List<Stream<dynamic>> get subStreams => <Stream<dynamic>>[
    recordStream,
    childrenStream,
    eventsStream,
    creatorStream,
  ];
}

/// Index constants for stream data tuple positions in [GraphNode].
///
/// When combining streams via [CombineLatestStream], data arrives as a list.
/// These indices provide type-safe access to each element.
enum DataIndex { record, children, events, creator }

/// Mixin that enables a [GraphNode] to be moved within the hierarchy.
///
/// Applied to nodes that support relocation (e.g., [GroupNode], [OrganismNode]).
/// Movement operations update both the node's `urlPath`/`internalPath` and
/// trigger appropriate events in the event log.
mixin MovableNode<T extends GraphNodeRecord> implements GraphNode<T> {
  Future<void> moveTo(GraphNode newParent) async {
    await graphRepository.moveNode(this, newParent: newParent);
  }
}

@visibleForTesting
class TestGraphNode<T extends GraphNodeRecord> extends GraphNode<T> {
  TestGraphNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    super.parent,
    required Stream<T?> recordStream,
    required Stream<List<GraphNode>> childrenStream,
    required Stream<List<Event>> eventsStream,
    required Stream<User?> creatorStream,
    required GraphLoadedState<T> Function(List<dynamic> data)
    loadedStateFactory,
  }) : _recordStream = recordStream,
       _childrenStream = childrenStream,
       _eventsStream = eventsStream,
       _creatorStream = creatorStream,
       _loadedStateFactory = loadedStateFactory;

  final Stream<T?> _recordStream;
  final Stream<List<GraphNode>> _childrenStream;
  final Stream<List<Event>> _eventsStream;
  final Stream<User?> _creatorStream;
  final GraphLoadedState<T> Function(List<dynamic> data) _loadedStateFactory;

  @override
  GraphLoadedState<T> loadedStateFromData(List<dynamic> data) {
    return _loadedStateFactory(data);
  }

  @override
  GraphNodeStreamBundle<T> buildStreamBundle() {
    return GraphNodeStreamBundle<T>(
      recordStream: _recordStream,
      childrenStream: _childrenStream,
      eventsStream: _eventsStream,
      shallowEventsStream: _eventsStream,
      creatorStream: _creatorStream,
    );
  }

  @override
  Stream<List<GraphNode>> buildDefaultChildrenStream() => _childrenStream;
}

/// Reactive node in the hierarchical graph navigation system.
///
/// ## Overview
/// [GraphNode] is the core abstraction for navigating SeaFoundry's hierarchical
/// data model. Each node represents a [GraphNodeRecord] (Organization, Site,
/// Group, or OrganismRecord) and maintains reactive streams for:
/// - The record itself (auto-updates on Firestore changes)
/// - Child nodes (lazy-loaded on navigation)
/// - Events associated with the record
/// - Creator user information
///
/// ## Hierarchy
/// ```
/// Organization (root)
/// └── Site
///     └── Group (nursery structure, tank, etc.)
///         └── OrganismRecord (coral, fish, etc.)
/// ```
///
/// ## Usage
/// ```dart
/// // Get root node
/// final root = graphRepository.root;
///
/// // Wait for children to load
/// await root.awaitLoaded();
///
/// // Access loaded state
/// final loadedState = root.state as OrganizationLoadedState;
/// for (final site in loadedState.children) {
///   print(site.name);
/// }
/// ```
///
/// ## State Machine
/// - [GraphNodeInitial]: Node created but not loaded
/// - [GraphNodeLoading]: Streams connecting, data loading
/// - [GraphLoadedState]: All data available (record, children, events)
/// - [GraphNodeError]: Load failed (shows error message)
///
/// ## Concrete Implementations
/// - [OrganizationNode]: Root of the graph, organization-level data
/// - [SiteNode]: Physical location (nursery, reef site, lab)
/// - [GroupNode]: Logical container (tank, table, zone)
/// - [OrganismNode]: Individual or batch inventory records
///
/// See [GraphRepository] for node creation and caching.
abstract class GraphNode<T extends GraphNodeRecord>
    extends Cubit<GraphNodeState<T>> {
  GraphNode({
    required this.graphRepository,
    required this.recordRepository,
    required this.initialRecord,
    this.parent,
  }) : super(GraphNodeInitial(record: initialRecord)) {
    graphRepository.addNodeToCache(this);
    _streamBundle = buildStreamBundle();
  }

  /// Buffer for events that arrive before state is loaded.
  /// This prevents the race condition where event stream emits data
  /// between subscription setup and state transition to GraphLoadedState.
  List<Event>? _pendingEvents;

  @protected
  final GraphRepository graphRepository;

  @protected
  final RecordRepository recordRepository;

  // Clients should access record through state as it may be updated
  final T initialRecord;
  final GraphNode? parent;
  // List of ancestors, reversed to start with root
  late final List<GraphNode> lineage = _getLineage();

  Future<List<GraphNode>> getChildren() async {
    await awaitLoaded();
    return (state as GraphLoadedState).children;
  }

  ModelType get modelType => initialRecord.modelType;
  String get id => initialRecord.id;
  String get slug => initialRecord.slug;
  String get internalPath => state.record.internalPath;
  String get urlPath => state.record.urlPath;
  String get name => state.record.name;
  T get currentRecord => state.record;
  String get currentUrlPath => currentRecord.urlPath;
  bool get isLoaded => state is GraphLoadedState;

  Future<void> awaitLoaded() async {
    if (kDebugMode) {
      LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded START: $id (${modelType.name}), current state: ${state.runtimeType}');
    }

    // Fast path: if already loaded, return immediately
    if (state is GraphLoadedState) {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded: Already loaded, returning immediately');
      }
      return;
    }

    // Fast path: if in error state, throw immediately
    if (state is GraphNodeError<T>) {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded: Already in error state, throwing');
      }
      throw (state as GraphNodeError<T>).error;
    }

    // CRITICAL: If node is in initial state, trigger loading!
    // Nodes cached during synchronization may not have been told to load yet.
    if (state is GraphNodeInitial<T>) {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded: Node in initial state, triggering load');
      }
      add(GraphNodeLoadRequested());
    }

    if (kDebugMode) {
      LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded: Waiting for state transition...');
    }
    // Wait for state transition to loaded or error
    try {
      final finalState = await stream.firstWhere(
        (s) => s is GraphLoadedState || s is GraphNodeError,
      ).timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded: State transition completed: ${finalState.runtimeType}');
      }
      if (finalState is GraphNodeError<T>) {
        if (kDebugMode) {
          LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded: Final state is error');
        }
        throw finalState.error;
      }
    } on TimeoutException {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('GraphNode.awaitLoaded TIMEOUT: $id (${modelType.name}), urlPath: ${state.record.urlPath}, stuck in state: ${state.runtimeType}');
      }
      throw TimeoutException('Node $id (${modelType.name}) failed to load within 15 seconds');
    }
  }

  GraphNode<Site>? get siteNode =>
      lineage.length > 1 ? lineage[1] as GraphNode<Site> : null;

  GraphNode<Organization> get organizationNode =>
      lineage.first as GraphNode<Organization>;

  bool isAncestorOf(GraphNode other) {
    return other.lineage.contains(this);
  }

  bool isDescendantOf(GraphNode other) {
    return lineage.contains(other);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GraphNode<T> &&
        other.initialRecord == initialRecord &&
        other.parent == parent;
  }

  @override
  int get hashCode => initialRecord.hashCode ^ parent.hashCode;

  // Sub-streams
  late GraphNodeStreamBundle<T> _streamBundle;

  @protected
  GraphNodeStreamBundle<T> buildStreamBundle() {
    return GraphNodeStreamBundle<T>(
      recordStream: buildRecordStream(),
      childrenStream: buildDefaultChildrenStream(),
      eventsStream: buildEventsStream(),
      shallowEventsStream: buildShallowEventsStream(),
      creatorStream: buildCreatorStream(),
    );
  }

  List<Stream<dynamic>> get subStreams => _streamBundle.subStreams;

  @protected
  Stream<T?> buildRecordStream() => recordRepository
      .streamRecord<T>(
        initialRecord.modelType,
        initialRecord.id,
        organizationId: _getOrganizationId(),
      )
      // Ensure immediate emission for CombineLatestStream - use initialRecord
      // as seed value since we already have it, prevents timeout when Firestore is slow.
      .startWith(initialRecord)
      .asBroadcastStream();

  /// Get organizationId from the initial record (all GraphNodeRecords are InventoryRecords)
  String? _getOrganizationId() => initialRecord.organizationId;

  @protected
  Stream<List<GraphNode>> buildDefaultChildrenStream();

  @protected
  Stream<List<Event>> buildEventsStream() {
    return graphRepository
        .streamEventsForUrlPath(currentUrlPath)
        // Ensure immediate emission for CombineLatestStream - prevents timeout
        // when Firestore is slow or data hasn't loaded yet.
        .startWith(const <Event>[])
        .toBroadcastIfNeeded(StreamType.events);
  }

  @protected
  Stream<List<Event>> buildShallowEventsStream() => graphRepository
      .streamEventsForUrlPath(currentUrlPath, shallow: true)
      // Ensure immediate emission for CombineLatestStream - prevents timeout
      // when Firestore is slow or data hasn't loaded yet.
      .startWith(const <Event>[])
      .toBroadcastIfNeeded(StreamType.events);

  @protected
  Stream<User?> buildCreatorStream() => recordRepository
      .streamRecord<User>(ModelType.user, initialRecord.createdById)
      // Ensure immediate emission for CombineLatestStream - emit null initially,
      // actual user will be emitted when Firestore responds.
      .startWith(null)
      .asBroadcastStream();

  List<GraphNode> _getLineage() {
    final ancestors = <GraphNode>[];
    final seenKeys = <String>{};
    GraphNode? current = this;
    while (current != null) {
      final key = '${current.modelType.name}:${current.id}';
      if (seenKeys.contains(key)) {
        LoggingService.instance.warning(
          'GraphNode lineage contains duplicate key $key. '
          'Breaking to avoid cycles.',
        );
        break;
      }
      ancestors.add(current);
      seenKeys.add(key);
      current = current.parent;
    }
    return ancestors.reversed.toList();
  }

  // Subscriptions
  @protected
  StreamSubscription<T?>? recordSubscription;
  @protected
  StreamSubscription<List<GraphNode>>? childrenSubscription;
  @protected
  StreamSubscription<List<Event>>? eventsSubscription;
  @protected
  StreamSubscription<User?>? creatorSubscription;

  void add(GraphNodeEvent event) {
    // Guard against adding events after close - prevents async operations
    // from attempting to modify closed blocs during test teardown.
    if (isClosed) {
      return;
    }
    // Filter extraneous load requests for cleaner logging
    if (event is GraphNodeLoadRequested && state is! GraphNodeInitial) {
      return;
    }
    if (event is GraphNodeLoadRequested) {
      unawaited(_load());
      return;
    }
    if (event is GraphNodeReloadRequested) {
      unawaited(_reload());
      return;
    }
    if (event is GraphNodeRecordUpdated) {
      _onRecordUpdated(event);
      return;
    }
    if (event is GraphNodeChildrenUpdated) {
      _onChildrenUpdated(event);
      return;
    }
    if (event is GraphNodeEventsUpdated) {
      _onEventsUpdated(event);
      return;
    }
    if (event is GraphNodeCreatorUpdated) {
      _onCreatorUpdated(event);
      return;
    }
  }

  Future<void> _load({bool reload = false}) async {
    if (state is! GraphNodeInitial && !reload) {
      return;
    }
    // Guard against loading after close - this can happen when async load
    // is triggered just before bloc is closed during test teardown.
    if (isClosed) {
      return;
    }
    if (reload) {
      _cancelSubscriptions();
      _streamBundle = buildStreamBundle();
    }
    emit(GraphNodeLoading(record: state.record));

    // CRITICAL: Subscribe to sub-streams FIRST to keep them connected.
    // This prevents shareReplay's refCount from disconnecting when
    // CombineLatestStream.first disposes its temporary subscription.
    // The subscriptions will receive data even while we wait for initial load.
    _subscribeToSubStreams();

    late final List<dynamic> data;
    try {
      data = await CombineLatestStream.list(subStreams)
          .first
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (error, stackTrace) {
      LoggingService.instance.error(
        'GraphNode load timed out for ${initialRecord.modelType} ${initialRecord.name}',
        error,
        stackTrace,
      );
      _cancelSubscriptions();
      // Guard against emitting after close
      if (!isClosed) {
        emit(GraphNodeError(record: state.record, error: error));
      }
      return;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'GraphNode load failed for ${initialRecord.modelType} ${initialRecord.name}',
        error,
        stackTrace,
      );
      _cancelSubscriptions();
      // Guard against emitting after close
      if (!isClosed) {
        emit(GraphNodeError(record: state.record, error: error));
      }
      return;
    }
    _onLoadedData(data);
  }

  Future<void> _reload() async {
    // Force reload even if already loaded
    await _load(reload: true);
  }

  void _onLoadedData(List<dynamic> data) {
    // Guard against emitting after close - this can happen when async load
    // completes after the bloc has been closed during test teardown.
    if (isClosed) {
      LoggingService.instance.graphNodeDebug(
        'GraphNode._onLoadedData: Skipping emit for closed bloc ${initialRecord.modelType} ${initialRecord.name}',
      );
      return;
    }

    final record = data[DataIndex.record.index] as T?;
    if (record == null) {
      final message =
          'GraphNode load produced null record for ${initialRecord.modelType} '
          '${initialRecord.name} (id: ${initialRecord.id}, path: ${initialRecord.urlPath})';
      LoggingService.instance.error(message, data);
      emit(
        GraphNodeError<T>(
          record: state.record,
          error: StateError('Null record received during graph node load'),
        ),
      );
      return;
    }

    LoggingService.instance.graphNodeDebug(
      'Loaded data for ${initialRecord.modelType} ${initialRecord.name}',
      data,
    );
    // Emit state - subscriptions were already set up in _load() before
    // CombineLatestStream.first to keep the streams connected.
    var loadedState = loadedStateFromData(data);

    // Apply any pending events that arrived before state was loaded.
    // This handles the race condition where event streams emit data
    // between subscription setup and this state transition.
    if (_pendingEvents != null && _pendingEvents!.isNotEmpty) {
      loadedState =
          loadedState.copyWith(events: _pendingEvents!) as GraphLoadedState<T>;
      _pendingEvents = null;
    }

    emit(loadedState);
  }

  GraphLoadedState<T> loadedStateFromData(List<dynamic> data);

  void _subscribeToSubStreams() {
    _cancelSubscriptions(clearPendingEvents: false);

    _subscribeToRecord();
    _subscribeToChildren();
    _subscribeToEvents();
    _subscribeToCreator();
  }

  void _cancelSubscriptions({bool clearPendingEvents = true}) {
    recordSubscription?.cancel();
    recordSubscription = null;
    childrenSubscription?.cancel();
    childrenSubscription = null;
    eventsSubscription?.cancel();
    eventsSubscription = null;
    creatorSubscription?.cancel();
    creatorSubscription = null;
    if (clearPendingEvents) {
      _pendingEvents = null;
    }
  }

  /// When a record's urlPath changes (e.g., after a move), re-key the cache and
  /// rebuild stream subscriptions so this node listens on the new path.
  void _handleUrlPathChange(String oldPath, String newPath) {
    graphRepository.rekeyNodeInCache(
      oldPath: oldPath,
      newPath: newPath,
      node: this,
    );
    _cancelSubscriptions();
    _streamBundle = buildStreamBundle();
    _subscribeToSubStreams();
  }

  int _recordRetryCount = 0;
  static const int _maxRecordRetries = 3;

  void _subscribeToRecord() {
    recordSubscription = _streamBundle.recordStream.listen(
      (T? record) {
        // Reset retry count on successful data
        _recordRetryCount = 0;
        if (record == null) {
          final message =
              'Null record in stream for ${initialRecord.modelType} '
              '${initialRecord.name} (id: ${initialRecord.id}, path: ${initialRecord.urlPath})';
          LoggingService.instance.error(message);
          return;
        }
        if (record == state.record) {
          return;
        }
        LoggingService.instance.graphNodeDebug(
          'Record updated for ${record.modelType} ${record.name}',
          record,
        );
        add(GraphNodeRecordUpdated<T>(record));
      },
      onError: (error, stackTrace) {
        final errorMessage = error.toString();
        final isRetryableError =
            errorMessage.contains('INTERNAL ASSERTION FAILED') ||
            errorMessage.contains('Unexpected state');

        LoggingService.instance.error(
          'Record stream error for ${initialRecord.modelType} ${initialRecord.name}',
          error,
          stackTrace,
        );

        // Retry on Firestore SDK assertion errors (known issue in v12.3.0)
        if (isRetryableError &&
            _recordRetryCount < _maxRecordRetries &&
            !isClosed) {
          _recordRetryCount++;
          LoggingService.instance.warning(
            'Retrying record stream subscription (attempt $_recordRetryCount/$_maxRecordRetries) '
            'for ${initialRecord.modelType} ${initialRecord.name}',
          );
          Future.delayed(
            Duration(milliseconds: 200 * (1 << _recordRetryCount)),
            () {
              if (!isClosed) {
                recordSubscription?.cancel();
                _streamBundle = buildStreamBundle();
                _subscribeToRecord();
              }
            },
          );
        }
      },
    );
  }

  void _onRecordUpdated(GraphNodeRecordUpdated event) {
    // Guard against emitting after close
    if (isClosed) {
      return;
    }
    LoggingService.instance.graphNodeDebug(
      'Record updated for ${initialRecord.modelType} ${initialRecord.name}',
      event.record,
    );
    final loadedState = state;
    if (loadedState is! GraphLoadedState<T>) {
      LoggingService.instance.warning(
        'Received record update while state is not loaded for ${initialRecord.modelType} ${initialRecord.name}',
      );
      return;
    }
    final oldPath = loadedState.record.urlPath;
    final newRecord = event.record as T;
    final pathChanged = oldPath != newRecord.urlPath;
    emit(loadedState.copyWith(record: newRecord) as GraphLoadedState<T>);
    if (pathChanged) {
      _handleUrlPathChange(oldPath, newRecord.urlPath);
    }
  }

  void _subscribeToChildren() {
    childrenSubscription = _streamBundle.childrenStream.listen(
      (children) {
        LoggingService.instance.graphNodeDebug(
          'Children stream emission for ${initialRecord.modelType} ${initialRecord.name}: '
          'count=${children.length}, state=${state.runtimeType}',
        );
        // Only process if state is loaded
        if (state is! GraphLoadedState) {
          LoggingService.instance.graphNodeDebug(
            'Skipping children update - state not loaded for ${initialRecord.name}',
          );
          return;
        }

        final currentChildren = (state as GraphLoadedState).children;
        if (ListEquality().equals(children, currentChildren)) {
          LoggingService.instance.graphNodeDebug(
            'Skipping children update - lists equal for ${initialRecord.name}: '
            'new=${children.length}, current=${currentChildren.length}',
          );
          return;
        }
        LoggingService.instance.graphNodeDebug(
          'Children updated for ${initialRecord.modelType} ${initialRecord.name} with count ${children.length}',
        );
        add(GraphNodeChildrenUpdated(children));
      },
      onError: (error, stackTrace) {
        LoggingService.instance.error(
          'Children stream error for ${initialRecord.modelType} ${initialRecord.name}',
          error,
          stackTrace,
        );
      },
    );
  }

  void _onChildrenUpdated(GraphNodeChildrenUpdated event) {
    // Guard against emitting after close
    if (isClosed) {
      return;
    }
    final currentState = state;
    if (currentState is! GraphLoadedState) {
      LoggingService.instance.warning(
        'Received children update while state is not loaded for ${initialRecord.modelType} ${initialRecord.name}',
      );
      return;
    }
    final loadedState = currentState as GraphLoadedState;
    LoggingService.instance.graphNodeDebug(
      'GraphNode children update for ${initialRecord.modelType} ${initialRecord.name} count ${event.children.length}',
    );
    emit(loadedState.copyWith(children: event.children) as GraphLoadedState<T>);
  }

  int _eventsRetryCount = 0;
  static const int _maxEventsRetries = 3;

  void _subscribeToEvents() {
    eventsSubscription = _streamBundle.eventsStream.listen(
      (events) {
        // Reset retry count on successful data
        _eventsRetryCount = 0;
        LoggingService.instance.graphNodeDebug(
          '🔵 GraphNodeBloc events stream received ${events.length} events for ${initialRecord.modelType} ${initialRecord.name}',
        );

        // Buffer events if state is not yet loaded - they'll be replayed once loaded
        if (state is! GraphLoadedState) {
          LoggingService.instance.graphNodeDebug(
            '🔵 GraphNodeBloc: State not loaded yet, buffering ${events.length} events',
          );
          // Accumulate events instead of overwriting to prevent loss during rapid emissions
          _pendingEvents = [...?_pendingEvents, ...events];
          return;
        }

        final currentEvents = (state as GraphLoadedState).events;
        if (ListEquality().equals(events, currentEvents)) {
          LoggingService.instance.graphNodeDebug(
            '🔵 GraphNodeBloc: Events unchanged (${events.length}), skipping update',
          );
          return;
        }
        LoggingService.instance.graphNodeDebug(
          '🔵 GraphNodeBloc: Dispatching GraphNodeEventsUpdated with ${events.length} events',
        );
        add(GraphNodeEventsUpdated(events));
      },
      onError: (error, stackTrace) {
        final errorMessage = error.toString();
        final isRetryableError =
            errorMessage.contains('INTERNAL ASSERTION FAILED') ||
            errorMessage.contains('Unexpected state');

        LoggingService.instance.error(
          'Events stream error for ${initialRecord.modelType} ${initialRecord.name}',
          error,
          stackTrace,
        );

        // Retry on Firestore SDK assertion errors (known issue in v12.3.0)
        // See: https://github.com/firebase/firebase-js-sdk/issues/9267
        if (isRetryableError &&
            _eventsRetryCount < _maxEventsRetries &&
            !isClosed) {
          _eventsRetryCount++;
          LoggingService.instance.warning(
            'Retrying events stream subscription (attempt $_eventsRetryCount/$_maxEventsRetries) '
            'for ${initialRecord.modelType} ${initialRecord.name}',
          );
          // Exponential backoff: 200ms, 400ms, 800ms
          Future.delayed(
            Duration(milliseconds: 200 * (1 << _eventsRetryCount)),
            () {
              if (!isClosed) {
                eventsSubscription?.cancel();
                _streamBundle = buildStreamBundle();
                _subscribeToEvents();
              }
            },
          );
        }
      },
    );
  }

  void _onEventsUpdated(GraphNodeEventsUpdated event) {
    // Guard against emitting after close
    if (isClosed) {
      return;
    }
    final currentState = state;
    if (currentState is! GraphLoadedState) {
      LoggingService.instance.warning(
        'Received events update while state is not loaded for ${initialRecord.modelType} ${initialRecord.name}',
      );
      return;
    }
    final loadedState = currentState as GraphLoadedState;
    LoggingService.instance.graphNodeDebug(
      '🔵 GraphNodeBloc._onEventsUpdated: Emitting state with ${event.events.length} events for ${initialRecord.modelType} ${initialRecord.name}',
    );
    emit(loadedState.copyWith(events: event.events) as GraphLoadedState<T>);
  }

  void _subscribeToCreator() {
    var isFirstEmission = true;
    creatorSubscription = _streamBundle.creatorStream.listen(
      (creator) {
        if (creator == null) {
          // Skip the first null emission from startWith(null) - this is expected
          // Only log if createdById is present but user couldn't be resolved
          if (!isFirstEmission && initialRecord.createdById.isNotEmpty) {
            LoggingService.instance.warning(
              'Could not resolve creator (${initialRecord.createdById}) '
              'for ${initialRecord.modelType} ${initialRecord.name}',
            );
          }
          isFirstEmission = false;
          return;
        }
        isFirstEmission = false;
        // Only process if state is loaded
        if (state is! GraphLoadedState) return;

        if (creator == (state as GraphLoadedState).creator) {
          return;
        }
        LoggingService.instance.graphNodeDebug(
          'Creator updated for ${initialRecord.modelType} ${initialRecord.name}',
          creator,
        );
        add(GraphNodeCreatorUpdated(creator));
      },
      onError: (error, stackTrace) {
        LoggingService.instance.error(
          'Creator stream error for ${initialRecord.modelType} ${initialRecord.name}',
          error,
          stackTrace,
        );
      },
    );
  }

  void _onCreatorUpdated(GraphNodeCreatorUpdated event) {
    // Guard against emitting after close
    if (isClosed) {
      return;
    }
    final currentState = state;
    if (currentState is! GraphLoadedState) {
      LoggingService.instance.warning(
        'Received creator update while state is not loaded for ${initialRecord.modelType} ${initialRecord.name}',
      );
      return;
    }
    final loadedState = currentState as GraphLoadedState;
    emit(loadedState.copyWith(creator: event.creator) as GraphLoadedState<T>);
  }

  @override
  Future<void> close() async {
    final currentState = state;

    // Close children regardless of current state type
    if (currentState is GraphLoadedState<T>) {
      // Close all children in parallel and await completion
      // This ensures proper cleanup order: children first, then parent
      await Future.wait(
        currentState.children
            .where((child) => !child.isClosed)
            .map((child) => child.close()),
        eagerError: false,
      );
    }

    _cancelSubscriptions();
    graphRepository.removeNodeFromCache(this);
    await super.close();
  }
}
