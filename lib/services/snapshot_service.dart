// @tier: community
import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/services/tiered_field_registry.dart';

/// Service for managing record snapshots before and after events
///
/// **Purpose**: Captures point-in-time state of records for audit trails and
/// efficient state reconstruction. Snapshots enable fast historical queries without
/// replaying entire event histories.
///
/// **Design Decisions**:
/// - **Before/After pattern**: Captures state both before and after modifications
///   to enable delta calculations and rollback capabilities.
/// - **Pre-computation intervals**: Pre-computes snapshots at common intervals
///   (7, 30, 90, 180, 365 days) to accelerate StateReconstructionService queries.
/// - **In-memory cache**: Maintains snapshot cache in memory to avoid repeated
///   Firestore queries for frequently accessed snapshots.
/// - **Firestore persistence**: All snapshots persisted to Firestore for durability
///   and cross-device consistency.
///
/// **Performance Considerations**:
/// - Pre-computation happens asynchronously and should not block user operations
/// - Cache grows with organization activity - monitor memory usage
/// - Snapshot creation adds write overhead to event processing - batch when possible
///
/// **Usage**: Used by StateReconstructionService for fast historical queries,
/// and by analytics services that need before/after comparisons of record changes.
class SnapshotService {
  final FirebaseFirestore _firestore;
  final LoggingService _logger = LoggingService.instance;
  Tier _tier;
  static final _timestampOverrideKey = Object();

  // Cache for pre-computed snapshots
  final Map<String, LinkedHashMap<DateTime, InventorySnapshot>> _snapshotCache =
      {};

  // Common time intervals for pre-computation
  static const List<Duration> preComputedIntervals = [
    Duration(days: 7), // 1 week
    Duration(days: 30), // 30 days
    Duration(days: 90), // 90 days
    Duration(days: 180), // 6 months
    Duration(days: 365), // 1 year
  ];

  SnapshotService({
    required FirebaseFirestore firestore,
    Tier tier = Tier.scale,
  }) : _firestore = firestore,
       _tier = tier;

  void updateTier(Tier tier) {
    _tier = tier;
  }

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

      await FirestoreCollectionResolver.instance
          .collection(_firestore, 'snapshots')
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

      await FirestoreCollectionResolver.instance
          .collection(_firestore, 'snapshots')
          .doc(snapshot.id)
          .set(snapshot.toJson());

