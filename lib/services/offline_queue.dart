// @tier: community
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seafoundry_app/mixins/safe_stream_controller_mixin.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:seafoundry_app/services/logging_service.dart';

/// Safe enum parsing that returns null if value not found
T? _tryParseEnum<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final e in values) {
    if (e.name == name) return e;
  }
  return null;
}

/// Represents a pending operation that needs to be synced
class PendingOperation {
  final String id;
  final OperationType type;
  final ModelType modelType;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? parentId;
  final Map<String, dynamic>? metadata;

  PendingOperation({
    required this.id,
    required this.type,
    required this.modelType,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.parentId,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'modelType': modelType.name,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'parentId': parentId,
    'metadata': metadata,
  };

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    // Validate required fields exist
    if (json['id'] == null || json['id'] is! String) {
      throw FormatException(
        'PendingOperation.fromJson: missing or invalid "id" field',
      );
    }
    if (json['type'] == null || json['type'] is! String) {
      throw FormatException(
        'PendingOperation.fromJson: missing or invalid "type" field',
      );
    }
    if (json['modelType'] == null || json['modelType'] is! String) {
      throw FormatException(
        'PendingOperation.fromJson: missing or invalid "modelType" field',
      );
    }
    if (json['data'] == null || json['data'] is! Map) {
      throw FormatException(
        'PendingOperation.fromJson: missing or invalid "data" field',
      );
    }
    if (json['createdAt'] == null || json['createdAt'] is! String) {
      throw FormatException(
        'PendingOperation.fromJson: missing or invalid "createdAt" field',
      );
    }

    // Parse enums safely
    final type = _tryParseEnum(OperationType.values, json['type']);
    if (type == null) {
      throw FormatException(
        'PendingOperation.fromJson: invalid OperationType "${json['type']}"',
      );
    }

    final modelType = _tryParseEnum(ModelType.values, json['modelType']);
    if (modelType == null) {
      throw FormatException(
        'PendingOperation.fromJson: invalid ModelType "${json['modelType']}"',
      );
    }

    // Parse timestamp safely
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['createdAt']);
    } catch (e) {
      throw FormatException(
        'PendingOperation.fromJson: invalid timestamp "${json['createdAt']}"',
      );
    }

    // Validate retryCount if present
    int retryCount = 0;
    if (json['retryCount'] != null) {
      if (json['retryCount'] is! int) {
        throw FormatException(
          'PendingOperation.fromJson: invalid "retryCount" type',
        );
      }
      retryCount = json['retryCount'];
    }

    return PendingOperation(
      id: json['id'],
      type: type,
      modelType: modelType,
      data: json['data'],
      createdAt: createdAt,
      retryCount: retryCount,
      parentId: json['parentId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  PendingOperation copyWith({int? retryCount}) {
    return PendingOperation(
      id: id,
      type: type,
      modelType: modelType,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      parentId: parentId,
      metadata: metadata,
    );
  }
}

/// Types of operations that can be queued
enum OperationType {
  create,
  update,
  move,
  delete,
  createEvent,
  bulkActivityPropagation,
  updateQuantity,
  updateHealthStatus,
}

/// Telemetry categories emitted whenever the offline queue changes.
enum OfflineQueueTelemetryAction {
  queued,
  synced,
  failed,
  dropped,
  stalled,
  cleared,
}

/// Event payload describing a telemetry update from the offline queue.
class OfflineQueueTelemetryEvent {
  OfflineQueueTelemetryEvent({
    required this.action,
    required this.operation,
    required this.queueSize,
    required this.timestamp,
    this.retryCount,
    this.details,
  });

  final OfflineQueueTelemetryAction action;
  final PendingOperation operation;
  final int queueSize;
  final DateTime timestamp;
  final int? retryCount;
  final Map<String, Object?>? details;
}

/// Service for managing offline operations queue
class OfflineQueue with SafeStreamControllerMixin {
  OfflineQueue._();
  static OfflineQueue? _instance;
  static OfflineQueue get instance => _instance ??= OfflineQueue._();

  @visibleForTesting
  static void resetForTest() {
    _instance?.dispose();
    _instance = null;
  }

  final _logger = LoggingService.instance;
  final _operationController = StreamController<PendingOperation>.broadcast();
  final _telemetryController =
      StreamController<OfflineQueueTelemetryEvent>.broadcast();
  bool _persistEnabled = true;

  Stream<PendingOperation> get operationStream => _operationController.stream;
  Stream<OfflineQueueTelemetryEvent> get telemetryStream =>
      _telemetryController.stream;

