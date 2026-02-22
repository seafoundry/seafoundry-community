// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/services/tiered_field_registry.dart';

/// Repository for managing snapshot records and comparisons
class SnapshotRepository {
  final FirebaseFirestore _firestore;
  final String _organizationId;
  Tier _tier;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  SnapshotRepository({
    required FirebaseFirestore firestore,
    required String organizationId,
    Tier tier = Tier.scale,
  })  : _firestore = firestore,
        _organizationId = organizationId,
        _tier = tier;

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _resolver.collection(_firestore, ModelType.event.collectionPath);
  CollectionReference<Map<String, dynamic>> get _snapshotRecordsCollection =>
      _resolver.collection(_firestore, 'snapshot_records');

  /// Apply organization scoping to any collection query.
  Query<Map<String, dynamic>> _organizationQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) =>
      collectionRef.where('organizationId', isEqualTo: _organizationId);

  void updateTier(Tier tier) {
    _tier = tier;
  }

  /// Get all snapshots for a specific record
  Future<List<InventoryRecord>> getSnapshotsForRecord({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      // CRITICAL: Must include organizationId filter to satisfy Firestore security rules.
      // Queries without this filter will fail with permission-denied errors.
      Query<Map<String, dynamic>> query = _organizationQuery(_eventsCollection)
          .where('recordId', isEqualTo: recordId)
          .where('recordModelType', isEqualTo: recordModelType.name)
          .where('snapshotData', isNull: false); // Only events with snapshots

      // Add date filters
      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: startDate.toIso8601String(),
        );
      }
      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: endDate.toIso8601String(),
        );
      }

      // Add limit
      if (limit != null) {
        query = query.limit(limit);
      }

      // Order by creation time
      query = query.orderBy('createdAt', descending: false);

      final snapshot = await query.get();
      final snapshots = <InventoryRecord>[];

      for (final doc in snapshot.docs) {
        try {
          final eventData = doc.data();
          final snapshotData =
              eventData['snapshotData'] as Map<String, dynamic>?;

          if (snapshotData != null) {
            final filtered = await _filterSnapshotPayload(snapshotData);
            final inventoryRecord = _createInventoryRecordFromSnapshot(
              filtered,
              recordModelType,
            );
            if (inventoryRecord != null) {
              snapshots.add(inventoryRecord);
            }
          }
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to parse snapshot ${doc.id}: $e',
          );
        }
      }

      return snapshots;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get snapshots for record $recordId',
        e,
      );
      rethrow;
    }
  }

  /// Get the snapshot closest to a specific point in time
  Future<InventoryRecord?> getSnapshotAtTime({
    required String recordId,
    required ModelType recordModelType,
    required DateTime pointInTime,
  }) async {
    try {
      // Get snapshots before or at the point in time
      final snapshots = await getSnapshotsForRecord(
        recordId: recordId,
        recordModelType: recordModelType,
        endDate: pointInTime,
        limit: 100, // Get recent snapshots to find the closest one
      );

      if (snapshots.isEmpty) return null;

      // Find the snapshot closest to the point in time
      InventoryRecord? closestSnapshot;
      DateTime? closestTime;

      for (final snapshot in snapshots) {
        final snapshotTime = DateTime.parse(snapshot.updatedAt);
        if (snapshotTime.isBefore(pointInTime) ||
            snapshotTime.isAtSameMomentAs(pointInTime)) {
          if (closestTime == null || snapshotTime.isAfter(closestTime)) {
            closestSnapshot = snapshot;
            closestTime = snapshotTime;
          }
        }
      }

      return closestSnapshot;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get snapshot at time for $recordId',
        e,
      );
      rethrow;
    }
  }

  /// Get snapshots for multiple records
  Future<Map<String, List<InventoryRecord>>> getSnapshotsForRecords({
    required List<String> recordIds,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final results = <String, List<InventoryRecord>>{};

      // Initialize empty lists for all records
      for (final recordId in recordIds) {
        results[recordId] = [];
      }

      // Get snapshots for all records in batches
      const batchSize = 10; // Firestore 'whereIn' limit
      for (int i = 0; i < recordIds.length; i += batchSize) {
        final batch = recordIds.skip(i).take(batchSize).toList();

        // CRITICAL: Must include organizationId filter to satisfy Firestore security rules.
        Query<Map<String, dynamic>> query = _organizationQuery(_eventsCollection)
            .where('recordId', whereIn: batch)
            .where('recordModelType', isEqualTo: recordModelType.name)
            .where('snapshotData', isNull: false);

        // Add date filters
        if (startDate != null) {
          query = query.where(
            'createdAt',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
          );
        }
        if (endDate != null) {
          query = query.where(
            'createdAt',
            isLessThanOrEqualTo: endDate.toIso8601String(),
          );
        }

        // Order by creation time
        query = query.orderBy('createdAt', descending: false);

        final snapshot = await query.get();

        for (final doc in snapshot.docs) {
          try {
            final eventData = doc.data();
            final recordId = eventData['recordId'] as String;
            final snapshotData =
                eventData['snapshotData'] as Map<String, dynamic>?;

            if (snapshotData != null) {
              final filtered = await _filterSnapshotPayload(snapshotData);
              final inventoryRecord = _createInventoryRecordFromSnapshot(
                filtered,
                recordModelType,
              );
              if (inventoryRecord != null) {
                results[recordId]?.add(inventoryRecord);
              }
            }
          } catch (e) {
            LoggingService.instance.warning(
              'Failed to parse snapshot ${doc.id}: $e',
            );
          }
        }
      }

      return results;
    } catch (e) {
      LoggingService.instance.error('Failed to get snapshots for records', e);
      rethrow;
    }
  }

  /// Get snapshot statistics for a record
  Future<SnapshotStatistics> getSnapshotStatistics({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final snapshots = await getSnapshotsForRecord(
        recordId: recordId,
        recordModelType: recordModelType,
        startDate: startDate,
        endDate: endDate,
      );

      if (snapshots.isEmpty) {
        return SnapshotStatistics(
          recordId: recordId,
          recordModelType: recordModelType,
          totalSnapshots: 0,
          firstSnapshotDate: null,
          lastSnapshotDate: null,
          averageSnapshotsPerDay: 0.0,
          startDate: startDate,
          endDate: endDate,
        );
      }

      // Calculate statistics
      final totalSnapshots = snapshots.length;
      final snapshotDates = snapshots
          .map((s) => DateTime.parse(s.updatedAt))
          .toList();
      final firstSnapshotDate = snapshotDates.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      final lastSnapshotDate = snapshotDates.reduce(
        (a, b) => a.isAfter(b) ? a : b,
      );
      final averageSnapshotsPerDay = _calculateAverageSnapshotsPerDay(
        snapshotDates,
        startDate,
        endDate,
      );

      return SnapshotStatistics(
        recordId: recordId,
        recordModelType: recordModelType,
        totalSnapshots: totalSnapshots,
        firstSnapshotDate: firstSnapshotDate,
        lastSnapshotDate: lastSnapshotDate,
        averageSnapshotsPerDay: averageSnapshotsPerDay,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get snapshot statistics for $recordId',
        e,
      );
      rethrow;
    }
  }

  /// Create a snapshot record at a specific point in time
  /// Creates a snapshot record for historical tracking.
  ///
  /// [userId] - The ID of the user creating the snapshot. Defaults to 'system'
  /// for automated/system-initiated snapshots.
  Future<SnapshotRecord> createSnapshotRecord({
    required String recordId,
    required ModelType recordModelType,
    required InventoryRecord currentRecord,
    required DateTime pointInTime,
    String? description,
    String userId = 'system',
  }) async {
    try {
      final filtered = await _filterSnapshotPayload(currentRecord.toJson());
      final now = DateTime.now().toIso8601String();
      final snapshotRecord = SnapshotRecord(
        id: _generateSnapshotId(recordId, pointInTime),
        recordId: recordId,
        recordModelType: recordModelType,
        snapshotData: filtered,
        pointInTime: pointInTime,
        description:
            description ?? 'Snapshot at ${pointInTime.toIso8601String()}',
        createdAt: now,
        createdById: userId,
        updatedAt: now,
        updatedById: userId,
        organizationId: currentRecord.organizationId,
      );

      // Store the snapshot record
      await _snapshotRecordsCollection
          .doc(snapshotRecord.id)
          .set(snapshotRecord.toJson());

      LoggingService.instance.info(
        'Created snapshot record ${snapshotRecord.id} for $recordId',
      );
      return snapshotRecord;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to create snapshot record for $recordId',
        e,
      );
      rethrow;
    }
  }

  /// Get snapshot records for a specific record
  Future<List<SnapshotRecord>> getSnapshotRecords({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      // CRITICAL: Must include organizationId filter to satisfy Firestore security rules.
      Query query = _organizationQuery(_snapshotRecordsCollection)
          .where('recordId', isEqualTo: recordId)
          .where('recordModelType', isEqualTo: recordModelType.name);

      // Order by point in time (stored as ISO-8601 string)
      query = query.orderBy('pointInTime', descending: false);

      // Add date filters using ISO-8601 strings for consistency
      if (startDate != null) {
        query = query.where(
          'pointInTime',
          isGreaterThanOrEqualTo: startDate.toIso8601String(),
        );
      }
      if (endDate != null) {
        query = query.where(
          'pointInTime',
          isLessThanOrEqualTo: endDate.toIso8601String(),
        );
      }

      // Add limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final snapshotRecords = <SnapshotRecord>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          final snapshotRecord = SnapshotRecord.fromJson(data);
          snapshotRecords.add(snapshotRecord);
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to parse snapshot record ${doc.id}: $e',
          );
        }
      }

      return snapshotRecords;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to get snapshot records for $recordId',
        e,
      );
      rethrow;
    }
  }

  /// Create an inventory record from snapshot data
  InventoryRecord? _createInventoryRecordFromSnapshot(
    Map<String, dynamic> snapshotData,
    ModelType recordModelType,
  ) {
    try {
      // Import the record factory to create appropriate record types
      // This would need to be implemented based on the existing record factory pattern
      // For now, return null as a placeholder
      return null;
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to create inventory record from snapshot: $e',
      );
      return null;
    }
  }

  /// Generate a unique snapshot ID
  String _generateSnapshotId(String recordId, DateTime pointInTime) {
    final timestamp = pointInTime.millisecondsSinceEpoch;
    return '${recordId}_snapshot_$timestamp';
  }

  /// Calculate average snapshots per day
  double _calculateAverageSnapshotsPerDay(
    List<DateTime> snapshotDates,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (snapshotDates.isEmpty) return 0.0;

    final actualStart =
        startDate ?? snapshotDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final actualEnd =
        endDate ?? snapshotDates.reduce((a, b) => a.isAfter(b) ? a : b);

    final daysDiff = actualEnd.difference(actualStart).inDays;
    if (daysDiff == 0) return snapshotDates.length.toDouble();

    return snapshotDates.length / daysDiff;
  }

  Future<Map<String, dynamic>> _filterSnapshotPayload(
    Map<String, dynamic> payload,
  ) async {
    await TieredFieldRegistry.instance.ensureInitialized();
    return TieredFieldRegistry.instance.filterFields(
      model: 'inventory_record_snapshot',
      payload: Map<String, dynamic>.from(payload),
      tier: _tier,
    );
  }
}