      _logger.info('Created after snapshot for ${record.id}');
      return snapshot;
    } catch (e) {
      _logger.error('Failed to create after snapshot', e);
      rethrow;
    }
  }

  /// Gets all snapshots for a record within a date range
  Future<List<RecordSnapshot>> getSnapshotsForRecord({
    required String recordId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = FirestoreCollectionResolver.instance
          .collection(_firestore, 'snapshots')
          .where('recordId', isEqualTo: recordId);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final querySnapshot = await query.orderBy('timestamp').get();

      final records = await Future.wait(
        querySnapshot.docs.map((doc) => _recordFromDoc(doc.data())),
      );

      return records;
    } catch (e) {
      _logger.error('Failed to get snapshots for record $recordId', e);
      return [];
    }
  }

  /// Retrieves the most recent inventory snapshot on or before [targetDate]
  Future<InventorySnapshot?> getNearestInventorySnapshot({
    required String organizationId,
    required DateTime targetDate,
  }) async {
    try {
      final querySnapshot = await FirestoreCollectionResolver.instance
          .collection(_firestore, 'inventory_snapshots')
          .where('organizationId', isEqualTo: organizationId)
          .where('timestamp', isLessThanOrEqualTo: targetDate.toIso8601String())
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return InventorySnapshot.fromJson(querySnapshot.docs.first.data());
    } catch (e) {
      _logger.warning(
        'Failed to fetch nearest inventory snapshot for $organizationId',
        e,
      );
      return null;
    }
  }

  /// Pre-computes inventory snapshots at common intervals
  Future<void> preComputeInventorySnapshots({
    required String organizationId,
    required DateTime upToDate,
    bool forceRecompute = true,
  }) async {
    try {
      for (final interval in preComputedIntervals) {
        final snapshotDate = upToDate.subtract(interval);
        await _computeInventorySnapshot(
          organizationId: organizationId,
          targetDate: snapshotDate,
          forceRecompute: forceRecompute,
        );
      }
    } catch (e) {
      _logger.error('Failed to pre-compute inventory snapshots', e);
    }
  }

  /// Computes an inventory snapshot for a specific date
  Future<InventorySnapshot> _computeInventorySnapshot({
    required String organizationId,
    required DateTime targetDate,
    bool forceRecompute = true,
  }) async {
    try {
      // Check cache first
      final cacheKey = '$organizationId-${targetDate.toIso8601String()}';
      final cached = _snapshotCache[organizationId]?[targetDate];
      if (cached != null && !forceRecompute) {
        // Move to end to mark as recently used
        _snapshotCache[organizationId]?.remove(targetDate);
        _snapshotCache[organizationId]?[targetDate] = cached;
        return cached;
      }

      // Stream events in pages to avoid Firestore limits
      final inventoryState = <String, Map<String, dynamic>>{};
      await for (final eventData in _streamEvents(
        organizationId: organizationId,
        targetDate: targetDate,
      )) {
        await _applyEventToState(eventData, inventoryState);
      }

      // Determine versioning: increment if existing snapshot exists
      final existingDoc = await FirestoreCollectionResolver.instance
          .collection(_firestore, 'inventory_snapshots')
          .doc(cacheKey)
          .get();
      final existingData = existingDoc.data();
      final existingSnapshot = existingDoc.exists && existingData != null
          ? InventorySnapshot.fromJson(Map<String, dynamic>.from(existingData))
          : null;
      final newVersion = (existingSnapshot?.version ?? 0) + 1;

      final snapshot = InventorySnapshot(
        id: cacheKey,
        organizationId: organizationId,
        timestamp: targetDate,
        totalOrganisms: _countOrganisms(inventoryState),
        organismsBySpecies: _groupOrganismsBySpecies(inventoryState),
        organismsBySite: _groupOrganismsBySite(inventoryState),
        healthDistribution: _calculateHealthDistribution(inventoryState),
        sizeDistribution: _calculateSizeDistribution(inventoryState),
        recordSnapshots: Map<String, Map<String, dynamic>>.from(inventoryState),
        version: newVersion,
        computedAt: _currentTimestamp(),
      );

      // Cache the result
      _snapshotCache.putIfAbsent(
        organizationId,
        () => LinkedHashMap<DateTime, InventorySnapshot>(),
      );
      _snapshotCache[organizationId]![targetDate] = snapshot;
      _evictSnapshotCacheIfNeeded(organizationId);

      // Persist to Firestore for long-term storage
      await FirestoreCollectionResolver.instance
          .collection(_firestore, 'inventory_snapshots')
          .doc(snapshot.id)
          .set(snapshot.toJson());

      return snapshot;
    } catch (e) {
      _logger.error('Failed to compute inventory snapshot', e);
      rethrow;
    }
  }

  /// Applies an event to the inventory state
  Future<void> _applyEventToState(
    Map<String, dynamic> eventData,
    Map<String, Map<String, dynamic>> inventoryState,
  ) async {
    final eventType = eventData['eventTypeId'] as String;
    final recordId = eventData['recordId'] as String;

    // Event type IDs - using string literals to match constants:
    // EventType.create.id = 'event_create'
    // InventoryEventType.populationLossId = 'event_population_loss'
    // EventType.outplant.id = 'outplant_event'
    // EventType.observation.id = 'event_observation'
    switch (eventType) {
      case 'event_create':
        // Add new record to state
        final snapshot = eventData['snapshotData'] as Map<String, dynamic>?;
        if (snapshot != null) {
          final filtered = await _filterSnapshotPayload(snapshot);
          inventoryState[recordId] = _normalizeRecord(filtered);
        }
        break;

      case 'event_population_loss':
        // Update quantity for population loss events
        if (inventoryState.containsKey(recordId)) {
          // Support both old field name (quantityLost) and new structure (oldPopulation/newPopulation)
          final oldPopulation = safeInt(eventData['oldPopulation']);
          final newPopulation = safeInt(eventData['newPopulation']);
          final quantityLost = oldPopulation != null && newPopulation != null
              ? oldPopulation - newPopulation
              : safeInt(eventData['quantityLost']) ?? 0;

          final currentQuantity = _extractQuantity(inventoryState[recordId]!);
          inventoryState[recordId]!['quantity'] =
              currentQuantity - quantityLost;

          // Remove if quantity reaches 0
          if ((safeInt(inventoryState[recordId]!['quantity']) ?? 0) <= 0) {
            inventoryState.remove(recordId);
          }
        }
        break;

      case 'outplant_event':
        // Handle outplanting
        final allocations = eventData['allocations'] as List<dynamic>? ?? [];
        for (final allocation in allocations) {
          final organismId =
              allocation['organismId'] as String? ??
              allocation['coralId'] as String?;
          final quantity = safeInt(allocation['quantity']) ?? 0;

          if (organismId == null || organismId.isEmpty) {
            continue;
          }

          if (inventoryState.containsKey(organismId)) {
            final currentQuantity =
                _extractQuantity(inventoryState[organismId]!);
            inventoryState[organismId]!['quantity'] =
                currentQuantity - quantity;

            if ((safeInt(inventoryState[organismId]!['quantity']) ?? 0) <= 0) {
              inventoryState.remove(organismId);
            }
          }
        }
        break;

      case 'event_observation':
        // Update health status
        if (inventoryState.containsKey(recordId)) {
          final newHealthStatus = eventData['newHealthStatus'] as String?;
          if (newHealthStatus != null) {
            inventoryState[recordId]!['healthStatus'] = newHealthStatus;
          }
        }
        break;

      // Add more event types as needed
    }
  }

  Future<Map<String, dynamic>> _filterSnapshotPayload(
    Map<String, dynamic> payload,
  ) async {
    await TieredFieldRegistry.instance.ensureInitialized();
    return TieredFieldRegistry.instance.filterFields(
      model: 'inventory_record_snapshot',
      payload: _hoistMetadataFields(payload),
      tier: _tier,
    );
  }

  Future<RecordSnapshot> _recordFromDoc(Map<String, dynamic> data) async {
    final snapshot = RecordSnapshot.fromJson(data);
    final filtered = await _filterSnapshotPayload(snapshot.data);
    return snapshot.copyWith(data: filtered);
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

  // Helper methods for calculating metrics
  int _countOrganisms(Map<String, Map<String, dynamic>> state) {
    return state.values
        .where(_isOrganismRecord)
        .fold(0, (total, record) => total + _extractQuantity(record));
  }

  Map<String, int> _groupOrganismsBySpecies(
    Map<String, Map<String, dynamic>> state,
  ) {
    final result = <String, int>{};
    for (final record in state.values) {
      if (_isOrganismRecord(record)) {
        final species = record['speciesId'] as String? ?? 'unknown';
        final quantity = _extractQuantity(record);
        result[species] = (result[species] ?? 0) + quantity;
      }
    }
    return result;
  }

  Map<String, int> _groupOrganismsBySite(
    Map<String, Map<String, dynamic>> state,
  ) {
    final result = <String, int>{};
    for (final record in state.values) {
      if (_isOrganismRecord(record)) {
        final urlPath = record['urlPath'] as String? ?? '';
        final sitePart = urlPath
            .split('/')
            .firstWhere(
              (part) => part.startsWith('site'),
              orElse: () => 'unknown',
            );
        final quantity = _extractQuantity(record);
        result[sitePart] = (result[sitePart] ?? 0) + quantity;
      }
    }
    return result;
  }

  Map<String, int> _calculateHealthDistribution(
    Map<String, Map<String, dynamic>> state,
  ) {
    final result = <String, int>{};
    for (final record in state.values) {
      if (_isOrganismRecord(record)) {
        final health = record['healthStatus'] as String? ?? 'unknown';
        final quantity = _extractQuantity(record);
        result[health] = (result[health] ?? 0) + quantity;
      }
    }
    return result;
  }

  Map<String, int> _calculateSizeDistribution(
    Map<String, Map<String, dynamic>> state,
  ) {
    final result = <String, int>{};
    for (final record in state.values) {
      if (_isOrganismRecord(record)) {
        final size = record['size'] as String? ?? 'unknown';
        final quantity = _extractQuantity(record);
        result[size] = (result[size] ?? 0) + quantity;
      }
    }
    return result;
  }

  /// Paginates event loading to avoid Firestore 1MB/10k limits.
  Stream<Map<String, dynamic>> _streamEvents({
    required String organizationId,
    required DateTime targetDate,
    int pageSize = 10000,
  }) async* {
    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      Query<Map<String, dynamic>> query = FirestoreCollectionResolver.instance
          .collection(_firestore, 'events')
          .where('organizationId', isEqualTo: organizationId)
          .where('createdAt', isLessThanOrEqualTo: targetDate.toIso8601String())
          .orderBy('createdAt')
          .limit(pageSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;

      for (final doc in snapshot.docs) {
        yield doc.data();
      }

      lastDoc = snapshot.docs.last;
    }
  }

  void _evictSnapshotCacheIfNeeded(String organizationId) {
    const maxEntriesPerOrg = 50;
    final cache = _snapshotCache[organizationId];
    if (cache == null) return;
    while (cache.length > maxEntriesPerOrg) {
      cache.remove(cache.keys.first);
    }
  }

  /// Clears all cached snapshots.
  ///
  /// Called during logout to prevent organization-specific data from persisting
  /// across user sessions. This is a security measure to ensure cached inventory
  /// snapshots don't leak between organizations.
  void clearCache() {
    _snapshotCache.clear();
    _logger.info('SnapshotService: cleared all cached snapshots');
  }

  bool _isOrganismRecord(Map<String, dynamic> record) {
    final modelType = record['modelType']?.toString();
    return modelType == 'coral' || modelType == 'organismRecord';
  }

  int _extractQuantity(Map<String, dynamic> record) {
    final quantity = record['quantity'];
    if (quantity is num) {
      return quantity.round();
    }

    final measurement = record['measurement'];
    if (measurement is Map<String, dynamic>) {
      final value = measurement['value'];
      if (value is num) {
        return value.round();
      }
    }

    final populationMeasurement = record['populationMeasurement'];
    if (populationMeasurement is Map<String, dynamic>) {
      final value = populationMeasurement['value'];
      if (value is num) {
        return value.round();
      }
    }

    final measurementValue = record['measurementValue'];
    if (measurementValue is num) {
      return measurementValue.round();
    }

    return 0;
  }

  Map<String, dynamic> _normalizeRecord(Map<String, dynamic> snapshot) {
    final normalized = Map<String, dynamic>.from(snapshot);
    normalized['quantity'] = _extractQuantity(snapshot);
    normalized['modelType'] =
        snapshot['modelType'] ??
        snapshot['recordModelType'] ??
        'organismRecord';
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

/// Represents an inventory-wide snapshot at a point in time
class InventorySnapshot {
  final String id;
  final String organizationId;
  final DateTime timestamp;
  final DateTime computedAt;
  final int version;
  final int totalOrganisms;
  final Map<String, int> organismsBySpecies;
  final Map<String, int> organismsBySite;
  final Map<String, int> healthDistribution;
  final Map<String, int> sizeDistribution;
  final Map<String, Map<String, dynamic>> recordSnapshots;

  InventorySnapshot({
    required this.id,
    required this.organizationId,
    required this.timestamp,
    DateTime? computedAt,
    this.version = 1,
    required this.totalOrganisms,
    required this.organismsBySpecies,
    required this.organismsBySite,
    required this.healthDistribution,
    required this.sizeDistribution,
    this.recordSnapshots = const {},
  }) : computedAt = computedAt ?? DateTime.now().toUtc();

  factory InventorySnapshot.fromJson(Map<String, dynamic> json) {
    return InventorySnapshot(
      id: json['id'],
      organizationId: json['organizationId'],
      timestamp: DateTime.parse(json['timestamp']),
      computedAt: json['computedAt'] != null
          ? DateTime.parse(json['computedAt'])
          : DateTime.now().toUtc(),
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ?? 1,
      totalOrganisms: safeInt(json['totalOrganisms']) ?? 0,
      organismsBySpecies: safeIntMap(json['organismsBySpecies']),
      organismsBySite: safeIntMap(json['organismsBySite']),
      healthDistribution: safeIntMap(json['healthDistribution']),
      sizeDistribution: safeIntMap(json['sizeDistribution']),
      recordSnapshots:
          (json['recordSnapshots'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              Map<String, dynamic>.from(value as Map<String, dynamic>),
            ),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'timestamp': timestamp.toIso8601String(),
      'computedAt': computedAt.toIso8601String(),
      'version': version,
      'totalOrganisms': totalOrganisms,
      'organismsBySpecies': organismsBySpecies,
      'organismsBySite': organismsBySite,
      'healthDistribution': healthDistribution,
      'sizeDistribution': sizeDistribution,
      if (recordSnapshots.isNotEmpty) 'recordSnapshots': recordSnapshots,
    };
  }
}

enum SnapshotType { before, after }
