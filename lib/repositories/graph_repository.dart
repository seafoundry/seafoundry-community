import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:seafoundry_community/errors/domain_errors.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/graph_node_events.dart';
import 'package:seafoundry_community/models/graph/graph_node_state.dart';
import 'package:seafoundry_community/models/graph/group_node.dart';
import 'package:seafoundry_community/models/graph/organism_node.dart';
import 'package:seafoundry_community/models/graph/organization_node.dart';
import 'package:seafoundry_community/models/graph/site_node.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/repositories/firebase_utils.dart';
import 'package:seafoundry_community/repositories/inventory/inventory_record_repository.dart';
import 'package:seafoundry_community/repositories/repositories.dart';
import 'package:seafoundry_community/services/graph_cache_manager.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/services/site_capability_guard.dart';
import 'package:seafoundry_community/utils/performance_analyzer.dart';

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

    // PLAN-THEN-COMMIT: build the full move plan OUTSIDE any transaction. The
    // traversal loads nodes from in-memory graph state (never through the
    // transaction) and pre-mints every slug there — each slug mint opens its own
    // transaction and MUST NOT be nested inside the outer move transaction.
    final plan = await _buildMovePlan(
      node,
      newParent.state.record,
      partialSelection: partialSelection,
    );

    // Use Firestore transaction to ensure atomicity - either all moves succeed
    // or none. The closure performs READS (optimistic-lock guards) first, then
    // WRITES from the pre-built plan; it opens no nested transaction and mints
    // no slugs.
    // Retry logic handles intermittent Firestore SDK assertion errors (known
    // issue in v12.3.0). See: https://github.com/firebase/firebase-js-sdk/issues/9267
    await _runTransactionWithRetry(
      () => db.runTransaction((transaction) async {
        // READS FIRST — Firestore requires all reads before any write.
        for (final guard in plan.guards) {
          final snap = await transaction.get(guard.ref);
          if (!snap.exists) {
            throw RepositoryError(
              message:
                  'A record in this move no longer exists. Refresh and try again.',
            );
          }
          final expected = guard.expectedUpdatedAt;
          if (expected != null && snap.data()?['updatedAt'] != expected) {
            throw RepositoryError(
              message:
                  'This move is out of date — another change happened. '
                  'Refresh and try again.',
            );
          }
        }
        // WRITES — apply the pre-built plan. No slug mints, no sub-transactions.
        for (final item in plan.items) {
          await _writeMoveItem(item, transaction, moveReason, base);
        }
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
  /// This NO LONGER covers nested-transaction assertions: slug minting is now
  /// pre-computed OUTSIDE the outer move transaction (plan-then-commit), so the
  /// former "cannot allocate an identifier" / nested-`runTransaction` hang is
  /// structurally impossible and cannot be retried into existence here.
  ///
  /// It remains as defense-in-depth for a DIFFERENT documented issue: the
  /// intermittent Firestore SDK assertion errors that occur when a transaction
  /// races active snapshot listeners (Firebase JS SDK v12.3.0).
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

  /// Test-only view of a built move plan. Returns, in DFS commit order, the
  /// per-node PRE-MINTED slug lists (organism slug first for split nodes, then
  /// moveOut + moveIn event slugs), the moved record ids, and the optimistic-
  /// lock guard details. Building the plan performs ALL slug minting OUTSIDE any
  /// transaction, so this proves the "mint before commit" property and the DFS
  /// slug counts/order. It fails if a mint is moved back inside the commit txn.
  @visibleForTesting
  Future<
    ({
      List<List<String>> perNodeSlugs,
      List<String> recordIds,
      List<String?> guardUpdatedAt,
    })
  >
  debugBuildMovePlan(
    GraphNode node,
    GraphNodeRecord newParent, {
    PartialMoveSelection? partialSelection,
  }) async {
    final plan = await _buildMovePlan(
      node,
      newParent,
      partialSelection: partialSelection,
    );
    return (
      perNodeSlugs: plan.items
          .map(
            (i) => <String>[
              if (i.partialNewOrganismSlug != null) i.partialNewOrganismSlug!,
              i.moveOutSlug,
              i.moveInSlug,
            ],
          )
          .toList(),
      recordIds: plan.items.map((i) => i.record.id).toList(),
      guardUpdatedAt: plan.guards.map((g) => g.expectedUpdatedAt).toList(),
    );
  }

  /// Builds the complete, ordered move plan for [node] (and its selected
  /// subtree) moving under [newParent], entirely OUTSIDE any transaction.
  ///
  /// Traversal reads only in-memory graph-node state (never through a
  /// transaction — the move transaction performs no `transaction.get` on moved
  /// records today), and pre-mints every slug in DFS order so the commit pass
  /// consumes them in the exact order the old in-transaction recursion produced.
  Future<_MovePlan> _buildMovePlan(
    GraphNode node,
    GraphNodeRecord newParent, {
    PartialMoveSelection? partialSelection,
  }) async {
    final items = <_MoveWorkItem>[];
    final guards = <_MoveGuard>[];
    await _planMoveNode(node, newParent, partialSelection, items, guards);
    return _MovePlan(items, guards);
  }

  /// Recursive DFS plan builder mirroring the old `moveRecordRecursive` traversal
  /// step-for-step, but appending [_MoveWorkItem]s / [_MoveGuard]s and minting
  /// slugs instead of writing to a transaction.
  Future<void> _planMoveNode(
    GraphNode node,
    GraphNodeRecord newParent,
    PartialMoveSelection? partialSelection,
    List<_MoveWorkItem> items,
    List<_MoveGuard> guards,
  ) async {
    LoggingService.instance.info(
      'GraphRepository._planMoveNode called for ${node.modelType}:',
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

    final record = loadedState.record;
    final fromParent = node.parent!.state.record;

    // Capture a single `now` so the plan-time moved record (used to chain
    // children) and the commit-time write agree; paths are `now`-independent.
    final now = DateTime.now().toIso8601String();
    final willSplit =
        eventRecordRepository.willSplitOnMove(record, filteredSelection);

    // Pre-mint slugs OUTSIDE the transaction, in the SAME order the old
    // in-transaction path consumed them:
    //   full move  -> [moveOut(event), moveIn(event)]
    //   split move -> [newOrganism(record), moveOut(event), moveIn(event)]
    String? partialNewOrganismSlug;
    String? partialNewOrganismId;
    final GraphNodeRecord movedRecord;
    if (willSplit && record is OrganismRecord) {
      partialNewOrganismSlug = await eventRecordRepository
          .nextSlugForModelType(eventRecordRepository.modelType);
      partialNewOrganismId = generateId(firestore: db);
      final requestedQty = filteredSelection!.partialQuantities[record.id]!;
      movedRecord = eventRecordRepository.computePartialMovedOrganism(
        record: record,
        toParent: newParent,
        requestedQty: requestedQty,
        newOrganismId: partialNewOrganismId,
        newSlug: partialNewOrganismSlug,
        now: now,
      );
    } else {
      movedRecord =
          eventRecordRepository.computeMovedRecordForMove(
                record: record,
                toParent: newParent,
                now: now,
              )
              as GraphNodeRecord;
    }

    final moveOutSlug =
        await eventRepository.nextSlugForModelType(ModelType.event);
    final moveInSlug =
        await eventRepository.nextSlugForModelType(ModelType.event);
    final moveOutEventId = generateId(firestore: db);
    final moveInEventId = generateId(firestore: db);

    items.add(
      _MoveWorkItem(
        repo: eventRecordRepository,
        record: record,
        fromParent: fromParent,
        toParent: newParent,
        events: loadedState.events,
        selection: filteredSelection,
        moveOutSlug: moveOutSlug,
        moveInSlug: moveInSlug,
        moveOutEventId: moveOutEventId,
        moveInEventId: moveInEventId,
        partialNewOrganismSlug: partialNewOrganismSlug,
        partialNewOrganismId: partialNewOrganismId,
      ),
    );
    // One optimistic-lock guard per moved/reduced source record.
    guards.add(
      _MoveGuard(
        eventRecordRepository.collectionRef.doc(record.id),
        record.updatedAt,
      ),
    );

    if (filteredSelection == null || filteredSelection.moveAll) {
      for (final child in loadedState.children) {
        await _planMoveNode(child, movedRecord, null, items, guards);
      }
      return;
    }

    for (final child in loadedState.children) {
      final childSelection = filteredSelection.forChild(child.id);
      if (!childSelection.hasSelection) continue;

      await _planMoveNode(child, movedRecord, childSelection, items, guards);
    }
  }

  /// Applies one planned per-node move inside the outer transaction, preserving
  /// the exact write order of the former recursion:
  ///   full node    -> set(record), moveOut, moveIn, re-pathed events
  ///   partial node -> set(new), update(source), moveOut, moveIn, re-pathed events
  ///
  /// Reuses the repository write methods with PRE-MINTED slugs, so no slug is
  /// minted and no nested transaction is opened inside the closure.
  Future<void> _writeMoveItem(
    _MoveWorkItem item,
    Transaction transaction,
    String? moveReason,
    EventBaseParams base,
  ) async {
    final moved =
        await item.repo.moveRecord(
              record: item.record,
              fromParent: item.fromParent,
              toParent: item.toParent,
              transaction: transaction,
              moveOutSlug: item.moveOutSlug,
              moveInSlug: item.moveInSlug,
              moveOutEventId: item.moveOutEventId,
              moveInEventId: item.moveInEventId,
              partialNewOrganismSlug: item.partialNewOrganismSlug,
              partialNewOrganismId: item.partialNewOrganismId,
              partialSelection: item.selection,
              moveReason: moveReason,
              base: base,
            )
            as GraphNodeRecord;

    await eventRepository.moveEvents(
      events: item.events,
      fromRecord: item.record,
      toRecord: moved,
      transaction: transaction,
    );
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

/// One planned per-node move, carrying the loaded records/events and the
/// PRE-MINTED slugs/ids the commit pass writes with. Built entirely outside any
/// transaction by [GraphRepository._buildMovePlan].
class _MoveWorkItem {
  const _MoveWorkItem({
    required this.repo,
    required this.record,
    required this.fromParent,
    required this.toParent,
    required this.events,
    required this.selection,
    required this.moveOutSlug,
    required this.moveInSlug,
    required this.moveOutEventId,
    required this.moveInEventId,
    required this.partialNewOrganismSlug,
    required this.partialNewOrganismId,
  });

  final InventoryRecordRepository repo;
  final GraphNodeRecord record;
  final GraphNodeRecord fromParent;
  final GraphNodeRecord toParent;
  final List<Event> events;
  final PartialMoveSelection? selection;
  final String moveOutSlug;
  final String moveInSlug;
  final String moveOutEventId;
  final String moveInEventId;

  /// Non-null only for partial (split) moves.
  final String? partialNewOrganismSlug;
  final String? partialNewOrganismId;
}

/// Optimistic-lock guard: the commit pass `transaction.get`s [ref] first and
/// aborts if the doc is gone or its `updatedAt` no longer matches
/// [expectedUpdatedAt]. MOVE had no optimistic lock before plan-then-commit;
/// this is a strict improvement.
class _MoveGuard {
  const _MoveGuard(this.ref, this.expectedUpdatedAt);

  final DocumentReference<Map<String, dynamic>> ref;
  final String? expectedUpdatedAt;
}

/// The full ordered move plan: commit-order write items plus optimistic-lock
/// guards.
class _MovePlan {
  const _MovePlan(this.items, this.guards);

  final List<_MoveWorkItem> items;
  final List<_MoveGuard> guards;
}
