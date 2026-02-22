// @tier: community
import 'dart:async';

import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/activity_event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/offline_queue.dart';

/// Mirrors inventory events onto ancestor structures so activity feeds stay in
/// sync across trays, tanks, nurseries, and sites. Propagation is intentionally
/// best-effort: if an ancestor fails to load we skip it instead of surfacing an
/// error to the user.
class EventPropagationService {
  final ActivityEventRepository _activityEventRepository;

  EventPropagationService({
    required ActivityEventRepository activityEventRepository,
    OrganismContext? organismContext,
  }) : _activityEventRepository = activityEventRepository,
       organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral);

  final OrganismContext organismContext;

  /// Propagate an event to parent records
  ///
  /// This creates a reference activity event for each parent record.
  ///
  /// **Idempotency (P0-2):** Safe to retry - reuses existing ActivityEvents.
  /// **Atomicity (P0-3):** Uses WriteBatch for all-or-nothing semantics.
  Future<List<ActivityEvent>> propagateToParents({
    required Event sourceEvent,
    required GraphNode sourceNode,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
  }) async {
    final List<ActivityEvent> createdEvents = [];

    try {
      // Wait for source node with timeout to prevent hanging
      try {
        await sourceNode.awaitLoaded().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
              'Timeout waiting for source node to load',
              const Duration(seconds: 10),
            );
          },
        );
      } catch (e) {
        LoggingService.instance.warning(
          'Aborting propagation; source node failed to load (${sourceNode.id}): $e',
        );
        return createdEvents;
      }

      final sourceState = sourceNode.state;
      if (sourceState is! GraphLoadedState) {
        LoggingService.instance.warning(
          'Aborting propagation; source node failed to load (${sourceNode.id})',
        );
        return createdEvents;
      }
      final sourceRecord = sourceState.record as InventoryRecord;
      final propagatedOrganismKind = _organismKindForEvent(sourceEvent);

      final parentNodes = await _getParentNodes(sourceNode);

      // Load ALL parents with timeout and error handling to prevent hanging
      for (final parentNode in parentNodes) {
        try {
          await parentNode.awaitLoaded().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              LoggingService.instance.warning(
                'Timeout waiting for parent node ${parentNode.id} to load; will skip if still not loaded',
              );
            },
          );
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to load parent node ${parentNode.id}; will skip if not loaded: $e',
          );
        }
      }

      // STEP 1: Filter out parents that already have this propagation (IDEMPOTENCY)
      final parentsNeedingPropagation = <(GraphNode, InventoryRecord)>[];
      for (final parentNode in parentNodes) {
        final parentState = parentNode.state;
        if (parentState is! GraphLoadedState) {
          LoggingService.instance.warning(
            'Skipping propagation target; node failed to load (${parentNode.id})',
          );
          continue;
        }

        final parentRecord = parentState.record as InventoryRecord;

        final cachedEvent = await _activityEventRepository
            .findCachedActivityEventBySourceAndParent(
              sourceEventId: sourceEvent.id,
              parentRecordId: parentRecord.id,
            );
        if (cachedEvent != null) {
          LoggingService.instance.info(
            'Skipping duplicate propagation to ${parentNode.id} (cached: ${cachedEvent.id})',
          );
          createdEvents.add(cachedEvent);
          continue;
        }

        final existingEvent = await _activityEventRepository
            .findActivityEventBySourceAndParent(
              sourceEventId: sourceEvent.id,
              parentRecordId: parentRecord.id,
            );

        if (existingEvent != null) {
          LoggingService.instance.info(
            'Skipping duplicate propagation to ${parentNode.id} (existing: ${existingEvent.id})',
          );
          createdEvents.add(existingEvent);
          continue;
        }

        parentsNeedingPropagation.add((parentNode, parentRecord));
      }

      if (parentsNeedingPropagation.isEmpty) {
        return createdEvents;
      }

      final isOnline = _activityEventRepository.isOnline;
      // STEP 2: Create all events in a single atomic batch (ATOMICITY)
      final batch = isOnline ? _activityEventRepository.db.batch() : null;
      final newEvents = <ActivityEvent>[];

      for (final (_, parentRecord) in parentsNeedingPropagation) {
        final activityEvent = await _activityEventRepository.createActivityEvent(
          recordId: parentRecord.id,
          recordModelType: parentRecord.modelType,
          activityType: activityType,
          description: description ?? _buildDescription(sourceRecord, parentRecord),
          parameters: _mergeParameters(
            sourceEvent: sourceEvent,
            additionalParameters: parameters,
          ),
          parentPath: parentRecord.urlPath,
          parentInternalPath: parentRecord.internalPath,
          organismKindOverride: propagatedOrganismKind,
          batch: batch,
        );
        newEvents.add(activityEvent);
      }

      if (isOnline && batch != null) {
        // Atomic commit - all-or-nothing
        try {
          await batch.commit();
          // CRITICAL: Only cache events AFTER successful batch commit.
          // This prevents idempotency check failures when batch commit fails
          // and events are retried (events would be cached but not in Firestore).
          await _activityEventRepository.cacheActivityEventsAfterCommit(newEvents);
        } catch (e, stackTrace) {
          LoggingService.instance.warning(
            'Batch commit failed; queueing activity events for offline sync',
            {'error': e.toString(), 'stackTrace': stackTrace.toString()},
          );
          for (final event in newEvents) {
            await _activityEventRepository.queueActivityEventForOfflineSync(event);
          }
        }
      }
      createdEvents.addAll(newEvents);

      LoggingService.instance.info(
        'Propagated $activityType to ${newEvents.length} parents from ${sourceNode.id}',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to propagate event to parents', e, stackTrace);
    }

    return createdEvents;
  }

  /// Create lightweight activity references for specific target records.
  ///
  /// This is used for multi-target actions where a single parent event should
  /// appear in each target's activity feed without duplicating full events.
  Future<List<ActivityEvent>> propagateToTargets({
    required Event sourceEvent,
    required Iterable<InventoryRecord> targetRecords,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
    Map<String, dynamic> Function(InventoryRecord record)? parametersBuilder,
    bool queueOnly = false,
    bool useLocalSlug = false,
    bool skipRemoteCheck = false,
  }) async {
    final createdEvents = <ActivityEvent>[];

    final uniqueTargets = <String, InventoryRecord>{};
    for (final record in targetRecords) {
      if (record.id == sourceEvent.recordId) {
        continue;
      }
      uniqueTargets[record.id] = record;
    }

    if (uniqueTargets.isEmpty) {
      return createdEvents;
    }

    final propagatedOrganismKind = _organismKindForEvent(sourceEvent);
    final isOnline = _activityEventRepository.isOnline;
    final shouldBatch = isOnline && !queueOnly;
    final batch = shouldBatch ? _activityEventRepository.db.batch() : null;
    final newEvents = <ActivityEvent>[];

    for (final record in uniqueTargets.values) {
      final cachedEvent = await _activityEventRepository
          .findCachedActivityEventBySourceAndParent(
            sourceEventId: sourceEvent.id,
            parentRecordId: record.id,
          );
      if (cachedEvent != null) {
        createdEvents.add(cachedEvent);
        continue;
      }

      if (!skipRemoteCheck) {
        final existingEvent = await _activityEventRepository
            .findActivityEventBySourceAndParent(
              sourceEventId: sourceEvent.id,
              parentRecordId: record.id,
            );
        if (existingEvent != null) {
          createdEvents.add(existingEvent);
          continue;
        }
      }

      final perTargetParameters = parametersBuilder?.call(record);
      final mergedParameters = _mergeAdditionalParameters(
        parameters,
        perTargetParameters,
      );

      final activityEvent = await _activityEventRepository.createActivityEvent(
        recordId: record.id,
        recordModelType: record.modelType,
        activityType: activityType,
        description: description,
        parameters: _mergeParameters(
          sourceEvent: sourceEvent,
          additionalParameters: mergedParameters,
        ),
        parentPath: record.urlPath,
        parentInternalPath: record.internalPath,
        organismKindOverride: propagatedOrganismKind,
        batch: batch,
        queueOnly: queueOnly,
        useLocalSlug: useLocalSlug,
      );
      newEvents.add(activityEvent);
    }

    if (shouldBatch && batch != null) {
      try {
        await batch.commit();
        // CRITICAL: Only cache events AFTER successful batch commit.
        // This prevents idempotency check failures when batch commit fails
        // and events are retried (events would be cached but not in Firestore).
        await _activityEventRepository.cacheActivityEventsAfterCommit(newEvents);
      } catch (e, stackTrace) {
        LoggingService.instance.warning(
          'Batch commit failed; queueing activity reference events for offline sync',
          {'error': e.toString(), 'stackTrace': stackTrace.toString()},
        );
        for (final event in newEvents) {
          await _activityEventRepository.queueActivityEventForOfflineSync(event);
        }
      }
    }

    createdEvents.addAll(newEvents);
    return createdEvents;
  }

  /// Convenience wrapper that resolves records from target nodes and creates
  /// activity references for each.
  Future<List<ActivityEvent>> propagateToTargetNodes({
    required Event sourceEvent,
    required Iterable<GraphNode> targetNodes,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
    Map<String, dynamic> Function(InventoryRecord record)? parametersBuilder,
    bool queueOnly = false,
    bool useLocalSlug = false,
    bool skipRemoteCheck = false,
  }) async {
    final records = <InventoryRecord>[];
    for (final node in targetNodes) {
      if (node.isClosed) {
        continue;
      }
      try {
        await node.awaitLoaded().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            LoggingService.instance.warning(
              'Timeout waiting for target node ${node.id} to load; using initial record',
            );
          },
        );
      } catch (e) {
        LoggingService.instance.warning(
          'Failed to load target node ${node.id}; using initial record: $e',
        );
      }
      final state = node.state;
      if (state is GraphLoadedState) {
        records.add(state.record as InventoryRecord);
      } else {
        records.add(node.initialRecord as InventoryRecord);
      }
    }

    return propagateToTargets(
      sourceEvent: sourceEvent,
      targetRecords: records,
      activityType: activityType,
      description: description,
      parameters: parameters,
      parametersBuilder: parametersBuilder,
      queueOnly: queueOnly,
      useLocalSlug: useLocalSlug,
      skipRemoteCheck: skipRemoteCheck,
    );
  }

  /// Queue bulk activity references for offline-safe propagation.
  ///
  /// Creates a single offline queue operation that will expand into
  /// per-target ActivityEvents when synced. This avoids blocking UI while
  /// ensuring propagation still completes after navigation or app restarts.
  Future<void> queueActivityPropagation({
    required Event sourceEvent,
    required Iterable<InventoryRecord> targetRecords,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
    Map<String, dynamic> Function(InventoryRecord record)? parametersBuilder,
  }) async {
    final uniqueTargets = <String, InventoryRecord>{};
    for (final record in targetRecords) {
      if (record.id == sourceEvent.recordId) {
        continue;
      }
      uniqueTargets[record.id] = record;
    }

    if (uniqueTargets.isEmpty) {
      return;
    }

    final nowIso = DateTime.now().toIso8601String();
    final organismKind = _organismKindForEvent(sourceEvent).name;
    final targetPayloads = <Map<String, dynamic>>[];

    var processed = 0;
    for (final record in uniqueTargets.values) {
      final perTargetParameters = parametersBuilder?.call(record);
      final mergedParameters = _mergeAdditionalParameters(
        parameters,
        perTargetParameters,
      );

      final eventId = '${sourceEvent.id}_${record.id}';
      targetPayloads.add({
        'recordId': record.id,
        'recordModelType': record.modelType.name,
        'urlPath': record.urlPath,
        'internalPath': record.internalPath,
        'eventId': eventId,
        'eventSlug': eventId,
        'parameters': _mergeParameters(
          sourceEvent: sourceEvent,
          additionalParameters: mergedParameters,
        ),
      });
      processed++;
      if (processed % 50 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final payload = <String, dynamic>{
      'sourceEventId': sourceEvent.id,
      'activityType': activityType,
      'description': description,
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'createdById': sourceEvent.createdById,
      'updatedById': sourceEvent.updatedById,
      'organizationId': sourceEvent.organizationId,
      'organismKind': organismKind,
      'targets': targetPayloads,
    };

    await OfflineQueue.instance.queueBulkActivityPropagation(
      payload: payload,
      metadata: {
        'sourceEventId': sourceEvent.id,
        'activityType': activityType,
        'targetCount': targetPayloads.length,
      },
    );
  }

  Future<void> queueActivityPropagationToTargetNodes({
    required Event sourceEvent,
    required Iterable<GraphNode> targetNodes,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
    Map<String, dynamic> Function(InventoryRecord record)? parametersBuilder,
  }) async {
    final records = <InventoryRecord>[];
    for (final node in targetNodes) {
      final state = node.state;
      if (state is GraphLoadedState) {
        records.add(state.record as InventoryRecord);
      } else {
        records.add(node.initialRecord as InventoryRecord);
      }
    }

    await queueActivityPropagation(
      sourceEvent: sourceEvent,
      targetRecords: records,
      activityType: activityType,
      description: description,
      parameters: parameters,
      parametersBuilder: parametersBuilder,
    );
  }

  Map<String, dynamic>? _mergeAdditionalParameters(
    Map<String, dynamic>? base,
    Map<String, dynamic>? override,
  ) {
    if (base == null && override == null) {
      return null;
    }
    return <String, dynamic>{
      if (base != null) ...base,
      if (override != null) ...override,
    };
  }

  Map<String, dynamic> _mergeParameters({
    required Event sourceEvent,
    Map<String, dynamic>? additionalParameters,
  }) {
    final merged = <String, dynamic>{
      'organismKind': _organismKindForEvent(sourceEvent).name,
      'sourceEventId': sourceEvent.id,
      'sourceRecordId': sourceEvent.recordId,
      'sourceRecordType': sourceEvent.recordModelType.name,
    };
    if (additionalParameters != null) {
      merged.addAll(additionalParameters);
    }
    return merged;
  }

  OrganismKind _organismKindForEvent(Event sourceEvent) {
    final rawKind = sourceEvent.metadata?['organismKind']?.toString();
    return OrganismKindX.tryParse(rawKind) ?? organismContext.kind;
  }

  /// Maximum depth for parent traversal to prevent unbounded recursion.
  static const int _maxParentDepth = 20;

  /// Get parent nodes for propagation.
  ///
  /// Includes cycle detection to prevent infinite loops if the graph
  /// contains cycles. Also limits traversal depth to [_maxParentDepth].
  Future<List<GraphNode>> _getParentNodes(GraphNode node) async {
    final parents = <GraphNode>[];
    final visitedIds = <String>{node.id};
    GraphNode? current = node.parent;
    var depth = 0;

    while (current != null && depth < _maxParentDepth) {
      final currentId = current.id;

      // Cycle detection: if we've already visited this node, log and stop
      if (visitedIds.contains(currentId)) {
        LoggingService.instance.error(
          'Cycle detected in parent graph traversal',
          GraphCycleDetectedError(
            nodeId: node.id,
            cycleNodeId: currentId,
            visitedPath: visitedIds.toList(),
          ),
          StackTrace.current,
        );
        break;
      }

      visitedIds.add(currentId);
      parents.add(current);
      current = current.parent;
      depth++;
    }

    if (depth >= _maxParentDepth) {
      LoggingService.instance.warning(
        'Parent traversal reached max depth ($_maxParentDepth) for node ${node.id}',
        {'visitedIds': visitedIds.toList()},
      );
    }

    return parents;
  }

  /// Generate a human-readable description to link the propagated event to its
  /// source record.
  String _buildDescription(
    InventoryRecord sourceRecord,
    InventoryRecord parentRecord,
  ) {
    final sourceType = sourceRecord.modelType.name;
    final parentType = parentRecord.modelType.name;
    final sourceName = _getRecordName(sourceRecord);
    final parentName = _getRecordName(parentRecord);

    return 'Activity from $sourceType "$sourceName" in $parentType "$parentName"';
  }

  /// Get display name for a record
  String _getRecordName(InventoryRecord record) {
    if (record is OrganismRecord) return record.name;
    if (record is Group) return record.name;
    if (record is Site) return record.name;
    if (record is Organization) return record.name;
    if (record is Genet) return record.name;
    return record.id;
  }

  /// Propagate health observation events
  Future<List<ActivityEvent>> propagateHealthObservation({
    required ObservationEvent observation,
    required GraphNode observationNode,
  }) async {
    String activityType = 'health_observation';
    String description = 'Health observation recorded';

    if (observation.healthIssueTypeId != null) {
      final healthIssue = HealthIssueType.fromId(observation.healthIssueTypeId);
      if (healthIssue != null) {
        activityType = 'health_issue_${healthIssue.id}';
        description = 'Health issue detected: ${healthIssue.label}';
      }
    }

    return propagateToParents(
      sourceEvent: observation,
      sourceNode: observationNode,
      activityType: activityType,
      description: description,
      parameters: {
        'healthIssueTypeId': observation.healthIssueTypeId,
        'oldHealthStatus': observation.oldHealthStatus,
        'newHealthStatus': observation.newHealthStatus,
      },
    );
  }

  /// Propagate feeding events
  Future<List<ActivityEvent>> propagateFeeding({
    required FeedingEvent feeding,
    required GraphNode feedingNode,
  }) async {
    return propagateToParents(
      sourceEvent: feeding,
      sourceNode: feedingNode,
      activityType: 'feeding',
      description: 'Feeding activity recorded',
      parameters: {
        'foodTypeId': feeding.foodTypeId,
        'amount': feeding.amount,
        'unit': feeding.unit,
      },
    );
  }

  /// Propagate task events
  Future<List<ActivityEvent>> propagateTask({
    required TaskEvent task,
    required GraphNode taskNode,
  }) async {
    return propagateToParents(
      sourceEvent: task,
      sourceNode: taskNode,
      activityType: 'husbandry_task',
      description: 'Husbandry task: ${task.title}',
      parameters: {
        'taskTitle': task.title,
        'husbandryActionTypeId': task.husbandryActionTypeId,
        'priorityId': task.priorityId,
        'isCompleted': task.completedAt != null,
      },
    );
  }

  /// Propagate water quality test events
  Future<List<ActivityEvent>> propagateWaterQualityTest({
    required WaterQualityTestEvent test,
    required GraphNode testNode,
  }) async {
    return propagateToParents(
      sourceEvent: test,
      sourceNode: testNode,
      activityType: 'water_quality_test',
      description: 'Water quality test performed',
      parameters: {
        'parameterCount': test.parameterValues.length,
        'parameters': test.parameterValues,
      },
    );
  }

  /// Propagate transfer (move in/out) events to parent hierarchy
  Future<List<ActivityEvent>> propagateTransfer({
    required Event transferEvent,
    required GraphNode transferNode,
  }) async {
    String activityType;
    String description;
    Map<String, dynamic> parameters = {};

    if (transferEvent is MoveInEvent) {
      activityType = 'transfer_in';
      description = 'Organisms moved in from ${transferEvent.fromUrlPath}';
      parameters = {
        'fromParentId': transferEvent.fromParentId,
        'toParentId': transferEvent.toParentId,
        'direction': 'in',
      };
    } else if (transferEvent is MoveOutEvent) {
      activityType = 'transfer_out';
      description = 'Organisms moved out to ${transferEvent.toUrlPath}';
      parameters = {
        'fromParentId': transferEvent.fromParentId,
        'toParentId': transferEvent.toParentId,
        'direction': 'out',
      };
    } else {
      // Not a transfer event, skip
      return [];
    }

    return propagateToParents(
      sourceEvent: transferEvent,
      sourceNode: transferNode,
      activityType: activityType,
      description: description,
      parameters: parameters,
    );
  }
}
