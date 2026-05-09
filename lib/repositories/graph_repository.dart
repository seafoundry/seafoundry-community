// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/inventory_record_repository.dart';
import 'package:seafoundry_app/repositories/repositories.dart';
import 'package:seafoundry_app/services/graph_cache_manager.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/site_capability_guard.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';

class GraphRepository {
  GraphRepository({
    required this.eventRepository,
    required this.siteRepository,
    required this.groupRepository,
    required this.organismRecordRepository,
    required this.genetRepository,
    required this.recordRepository,
    required FirebaseFirestore firestore,
    bool enableCleanupTimer = true,
    GraphRepositoryStreamControllerFactory? streamControllerFactory,
    GraphCacheManagerConfig cacheConfig =
        const GraphCacheManagerConfig.production(),
    GraphNode<Organization> Function(GraphRepository repository)?
    testRootBuilder,
    Future<void> Function(
      GraphNode node, {
      required GraphNode newParent,
      PartialMoveSelection? partialSelection,
      String? moveReason,
      EventBaseParams base,
    })?
    moveNodeOverride,
  }) : db = firestore,
       _testRootBuilder = testRootBuilder,
       _moveNodeOverride = moveNodeOverride {
    _cacheManager = GraphCacheManager(maxCacheSize: 5000, config: cacheConfig);
    if (enableCleanupTimer) {
      _cacheManager.startCleanupTimer();
    }
    _streamControllerFactory = streamControllerFactory;
  }

  final EventRepository eventRepository;
  final SiteRepository siteRepository;
  final GroupRepository groupRepository;
  final OrganismRecordRepository organismRecordRepository;
  final GenetRepository genetRepository;
  final RecordRepository recordRepository;
  final FirebaseFirestore db;
  final GraphNode<Organization> Function(GraphRepository repository)?
  _testRootBuilder;
  GraphNode<Organization>? _testRoot;
  final Future<void> Function(
    GraphNode node, {
    required GraphNode newParent,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base,
  })?
  _moveNodeOverride;

  late final GraphCacheManager _cacheManager;
  late final GraphRepositoryStreamControllerFactory? _streamControllerFactory;
  final List<GraphRepositoryStreamController<dynamic>>
  _managedStreamControllers = [];

  Organization get organization => eventRepository.organization;

  GraphNode<Organization> get root {
    final builder = _testRootBuilder;
    if (builder != null) {
      return _testRoot ??= builder(this);
    }

    final domain = eventRepository.organization.domain;
    final cached = _cacheManager.get(domain);
    if (cached != null) {
      return cached as GraphNode<Organization>;
    }

    final node = OrganizationNode(
      graphRepository: this,
      recordRepository: recordRepository,
      initialRecord: eventRepository.organization,
    )..add(GraphNodeLoadRequested());

    _cacheManager.add(domain, node);
    return node;
  }

  void addNodeToCache(GraphNode node) {
    _cacheManager.add(node.urlPath, node);
  }

  void removeNodeFromCache(GraphNode node) {
    _cacheManager.remove(node.urlPath);
  }

  /// Re-key an existing node in the cache when its urlPath changes (e.g., after a move).
  void rekeyNodeInCache({
    required String oldPath,
    required String newPath,
    required GraphNode node,
  }) {
    final normalizedOld = _normalizeUrlPath(oldPath);
    final normalizedNew = _normalizeUrlPath(newPath);
    if (normalizedOld == normalizedNew) {
      return;
    }
    _cacheManager.remove(normalizedOld);
    _cacheManager.add(normalizedNew, node);
  }

  /// Active stream controllers created by this repository (primarily for tests).
  List<GraphRepositoryStreamController<dynamic>> get streamControllers =>
      List.unmodifiable(_managedStreamControllers);

  GraphNode<GraphNodeRecord>? getNodeFromCache(String urlPath) {
    final normalizedPath = _normalizeUrlPath(urlPath);
    if (!normalizedPath.startsWith(organization.domain)) {
      LoggingService.instance.error(
        'Attempt to get node outside of organization: $urlPath (normalized: $normalizedPath, org: ${organization.domain})',
      );
      return null;
    } else if (normalizedPath == organization.domain) {
      return root;
    }
    final cached = _cacheManager.get(normalizedPath);
    LoggingService.instance.info(
      'Cache lookup for $normalizedPath: ${cached != null ? "found" : "not found"}',
    );
    return cached;
  }