  static const _queueFileName = 'seafoundry_pending_ops.json';
  static const _maxRetries = 3;
  static const _stuckOperationThreshold = Duration(minutes: 30);

  Directory? _appDocDir;
  List<PendingOperation> _queue = [];
  bool _isDisposed = false;

  /// Initialize the offline queue
  Future<void> initialize() async {
    _logger.info('Initializing OfflineQueue');

    if (kIsWeb) {
      _persistEnabled = false;
      _queue = [];
      _logger.info(
        'OfflineQueue running in-memory only on web (disk persistence disabled)',
      );
      return;
    }

    try {
      _appDocDir = await getApplicationDocumentsDirectory();
      await _loadQueue();
      _detectStuckOperations();
      _logger.info(
        'OfflineQueue initialized with ${_queue.length} pending operations',
      );
    } catch (e) {
      _logger.error('Failed to initialize OfflineQueue', e);
      rethrow;
    }
  }

  /// Add an operation to the queue
  Future<void> addOperation(PendingOperation operation) async {
    if (_isDisposed) {
      _logger.warning(
        'Cannot add operation to disposed OfflineQueue: ${operation.type.name}',
      );
      return;
    }

    _queue.add(operation);
    await _saveQueue();
    tryAddToSink(_operationController, operation, debugLabel: 'OfflineQueue.operations');
    _emitTelemetry(OfflineQueueTelemetryAction.queued, operation);

    _logger.info(
      'Added ${operation.type.name} operation for ${operation.modelType.name} to offline queue',
    );
  }

  /// Create a pending operation for record creation
  Future<void> queueCreateRecord({
    required GraphNodeRecord record,
    required String parentId,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = PendingOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_create_${record.id}',
      type: OperationType.create,
      modelType: record.modelType,
      data: record.toJson(),
      createdAt: DateTime.now(),
      parentId: parentId,
      metadata: metadata,
    );

    await addOperation(operation);
  }