/// Represents a snapshot record
class SnapshotRecord {
  final String id;
  final String recordId;
  final ModelType recordModelType;
  final Map<String, dynamic> snapshotData;
  final DateTime pointInTime;
  final String description;
  final String createdAt;
  final String createdById;
  final String updatedAt;
  final String updatedById;
  final String organizationId;

  const SnapshotRecord({
    required this.id,
    required this.recordId,
    required this.recordModelType,
    required this.snapshotData,
    required this.pointInTime,
    required this.description,
    required this.createdAt,
    required this.createdById,
    required this.updatedAt,
    required this.updatedById,
    required this.organizationId,
  });

  SnapshotRecord.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      recordId = json['recordId'],
      recordModelType = ModelType.values.byName(json['recordModelType']),
      snapshotData = json['snapshotData'] as Map<String, dynamic>,
      pointInTime = DateTime.parse(json['pointInTime']),
      description = json['description'],
      createdAt = json['createdAt'],
      createdById = json['createdById'],
      updatedAt = json['updatedAt'],
      updatedById = json['updatedById'],
      organizationId = json['organizationId'];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recordId': recordId,
      'recordModelType': recordModelType.name,
      'snapshotData': snapshotData,
      'pointInTime': pointInTime.toIso8601String(),
      'description': description,
      'createdAt': createdAt,
      'createdById': createdById,
      'updatedAt': updatedAt,
      'updatedById': updatedById,
      'organizationId': organizationId,
    };
  }
}

