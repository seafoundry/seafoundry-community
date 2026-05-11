import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for managing record snapshots before and after events
///
/// **Purpose**: Captures point-in-time state of records for audit trails and
/// efficient state reconstruction. Snapshots enable fast historical queries without
/// replaying entire event histories.
///
/// **Design Decisions**:
/// - **Before/After pattern**: Captures state both before and after modifications
///   to enable delta calculations and rollback capabilities.
/// - **Firestore persistence**: All snapshots persisted to Firestore for durability
///   and cross-device consistency.
///
/// **Usage**: Used by StateReconstructionService for fast historical queries,
/// and by analytics services that need before/after comparisons of record changes.
class SnapshotService {
  final FirebaseFirestore _firestore;
  final LoggingService _logger = LoggingService.instance;
  static final _timestampOverrideKey = Object();

  SnapshotService({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  DateTime _currentTimestamp() =>
      (Zone.current[_timestampOverrideKey] as DateTime?) ??
      DateTime.now().toUtc();

  Future<T> withTimestampOverride<T>(
    DateTime timestamp,
    Future<T> Function() action,
  ) async {
    return runZoned(
      () => action(),
      zoneValues: {_timestampOverrideKey: timestamp.toUtc()},
    );
  }

  /// Creates a snapshot of a record before it's modified
  Future<RecordSnapshot> createBeforeSnapshot({
    required InventoryRecord record,
    required String eventId,
  }) async {
    try {
      final filteredData = await _filterSnapshotPayload(record.toJson());
      final snapshot = RecordSnapshot(
        id: '${record.id}_${eventId}_before',
        recordId: record.id,
        recordType: record.modelType,
        eventId: eventId,
        timestamp: _currentTimestamp(),
        snapshotType: SnapshotType.before,
        data: filteredData,
        organizationId: record.organizationId, // Required for Firestore security rules
      );

      await _firestore
          .collection('snapshots')
          .doc(snapshot.id)
          .set(snapshot.toJson());

      _logger.info('Created before snapshot for ${record.id}');
      return snapshot;
    } catch (e) {
      _logger.error('Failed to create before snapshot', e);
      rethrow;
    }
  }

  /// Creates a snapshot of a record after it's modified
  Future<RecordSnapshot> createAfterSnapshot({
    required InventoryRecord record,
    required String eventId,
  }) async {
    try {
      final filteredData = await _filterSnapshotPayload(record.toJson());
      final snapshot = RecordSnapshot(
        id: '${record.id}_${eventId}_after',
        recordId: record.id,
        recordType: record.modelType,
        eventId: eventId,
        timestamp: _currentTimestamp(),
        snapshotType: SnapshotType.after,
        data: filteredData,
        organizationId: record.organizationId, // Required for Firestore security rules
      );

      await _firestore
          .collection('snapshots')
          .doc(snapshot.id)
          .set(snapshot.toJson());

      _logger.info('Created after snapshot for ${record.id}');
      return snapshot;
    } catch (e) {
      _logger.error('Failed to create after snapshot', e);
      rethrow;
    }
  }


  Future<Map<String, dynamic>> _filterSnapshotPayload(
    Map<String, dynamic> payload,
  ) async {
    return _hoistMetadataFields(payload);
  }

  Map<String, dynamic> _hoistMetadataFields(Map<String, dynamic> payload) {
    final normalized = Map<String, dynamic>.from(payload);
    final metadata = payload['metadata'];
    if (metadata is Map<String, dynamic>) {
      for (final entry in metadata.entries) {
        normalized.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return normalized;
  }

}

/// Represents a snapshot of a single record
class RecordSnapshot {
  final String id;
  final String recordId;
  final ModelType recordType;
  final String eventId;
  final DateTime timestamp;
  final SnapshotType snapshotType;
  final Map<String, dynamic> data;
  final String organizationId; // Required for Firestore security rules

  RecordSnapshot({
    required this.id,
    required this.recordId,
    required this.recordType,
    required this.eventId,
    required this.timestamp,
    required this.snapshotType,
    required this.data,
    required this.organizationId,
  });

  factory RecordSnapshot.fromJson(Map<String, dynamic> json) {
    return RecordSnapshot(
      id: json['id'],
      recordId: json['recordId'],
      recordType: ModelType.values.byName(json['recordType']),
      eventId: json['eventId'],
      timestamp: DateTime.parse(json['timestamp']),
      snapshotType: SnapshotType.values.byName(json['snapshotType']),
      data: Map<String, dynamic>.from(json['data']),
      organizationId: json['organizationId'] ?? '', // Nullable for backward compatibility
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recordId': recordId,
      'recordType': recordType.name,
      'eventId': eventId,
      'timestamp': timestamp.toIso8601String(),
      'snapshotType': snapshotType.name,
      'data': data,
      'organizationId': organizationId, // Required for Firestore security rules
    };
  }

  RecordSnapshot copyWith({Map<String, dynamic>? data}) {
    return RecordSnapshot(
      id: id,
      recordId: recordId,
      recordType: recordType,
      eventId: eventId,
      timestamp: timestamp,
      snapshotType: snapshotType,
      data: data ?? this.data,
      organizationId: organizationId,
    );
  }
}

enum SnapshotType { before, after }