  /// Create a pending operation for record update
  Future<void> queueUpdateRecord({
    required GraphNodeRecord record,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = PendingOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_update_${record.id}',
      type: OperationType.update,
      modelType: record.modelType,
      data: record.toJson(),
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    await addOperation(operation);
  }

  /// Create a pending operation for record move
  Future<void> queueMoveRecord({
    required String recordId,
    required ModelType modelType,
    required String fromParentId,
    required String toParentId,
    Map<String, dynamic>? partialSelection,
    String? placeholderRecordId,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = PendingOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_move_$recordId',
      type: OperationType.move,
      modelType: modelType,
      data: {
        'recordId': recordId,
        'fromParentId': fromParentId,
        'toParentId': toParentId,
        if (partialSelection != null) ...partialSelection,
        if (placeholderRecordId != null)
          'placeholderRecordId': placeholderRecordId,
      },
      createdAt: DateTime.now(),
      metadata: {
        'fromParentId': fromParentId,
        'toParentId': toParentId,
        if (placeholderRecordId != null)
          'placeholderRecordId': placeholderRecordId,
        if (metadata != null) ...metadata,
      },
    );

    await addOperation(operation);
  }

  /// Create a pending operation for record delete
  Future<void> queueDeleteRecord({
    required InventoryRecord record,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = PendingOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_delete_${record.id}',
      type: OperationType.delete,
      modelType: record.modelType,
      data: {'recordId': record.id, 'record': record.toJson()},
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    await addOperation(operation);
  }

  /// Create a pending operation for event creation
  Future<void> queueCreateEvent({
    required Event event,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = PendingOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_event_${event.id}',
      type: OperationType.createEvent,
      modelType: ModelType.event,
      data: event.toJson(),
      createdAt: DateTime.now(),
      metadata: {
        'eventTypeId': event.eventTypeId,
        'recordId': event.recordId,
        if (metadata != null) ...metadata,
      },
    );

    await addOperation(operation);
  }

  /// Create a pending operation for bulk activity propagation.
  Future<void> queueBulkActivityPropagation({
    required Map<String, dynamic> payload,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = PendingOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_bulk_activity',
      type: OperationType.bulkActivityPropagation,
      modelType: ModelType.event,
      data: payload,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    await addOperation(operation);
  }

  /// Create a pending operation for quantity/measurement update.
  ///
  /// Stores all data needed to replay the measurement update when back online:
  /// - [organismSnapshot]: Full organism record at time of offline change
  /// - [oldMeasurement]: The measurement before the change (for conflict detection)
  /// - [newMeasurement]: The new measurement to apply
  /// - [reasonId]: The QuantityChangeReason id (e.g., 'mortality', 'transferOut')
  /// - [reasonKind]: 'gain' or 'loss' from QuantityChangeKind
  /// - [mortalityReasonId]: Optional mortality reason id if applicable
  /// - [comment]: Optional user comment
  Future<void> queueUpdateQuantity({
    required OrganismRecord organismSnapshot,
    required PopulationMeasurement oldMeasurement,
    required PopulationMeasurement newMeasurement,
    required String reasonId,
    required String reasonKind,
    String? mortalityReasonId,
    String? comment,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = PendingOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_quantity_${organismSnapshot.id}',
      type: OperationType.updateQuantity,
      modelType: ModelType.organismRecord,
      data: {
        'organismId': organismSnapshot.id,
        'organismSnapshot': organismSnapshot.toJson(),
        'oldMeasurement': oldMeasurement.toJson(),
        'newMeasurement': newMeasurement.toJson(),
        'reasonId': reasonId,
        'reasonKind': reasonKind,
        if (mortalityReasonId != null) 'mortalityReasonId': mortalityReasonId,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
      createdAt: DateTime.now(),
      metadata: {
        'organismId': organismSnapshot.id,
        'organizationId': organismSnapshot.organizationId,
        'oldValue': oldMeasurement.value,
        'newValue': newMeasurement.value,
        'reasonId': reasonId,
        'reasonKind': reasonKind,
        if (metadata != null) ...metadata,
      },
    );

    await addOperation(operation);
  }

  /// Get all pending operations
  List<PendingOperation> getPendingOperations() {
    return List.unmodifiable(_queue);
  }

  /// Get pending operations count
  int get pendingCount => _queue.length;

  /// Remove an operation from the queue
  Future<void> removeOperation(
    String operationId, {
    OfflineQueueTelemetryAction action = OfflineQueueTelemetryAction.synced,
    Map<String, Object?>? details,
  }) async {
    final index = _queue.indexWhere((op) => op.id == operationId);
    if (index == -1) {
      _logger.warning('Attempted to remove missing operation $operationId');
      return;
    }

    final removed = _queue.removeAt(index);
    await _saveQueue();
    _emitTelemetry(action, removed, details: details);

    _logger.debug('Removed operation $operationId from offline queue');
  }

  /// Mark an operation as failed and increment retry count
  Future<void> markOperationFailed(String operationId) async {
    final index = _queue.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      final operation = _queue[index];
      final newRetryCount = operation.retryCount + 1;

      if (newRetryCount >= _maxRetries) {
        _logger.error(
          'Operation $operationId exceeded max retries, removing from queue',
        );
        await removeOperation(
          operationId,
          action: OfflineQueueTelemetryAction.dropped,
          details: {'reason': 'max_retries'},
        );
      } else {
        final updated = operation.copyWith(retryCount: newRetryCount);
        _queue[index] = updated;
        await _saveQueue();
        _emitTelemetry(
          OfflineQueueTelemetryAction.failed,
          updated,
          retryCount: newRetryCount,
        );
        _logger.warning(
          'Operation $operationId failed, retry count: $newRetryCount',
        );
      }
    }
  }

  /// Clear all pending operations
  Future<void> clearAll() async {
    final removedOperations = List<PendingOperation>.from(_queue);
    _queue.clear();
    await _saveQueue();
    for (final operation in removedOperations) {
      _emitTelemetry(
        OfflineQueueTelemetryAction.cleared,
        operation,
        details: {'reason': 'manual_clear'},
      );
    }
    _logger.info('Cleared all pending operations from offline queue');
  }

  void _detectStuckOperations() {
    if (_queue.isEmpty) return;
    final now = DateTime.now();
    for (final operation in _queue) {
      final age = now.difference(operation.createdAt);
      if (age >= _stuckOperationThreshold) {
        _emitTelemetry(
          OfflineQueueTelemetryAction.stalled,
          operation,
          details: {'ageMinutes': age.inMinutes},
        );
      }
    }
  }

  void _emitTelemetry(
    OfflineQueueTelemetryAction action,
    PendingOperation operation, {
    int? retryCount,
    Map<String, Object?>? details,
  }) {
    final event = OfflineQueueTelemetryEvent(
      action: action,
      operation: operation,
      queueSize: _queue.length,
      timestamp: DateTime.now(),
      retryCount: retryCount,
      details: details,
    );
    tryAddToSink(_telemetryController, event, debugLabel: 'OfflineQueue.telemetry');
    _logTaggedTelemetry(
      action,
      operation,
      retryCount: retryCount,
      details: details,
    );
  }

  void _logTaggedTelemetry(
    OfflineQueueTelemetryAction action,
    PendingOperation operation, {
    int? retryCount,
    Map<String, Object?>? details,
  }) {
    final tags = <String>[];
    if (_isCsvOperation(operation)) tags.add('CSV');
    if (_isLoanOperation(operation)) tags.add('LOAN');
    if (tags.isEmpty) return;

    final summary =
        '[${tags.join('+')}] OfflineQueue ${action.name} ${operation.type.name} (${operation.modelType.name})';
    final extra = <String, Object?>{
      'operationId': operation.id,
      'retryCount': retryCount,
      'metadata': operation.metadata,
      if (details != null) ...details,
    };

    if (action == OfflineQueueTelemetryAction.failed ||
        action == OfflineQueueTelemetryAction.dropped ||
        action == OfflineQueueTelemetryAction.stalled) {
      _logger.warning(summary, extra);
    } else {
      _logger.info(summary, extra);
    }
  }

  bool _isCsvOperation(PendingOperation operation) {
    final metadata = operation.metadata;
    if (metadata == null || metadata.isEmpty) return false;
    final source = metadata['source']?.toString().toLowerCase();
    if (source == 'csv' || source == 'csv_import') return true;
    return metadata.keys.any((key) => key.toLowerCase().contains('csv'));
  }

  bool _isLoanOperation(PendingOperation operation) {
    final metadata = operation.metadata;
    final eventTypeId = metadata?['eventTypeId']?.toString();
    if (eventTypeId == LoanEventType.loan.id || eventTypeId == LoanEventType.legacyTransfer.id) {
      return true;
    }
    if (metadata == null) return false;
    return metadata.keys.any((key) => key.toLowerCase().contains('loan'));
  }

  /// Get the queue file
  Future<File> _getQueueFile() async {
    if (_appDocDir == null) {
      throw StateError('OfflineQueue not initialized');
    }
    return File('${_appDocDir!.path}/$_queueFileName');
  }

  /// Load queue from disk
  Future<void> _loadQueue() async {
    if (!_persistEnabled) return;
    try {
      final file = await _getQueueFile();

      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = json.decode(contents) as Map<String, dynamic>;
        final operations = (data['operations'] as List?) ?? [];

        // Parse operations individually with error handling
        final validOperations = <PendingOperation>[];
        var skippedCount = 0;

        for (var i = 0; i < operations.length; i++) {
          try {
            final op = PendingOperation.fromJson(operations[i]);
            validOperations.add(op);
          } catch (e) {
            skippedCount++;
            _logger.warning(
              'Skipped corrupted operation at index $i: $e',
              {'rawData': operations[i]},
            );
          }
        }

        _queue = validOperations;

        // If we skipped any corrupted entries, save the cleaned queue
        if (skippedCount > 0) {
          _logger.warning(
            'Loaded offline queue with $skippedCount corrupted entries skipped',
            {
              'totalOperations': operations.length,
              'validOperations': validOperations.length,
              'skippedCount': skippedCount,
            },
          );

          // Backup corrupted queue file before overwriting
          try {
            final backupFile = File('${file.path}.corrupted.backup');
            await file.copy(backupFile.path);
            _logger.info('Backed up corrupted queue to ${backupFile.path}');
          } catch (e) {
            _logger.error('Failed to backup corrupted queue file', e);
          }

          // Save cleaned queue
          await _saveQueue();
        }
      }
    } catch (e) {
      _logger.error('Failed to load offline queue', e);

      // Backup completely corrupted file
      try {
        final file = await _getQueueFile();
        if (await file.exists()) {
          final backupFile = File('${file.path}.invalid.backup');
          await file.copy(backupFile.path);
          _logger.info(
            'Backed up invalid queue file to ${backupFile.path}',
          );
        }
      } catch (backupError) {
        _logger.error('Failed to backup invalid queue file', backupError);
      }

      _queue = [];
    }
  }

  /// Save queue to disk
  Future<void> _saveQueue() async {
    if (!_persistEnabled) return;
    try {
      final file = await _getQueueFile();
      final data = {
        'version': 1,
        'operations': _queue.map((op) => op.toJson()).toList(),
        'lastModified': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(json.encode(data));
    } catch (e) {
      _logger.error('Failed to save offline queue', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;

    // Guard StreamController close to prevent double-dispose errors
    if (!_operationController.isClosed) {
      try {
        _operationController.close();
      } catch (e) {
        _logger.debug('Error closing operation controller: $e');
      }
    }

    if (!_telemetryController.isClosed) {
      try {
        _telemetryController.close();
      } catch (e) {
        _logger.debug('Error closing telemetry controller: $e');
      }
    }

    _queue = [];
    _appDocDir = null;
  }
}