/// Represents snapshot statistics for a record
class SnapshotStatistics {
  final String recordId;
  final ModelType recordModelType;
  final int totalSnapshots;
  final DateTime? firstSnapshotDate;
  final DateTime? lastSnapshotDate;
  final double averageSnapshotsPerDay;
  final DateTime? startDate;
  final DateTime? endDate;

  const SnapshotStatistics({
    required this.recordId,
    required this.recordModelType,
    required this.totalSnapshots,
    this.firstSnapshotDate,
    this.lastSnapshotDate,
    required this.averageSnapshotsPerDay,
    this.startDate,
    this.endDate,
  });

  /// Get a summary of the statistics
  String get summary {
    if (totalSnapshots == 0) return 'No snapshots available';

    final parts = <String>[];
    parts.add('$totalSnapshots total snapshots');

    if (averageSnapshotsPerDay > 0) {
      parts.add(
        '${averageSnapshotsPerDay.toStringAsFixed(2)} snapshots/day average',
      );
    }

    if (firstSnapshotDate != null && lastSnapshotDate != null) {
      final daysDiff = lastSnapshotDate!.difference(firstSnapshotDate!).inDays;
      if (daysDiff > 0) {
        parts.add('$daysDiff days of history');
      }
    }

    return parts.join(', ');
  }
}