  /// Loads a graph node by URL path by walking parents + cache.
  ///
  /// This method is the backbone of graph navigation:
  /// - returns the cached root immediately when possible
  /// - deduplicates concurrent loads via [GraphCacheManager.registerPendingLoad]
  /// - ensures parents are loaded before children to keep lineage intact
  /// - polls briefly for late-arriving children (as nodes hydrate asynchronously)
  Future<GraphNode<GraphNodeRecord>?> getNodeForUrlPath(String urlPath) async {
    return PerformanceAnalyzer.measure(
      'GraphRepository.getNodeForUrlPath',
      () => _getNodeForUrlPathInternal(urlPath),
      metadata: {'urlPath': urlPath, 'operation': 'node_loading'},
    );
  }

  Future<GraphNode<GraphNodeRecord>?> _getNodeForUrlPathInternal(
    String urlPath,
  ) async {
    final normalizedPath = _normalizeUrlPath(urlPath);
    if (kDebugMode) {
      LoggingService.instance
          .graphNodeDebug('GraphRepository._getNodeForUrlPathInternal', {
            'originalUrlPath': urlPath,
            'normalizedPath': normalizedPath,
            'organizationDomain': organization.domain,
            'equalsDomain': normalizedPath == organization.domain,
          });
    }

    if (normalizedPath == organization.domain) {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug(
          'GraphRepository: Returning ROOT (normalized == domain)',
        );
      }
      return root;
    }

    if (kDebugMode) {
      LoggingService.instance.graphNodeDebug(
        'GraphRepository: Calling registerPendingLoad for: $normalizedPath',
      );
    }
    // Use cache manager to handle concurrent loads - prevents multiple simultaneous
    // loads of the same path from different parts of the app
    return _cacheManager.registerPendingLoad(normalizedPath, () async {
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug(
          'GraphRepository: Inside loader for: $normalizedPath',
        );
      }
      // Check if already cached from concurrent load
      final cachedNode = getNodeFromCache(normalizedPath);
      if (cachedNode != null) {
        // Verify parent chain is intact before returning cached node.
        // A broken parent chain (closed parents) causes empty breadcrumbs.
        if (_hasValidParentChain(cachedNode)) {
          if (kDebugMode) {
            LoggingService.instance.graphNodeDebug(
              'GraphRepository: Found in cache with valid parent chain: $normalizedPath',
            );
          }
          return cachedNode;
        } else {
          // Parent chain is broken - remove from cache and reload hierarchically
          if (kDebugMode) {
            LoggingService.instance.graphNodeDebug(
              'GraphRepository: Cached node has broken parent chain, reloading: $normalizedPath',
            );
          }
          _cacheManager.remove(normalizedPath, closeNode: true);
        }
      }

      // Hierarchical loading: load parent first, then search its children
      // This ensures parent is fully loaded before accessing its children
      final parentUrlPath = _parentPath(normalizedPath);
      if (parentUrlPath == null) {
        if (kDebugMode) {
          LoggingService.instance.graphNodeDebug(
            'GraphRepository: Failed to determine parent path for: $normalizedPath',
          );
        }
        LoggingService.instance.error(
          'Failed to determine parent path for: $normalizedPath',
        );
        return null;
      }

      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug(
          'GraphRepository: Loading parent node: $parentUrlPath',
        );
      }
      final parentNode = await getNodeForUrlPath(parentUrlPath);
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug(
          'GraphRepository: Parent node loaded: ${parentNode?.id} (${parentNode?.modelType.name})',
        );
      }
      if (parentNode == null) {
        final error = NodeLoadNotFoundError(
          'Failed to find parent node for: $normalizedPath',
          urlPath: normalizedPath,
        );
        if (kDebugMode) {
          LoggingService.instance.graphNodeDebug(
            'GraphRepository: ${error.message}',
          );
        }
        LoggingService.instance.error(error.message);
        throw error;
      }

      // Wait for parent to finish loading its children
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug(
          'GraphRepository: Waiting for parent.awaitLoaded(): ${parentNode.id}',
        );
      }
      try {
        await parentNode.awaitLoaded();
        if (kDebugMode) {
          LoggingService.instance.graphNodeDebug(
            'GraphRepository: Parent awaitLoaded() completed: ${parentNode.id}',
          );
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          LoggingService.instance.graphNodeDebug(
            'GraphRepository: Parent awaitLoaded() FAILED: $e',
          );
        }
        LoggingService.instance.error(
          'Parent node failed to load for $normalizedPath (parent: $parentUrlPath)',
          e,
          stackTrace,
        );
        // Rethrow with a descriptive error that preserves the root cause
        throw ParentNodeLoadError(
          'Parent node failed to load',
          urlPath: normalizedPath,
          parentPath: parentUrlPath,
          cause: e,
        );
      }

      // Check cache again - node may have been loaded by parent's load process
      GraphNode<GraphNodeRecord>? result = _cacheManager.get(normalizedPath);
      final parentState = parentNode.state;

      if (result == null) {
        // Search parent's children for the requested node
        if (parentState is GraphLoadedState) {
          for (final child in parentState.children) {
            if (_normalizeUrlPath(child.urlPath) == normalizedPath) {
              result = child;
              _cacheManager.add(normalizedPath, child);
              break;
            }
          }
        }
      } else if (_hasValidParentChain(result)) {
        // Only return cached result if parent chain is intact
        return result;
      } else {
        // Parent chain broken - search parent's children for a valid node
        if (kDebugMode) {
          LoggingService.instance.graphNodeDebug(
            'GraphRepository: Cached node has broken parent chain (post-parent-load), '
            'searching parent children: $normalizedPath',
          );
        }
        _cacheManager.remove(normalizedPath, closeNode: true);
        result = null;
        if (parentState is GraphLoadedState) {
          for (final child in parentState.children) {
            if (_normalizeUrlPath(child.urlPath) == normalizedPath) {
              result = child;
              _cacheManager.add(normalizedPath, child);
              break;
            }
          }
        }
      }

      // Wait for async children loading (nodes load children asynchronously)
      // This handles race conditions where the parent is loaded but children aren't ready yet
      // Use a completer-based approach with timeout instead of polling
      if (result == null && parentState is GraphLoadedState) {
        final completer = Completer<GraphNode<GraphNodeRecord>?>();
        StreamSubscription<GraphNodeState>? subscription;

        subscription = parentNode.stream.listen((state) {
          if (completer.isCompleted) {
            subscription?.cancel();
            return;
          }

          if (state is GraphLoadedState) {
            // Check if our target child has appeared
            for (final child in state.children) {
              if (_normalizeUrlPath(child.urlPath) == normalizedPath) {
                _cacheManager.add(normalizedPath, child);
                completer.complete(child);
                subscription?.cancel();
                return;
              }
            }
          }
        });

        // Set a timeout and clean up
        Future.delayed(const Duration(seconds: 2)).then((_) {
          if (!completer.isCompleted) {
            completer.complete(null);
            subscription?.cancel();
          }
        });

        result = await completer.future;
      }

      if (result == null) {
        LoggingService.instance.error(
          'Failed to resolve node for $normalizedPath after loading parent. It may not exist or failed to load.',
        );
      }
      return result;
    });
  }

  Stream<List<Site>> streamSites() {
    return _wrapStream<List<Site>>(
      siteRepository.streamAll,
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.site.collectionPath,
        entity: GraphRepositoryStreamEntity.site,
        debugLabel: 'siteRepository.streamAll',
      ),
    );
  }

  Stream<List<Group>> streamGroupsForSite(Site site, {bool shallow = false}) {
    return _wrapStream<List<Group>>(
      groupRepository.groupsForSite(site, shallow: shallow),
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.group.collectionPath,
        entity: GraphRepositoryStreamEntity.group,
        debugLabel:
            'groupRepository.groupsForSite(${site.id}, shallow: $shallow)',
      ),
    );
  }

  Stream<List<Group>> streamGroupsForUrlPath(String urlPath) {
    // Use shallow: true to only get direct child groups, not nested grandchildren
    final source = groupRepository
        .streamRecordsForUrlPath(urlPath, shallow: true)
        .map(
          (groups) => groups
              .where((group) => group.urlPath != urlPath)
              .toList(growable: false),
        );

    return _wrapStream<List<Group>>(
      source,
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.group.collectionPath,
        entity: GraphRepositoryStreamEntity.group,
        debugLabel: 'groupRepository.streamRecordsForUrlPath($urlPath)',
      ),
    );
  }

  /// Stream organisms for a given URL path (universal five-axis model)
  ///
  /// Filters out the parent record itself to prevent self-nesting in tree views.
  Stream<List<OrganismRecord>> streamOrganismsForUrlPath(String urlPath) {
    // Filter out the parent record to prevent self-nesting (matches GroupNode pattern)
    final source = organismRecordRepository
        .streamRecordsForUrlPath(urlPath)
        .map(
          (organisms) => organisms
              .where((organism) => organism.urlPath != urlPath)
              .toList(growable: false),
        );

    return _wrapStream<List<OrganismRecord>>(
      source,
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.organismRecord.collectionPath,
        entity: GraphRepositoryStreamEntity.coral,
        debugLabel:
            'organismRecordRepository.streamRecordsForUrlPath($urlPath)',
      ),
    );
  }

  /// Stream zones for a given site.
  ///
  /// Zones are the first level of subdivision in the site hierarchy:
  /// Site -> Zone -> Subplot -> Tag
  Stream<List<Zone>> streamZonesForSite(Site site) {
    // Stream zones that belong to this site by filtering on siteId
    final source = recordRepository
        .streamRecordsForModelType<Zone>(ModelType.zone)
        .map(
          (zones) => zones
              .where((zone) => zone.siteId == site.id)
              .toList(growable: false),
        );

    return _wrapStream<List<Zone>>(
      source,
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.zone.collectionPath,
        entity: GraphRepositoryStreamEntity.zone,
        debugLabel: 'recordRepository.streamZonesForSite(${site.id})',
      ),
    );
  }

  /// Stream subplots for a given zone.
  ///
  /// Subplots are the second level of subdivision in the site hierarchy:
  /// Site -> Zone -> Subplot -> Tag
  Stream<List<Subplot>> streamSubplotsForZone(Zone zone) {
    // Stream subplots that belong to this zone by filtering on zoneId
    final source = recordRepository
        .streamRecordsForModelType<Subplot>(ModelType.subplot)
        .map(
          (subplots) => subplots
              .where((subplot) => subplot.zoneId == zone.id)
              .toList(growable: false),
        );

    return _wrapStream<List<Subplot>>(
      source,
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.subplot.collectionPath,
        entity: GraphRepositoryStreamEntity.subplot,
        debugLabel: 'recordRepository.streamSubplotsForZone(${zone.id})',
      ),
    );
  }

  /// Stream organisms for a given subplot.
  ///
  /// Organisms at the subplot level are tagged individuals at their
  /// outplanting location within the site hierarchy.
  Stream<List<OrganismRecord>> streamOrganismsForSubplot(Subplot subplot) {
    // Stream organisms that belong to this subplot by filtering on subplotId field.
    // Organisms are assigned to subplots via the subplotId field, not urlPath.
    final source = organismRecordRepository.streamAll.map(
      (organisms) => organisms
          .where((organism) => organism.subplotId == subplot.id)
          .toList(growable: false),
    );

    return _wrapStream<List<OrganismRecord>>(
      source,
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.organismRecord.collectionPath,
        entity: GraphRepositoryStreamEntity.coral,
        debugLabel:
            'organismRecordRepository.streamOrganismsForSubplot(${subplot.id})',
      ),
    );
  }

  Stream<List<Event>> streamEventsForUrlPath(
    String urlPath, {
    bool shallow = false,
    int limit = 500,
  }) {
    return _wrapStream<List<Event>>(
      eventRepository.streamEventsForUrlPath(
        urlPath,
        shallow: shallow,
        // Limit to reasonable number for activity feed display
        // Organization-level views need higher limits to show descendant events
        limit: limit,
      ),
      GraphRepositoryStreamMetadata(
        collectionName: ModelType.event.collectionPath,
        entity: GraphRepositoryStreamEntity.event,
        debugLabel:
            'eventRepository.streamEventsForUrlPath($urlPath, shallow: $shallow)',
      ),
    );
  }

  /// Moves a node (and optionally its children) to a new parent location.
  ///
  /// **Usage**: Called when user moves a structure/coral to a different group or site.
  /// **Behavior**:
  /// 1. Uses Firestore transaction to ensure atomicity
  /// 2. Recursively moves node and selected children (if partial move)
  /// 3. Reloads affected nodes to update UI immediately
  ///
  /// **Partial moves**: When moving only some corals from a cluster, this creates
  /// new coral records at the destination while updating the source quantity.
  Future<void> moveNode(
    GraphNode node, {
    required GraphNode newParent,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    final override = _moveNodeOverride;
    if (override != null) {
      await override(
        node,
        newParent: newParent,
        partialSelection: partialSelection,
        moveReason: moveReason,
        base: base,
      );
      return;
    }

    if (node.parent == null) {
      throw UnsupportedError(
        'Cannot move ${node.modelType} because it has no parent node.',
      );
    }

    // Cache the original hierarchy before we mutate anything; once the move
    // completes `node.parent` points at the destination and we lose the handle
    // required to refresh the previous container.
    final oldParent = node.parent;
    final oldParentParent = oldParent?.parent;
    final newParentParent = newParent.parent;

    LoggingService.instance.info(
      'moveNode called: ${node.modelType} "${node.name}" -> "${newParent.name}"',
    );

    final guard = const SiteCapabilityGuard();
    final sourceSite = guard.siteForNode(node);
    if (sourceSite != null) {
      guard.ensureSiteAllows(
        site: sourceSite,
        action: SiteCapabilityAction.move,
      );
    }

    final destinationSite = guard.siteForNode(newParent);
    if (destinationSite != null) {
      guard.ensureSiteAllows(
        site: destinationSite,
        action: SiteCapabilityAction.move,
      );
    }

    // Use Firestore transaction to ensure atomicity - either all moves succeed or none
    // Retry logic handles intermittent Firestore SDK assertion errors (known issue in v12.3.0)
    // See: https://github.com/firebase/firebase-js-sdk/issues/9267
    await _runTransactionWithRetry(
      () => db.runTransaction((transaction) async {
        await moveRecordRecursive(
          node,
          newParent.state.record,
          transaction,
          partialSelection: partialSelection,
          moveReason: moveReason,
          base: base,
        );
      }),
      operationName: 'moveNode',
    );

    // Force reloads so UI immediately reflects new hierarchy/state changes
    // This prevents stale data from being displayed after move operations
    _safeReload(node);
    _safeReload(newParent);
    _safeReload(oldParent);
    _safeReload(oldParentParent);
    _safeReload(newParent.parent);
    _safeReload(newParentParent);
  }

  /// Safely reloads a node if it's still active.
  ///
  /// **Usage**: Called after operations that modify node data to ensure UI reflects changes.
  /// **Safety**: Checks if node is closed before adding events to prevent bloc closure errors.
  void _safeReload(GraphNode? node) {
    if (node == null || node.isClosed) {
      return;
    }
    node.add(const GraphNodeReloadRequested());
  }

  /// Runs a Firestore operation with retry logic and exponential backoff.
  ///
  /// This handles intermittent Firestore SDK assertion errors that occur when
  /// transactions interact with active snapshot listeners. These errors are
  /// a known issue in Firebase JS SDK v12.3.0.
  ///
  /// See: https://github.com/firebase/firebase-js-sdk/issues/9267
  Future<T> _runTransactionWithRetry<T>(
    Future<T> Function() operation, {
    required String operationName,
    int maxAttempts = 3,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        final errorMessage = e.toString();
        final isRetryableError =
            errorMessage.contains('INTERNAL ASSERTION FAILED') ||
            errorMessage.contains('Unexpected state');

        if (isRetryableError && attempts < maxAttempts - 1) {
          attempts++;
          LoggingService.instance.warning(
            '$operationName: Firestore SDK assertion error (attempt $attempts/$maxAttempts), retrying...',
            {'error': errorMessage},
          );
          // Exponential backoff: 100ms, 200ms, 400ms...
          await Future.delayed(Duration(milliseconds: 100 * (1 << attempts)));
          continue;
        }
        LoggingService.instance.error(
          '$operationName failed after $attempts attempts',
          e,
        );
        rethrow;
      }
    }
  }

  Future<void> moveRecordRecursive(
    GraphNode node,
    GraphNodeRecord newParent,
    Transaction transaction, {
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    LoggingService.instance.info(
      'GraphRepository.moveRecordRecursive called for ${node.modelType}:',
    );
    if (partialSelection != null) {
      LoggingService.instance.info(
        '  - partialSelection.moveAll: ${partialSelection.moveAll}',
      );
      LoggingService.instance.info(
        '  - partialSelection.partialQuantities: ${partialSelection.partialQuantities}',
      );
    }

    final InventoryRecordRepository eventRecordRepository;
    if (node is GroupNode) {
      eventRecordRepository = groupRepository;
    } else if (node is SiteNode) {
      eventRecordRepository = siteRepository;
    } else if (node is OrganismNode) {
      eventRecordRepository = organismRecordRepository;
    } else if (node is OrganizationNode) {
      throw UnsupportedError('Organization nodes cannot be moved');
    } else {
      throw UnsupportedError(
        'Move is not supported for node type ${node.runtimeType}',
      );
    }
    if (!node.isClosed) {
      node.add(GraphNodeLoadRequested());
    }
    await node.awaitLoaded();
    final loadedState = node.state as GraphLoadedState;

    final childQuantities = <String, int>{};
    for (final child in loadedState.children) {
      final childState = child.state;
      if (childState is GraphLoadedState<OrganismRecord>) {
        childQuantities[child.id] = childState.record.measurement.value.toInt();
      }
    }

    final filteredSelection =
        partialSelection?.clampQuantities(childQuantities) ?? partialSelection;

    final movedRecord =
        await eventRecordRepository.moveRecord(
              record: loadedState.record,
              fromParent: node.parent!.state.record,
              toParent: newParent,
              transaction: transaction,
              partialSelection: filteredSelection,
              moveReason: moveReason,
              base: base,
            )
            as GraphNodeRecord;

    await eventRepository.moveEvents(
      events: loadedState.events,
      fromRecord: loadedState.record,
      toRecord: movedRecord,
      transaction: transaction,
    );

    if (filteredSelection == null || filteredSelection.moveAll) {
      for (final child in loadedState.children) {
        await moveRecordRecursive(
          child,
          movedRecord,
          transaction,
          partialSelection: null,
          moveReason: moveReason,
          base: base,
        );
      }
      return;
    }

    for (final child in loadedState.children) {
      final childSelection = filteredSelection.forChild(child.id);
      if (!childSelection.hasSelection) continue;

      await moveRecordRecursive(
        child,
        movedRecord,
        transaction,
        partialSelection: childSelection,
        moveReason: moveReason,
        base: base,
      );
    }
  }

  String _normalizeUrlPath(String urlPath) {
    if (urlPath.isEmpty) {
      return organization.domain;
    }

    Uri? uri;
    try {
      uri = Uri.parse(urlPath);
    } catch (e) {
      LoggingService.instance.graphNodeDebug('Failed to parse URL path', {
        'urlPath': urlPath,
        'error': e.toString(),
      });
      uri = null;
    }

    var path = urlPath;
    if (uri != null) {
      if (uri.fragment.isNotEmpty) {
        path = uri.fragment;
      } else if (uri.path.isNotEmpty) {
        path = uri.path;
      }
    }

    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    if (path.isEmpty) {
      path = organization.domain;
    }

    return path;
  }

  String? _parentPath(String urlPath) {
    final normalizedPath = _normalizeUrlPath(urlPath);
    final separatorIndex = normalizedPath.lastIndexOf('/');
    if (separatorIndex == -1) {
      return null;
    }
    return normalizedPath.substring(0, separatorIndex);
  }

  /// Verifies that a node's parent chain is intact (no closed parents).
  ///
  /// Returns true if all ancestors up to the root are valid (not closed).
  /// A broken parent chain can cause navigation breadcrumbs to be empty
  /// because the lineage property walks up the parent chain.
  bool _hasValidParentChain(GraphNode node) {
    GraphNode? current = node.parent;
    while (current != null) {
      if (current.isClosed) {
        if (kDebugMode) {
          LoggingService.instance.graphNodeDebug(
            'GraphRepository: Parent chain broken - closed parent found: '
            '${current.modelType.name}:${current.id} (child: ${node.id})',
          );
        }
        return false;
      }
      current = current.parent;
    }
    return true;
  }

  Future<void> dispose() async {
    _cacheManager.dispose();
    // Properly await all controller disposals to prevent memory leaks
    for (final controller in _managedStreamControllers) {
      await controller.dispose();
    }
    _managedStreamControllers.clear();
  }

  Stream<T> _wrapStream<T>(
    Stream<T> source,
    GraphRepositoryStreamMetadata metadata,
  ) {
    final factory =
        _streamControllerFactory ??
        GraphRepositoryStreamControllerScope.current?.factory;
    if (factory == null) {
      return source;
    }

    final controller = factory<T>(source, metadata);
    GraphRepositoryStreamControllerScope.current?.register(controller);
    _managedStreamControllers.add(controller);
    return controller.stream;
  }
}
