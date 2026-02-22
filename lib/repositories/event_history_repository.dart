// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for managing event histories and timeline data
class EventHistoryRepository {
  final FirebaseFirestore _firestore;
  final Organization _organization;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  EventHistoryRepository({
    required FirebaseFirestore firestore,
    required Organization organization,
  }) : _firestore = firestore,
       _organization = organization;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, ModelType.event.collectionPath);

  /// Get all events for a specific record within a date range
  ///
  /// NOTE: This method uses orderBy which requires a composite index.
  /// Requires composite index: organizationId + recordId + recordModelType + createdAt.
  /// See: firestore.indexes.json
  Future<List<Event>> getEventsForRecord({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? eventTypes,
    int? limit,
  }) async {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    final baseQuery = _collection
        .where('organizationId', isEqualTo: _organization.id)
        .where('recordId', isEqualTo: recordId)
        .where('recordModelType', isEqualTo: recordModelType.name);

    // NOTE: orderBy requires composite index - ensure index is deployed
    Query<Map<String, dynamic>> query = baseQuery;

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

    // Add event type filters
    if (eventTypes != null && eventTypes.isNotEmpty) {
      query = query.where('eventTypeId', whereIn: eventTypes);
    }

    // Add limit
    if (limit != null) {
      query = query.limit(limit);
    }

    // Order by creation time
    query = query.orderBy('createdAt', descending: false);

    try {
      final snapshot = await query.get();
      return _parseEventsFromSnapshot(snapshot);
    } on FirebaseException catch (e, stackTrace) {
      if (_isMissingIndexError(e)) {
        LoggingService.instance.warning(
          'EventHistoryRepository: Missing index for events query. '
          'Falling back to client-side filtering for record $recordId.',
        );
        return _fetchWithClientFiltering(
          baseQuery: baseQuery,
          startDate: startDate,
          endDate: endDate,
          eventTypes: eventTypes,
          limit: limit,
        );
      }
      LoggingService.instance.error(
        'Failed to get events for record $recordId',
        e,
        stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get events for record $recordId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get events for multiple records
  ///
  /// NOTE: This method uses orderBy which requires a composite index.
  /// Requires composite index: organizationId + recordId + recordModelType + createdAt.
  /// See: firestore.indexes.json
  Future<Map<String, List<Event>>> getEventsForRecords({
    required List<String> recordIds,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? eventTypes,
  }) async {
    try {
      final results = <String, List<Event>>{};

      // Initialize empty lists for all records
      for (final recordId in recordIds) {
        results[recordId] = [];
      }

      // Get events for all records in batches
      const batchSize = 10; // Firestore 'whereIn' limit
      for (int i = 0; i < recordIds.length; i += batchSize) {
        final batch = recordIds.skip(i).take(batchSize).toList();

        // CRITICAL: Must include organizationId filter to satisfy security rules
        // NOTE: orderBy requires composite index - ensure index is deployed
        Query<Map<String, dynamic>> query = _collection
            .where('organizationId', isEqualTo: _organization.id)
            .where('recordId', whereIn: batch)
            .where('recordModelType', isEqualTo: recordModelType.name);

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

        // Add event type filters
        if (eventTypes != null && eventTypes.isNotEmpty) {
          query = query.where('eventTypeId', whereIn: eventTypes);
        }

        // Order by creation time
        query = query.orderBy('createdAt', descending: false);

        final snapshot = await query.get();

        for (final doc in snapshot.docs) {
          try {
            final eventData = doc.data();
            eventData['id'] = doc.id;

            final event = _createEventFromData(eventData);
            if (event != null) {
              final recordId = event.recordId;
              results[recordId]?.add(event);
            }
          } catch (e) {
            LoggingService.instance.warning(
              'Failed to parse event ${doc.id}: $e',
            );
          }
        }
      }

      return results;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to get events for records', e, stackTrace);
      rethrow;
    }
  }

  /// Get events by type across all records
  ///
  /// NOTE: This method uses orderBy which requires a composite index.
  /// Requires composite index: organizationId + eventTypeId + createdAt.
  /// See: firestore.indexes.json
  Future<List<Event>> getEventsByType({
    required String eventTypeId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      // CRITICAL: Must include organizationId filter to satisfy security rules
      // NOTE: orderBy requires composite index - ensure index is deployed
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: _organization.id)
          .where('eventTypeId', isEqualTo: eventTypeId);

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
      final events = <Event>[];

      for (final doc in snapshot.docs) {
        try {
          final eventData = doc.data();
          eventData['id'] = doc.id;

          final event = _createEventFromData(eventData);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to parse event ${doc.id}: $e',
          );
        }
      }

      return events;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get events by type $eventTypeId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get events within a specific time range
  ///
  /// NOTE: This method uses orderBy which requires a composite index.
  /// Requires composite index: organizationId + createdAt.
  /// See: firestore.indexes.json
  Future<List<Event>> getEventsInTimeRange({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? eventTypes,
    int? limit,
  }) async {
    try {
      // CRITICAL: Must include organizationId filter to satisfy security rules
      // NOTE: orderBy requires composite index - ensure index is deployed
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: _organization.id)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
          )
          .where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String());

      // Add event type filters
      if (eventTypes != null && eventTypes.isNotEmpty) {
        query = query.where('eventTypeId', whereIn: eventTypes);
      }

      // Add limit
      if (limit != null) {
        query = query.limit(limit);
      }

      // Order by creation time
      query = query.orderBy('createdAt', descending: false);

      final snapshot = await query.get();
      final events = <Event>[];

      for (final doc in snapshot.docs) {
        try {
          final eventData = doc.data();
          eventData['id'] = doc.id;

          final event = _createEventFromData(eventData);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to parse event ${doc.id}: $e',
          );
        }
      }

      return events;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to get events in time range', e, stackTrace);
      rethrow;
    }
  }

  /// Get event statistics for a record
  Future<EventStatistics> getEventStatistics({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final events = await getEventsForRecord(
        recordId: recordId,
        recordModelType: recordModelType,
        startDate: startDate,
        endDate: endDate,
      );

      final eventTypeCounts = <String, int>{};
      final eventDates = <DateTime>[];

      for (final event in events) {
        eventTypeCounts[event.eventTypeId] =
            (eventTypeCounts[event.eventTypeId] ?? 0) + 1;
        eventDates.add(DateTime.parse(event.createdAt));
      }

      // Calculate statistics
      final totalEvents = events.length;
      final uniqueEventTypes = eventTypeCounts.keys.length;
      final firstEventDate = eventDates.isNotEmpty
          ? eventDates.reduce((a, b) => a.isBefore(b) ? a : b)
          : null;
      final lastEventDate = eventDates.isNotEmpty
          ? eventDates.reduce((a, b) => a.isAfter(b) ? a : b)
          : null;
      final averageEventsPerDay = _calculateAverageEventsPerDay(
        eventDates,
        startDate,
        endDate,
      );

      return EventStatistics(
        recordId: recordId,
        recordModelType: recordModelType,
        totalEvents: totalEvents,
        uniqueEventTypes: uniqueEventTypes,
        eventTypeCounts: eventTypeCounts,
        firstEventDate: firstEventDate,
        lastEventDate: lastEventDate,
        averageEventsPerDay: averageEventsPerDay,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get event statistics for $recordId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Create an event from Firestore data
  Event? _createEventFromData(Map<String, dynamic> data) {
    try {
      // Use RecordFactory to create events from JSON
      // This handles all event types via EventFactory
      return RecordFactory.eventFromJson(data);
    } catch (e) {
      LoggingService.instance.warning('Failed to create event from data: $e');
      return null;
    }
  }

  bool _isMissingIndexError(FirebaseException error) {
    final message = error.message?.toLowerCase() ?? '';
    return error.code == 'failed-precondition' && message.contains('index');
  }

  Future<List<Event>> _fetchWithClientFiltering({
    required Query<Map<String, dynamic>> baseQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? eventTypes,
    int? limit,
  }) async {
    final snapshot = await baseQuery.get();
    final events = _parseEventsFromSnapshot(snapshot);
    return _applyClientFilters(
      events,
      startDate: startDate,
      endDate: endDate,
      eventTypes: eventTypes,
      limit: limit,
    );
  }

  List<Event> _parseEventsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final events = <Event>[];
    for (final doc in snapshot.docs) {
      try {
        final eventData = doc.data();
        eventData['id'] = doc.id;

        final event = _createEventFromData(eventData);
        if (event != null) {
          events.add(event);
        }
      } catch (e) {
        LoggingService.instance.warning(
          'Failed to parse event ${doc.id}: $e',
        );
      }
    }
    return events;
  }

  List<Event> _applyClientFilters(
    List<Event> events, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? eventTypes,
    int? limit,
  }) {
    Iterable<Event> filtered = events;

    if (eventTypes != null && eventTypes.isNotEmpty) {
      filtered = filtered.where((event) => eventTypes.contains(event.eventTypeId));
    }

    if (startDate != null || endDate != null) {
      filtered = filtered.where((event) {
        final createdAt = _safeParseCreatedAt(event);
        if (startDate != null && createdAt.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && createdAt.isAfter(endDate)) {
          return false;
        }
        return true;
      });
    }

    final sorted = filtered.toList()
      ..sort(
        (a, b) => _safeParseCreatedAt(a).compareTo(_safeParseCreatedAt(b)),
      );

    if (limit != null && sorted.length > limit) {
      return sorted.take(limit).toList();
    }

    return sorted;
  }

  DateTime _safeParseCreatedAt(Event event) {
    try {
      return DateTime.parse(event.createdAt);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Calculate average events per day
  double _calculateAverageEventsPerDay(
    List<DateTime> eventDates,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (eventDates.isEmpty) return 0.0;

    final actualStart =
        startDate ?? eventDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final actualEnd =
        endDate ?? eventDates.reduce((a, b) => a.isAfter(b) ? a : b);

    final daysDiff = actualEnd.difference(actualStart).inDays;
    if (daysDiff == 0) return eventDates.length.toDouble();

    return eventDates.length / daysDiff;
  }
}

/// Represents event statistics for a record
class EventStatistics {
  final String recordId;
  final ModelType recordModelType;
  final int totalEvents;
  final int uniqueEventTypes;
  final Map<String, int> eventTypeCounts;
  final DateTime? firstEventDate;
  final DateTime? lastEventDate;
  final double averageEventsPerDay;
  final DateTime? startDate;
  final DateTime? endDate;

  const EventStatistics({
    required this.recordId,
    required this.recordModelType,
    required this.totalEvents,
    required this.uniqueEventTypes,
    required this.eventTypeCounts,
    this.firstEventDate,
    this.lastEventDate,
    required this.averageEventsPerDay,
    this.startDate,
    this.endDate,
  });

  /// Get the most frequent event type
  String? get mostFrequentEventType {
    if (eventTypeCounts.isEmpty) return null;

    return eventTypeCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get the count for the most frequent event type
  int get mostFrequentEventCount {
    if (eventTypeCounts.isEmpty) return 0;

    return eventTypeCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .value;
  }

  /// Get a summary of the statistics
  String get summary {
    final parts = <String>[];
    parts.add('$totalEvents total events');
    parts.add('$uniqueEventTypes event types');

    if (mostFrequentEventType != null) {
      parts.add(
        'Most frequent: $mostFrequentEventType ($mostFrequentEventCount)',
      );
    }

    if (averageEventsPerDay > 0) {
      parts.add('${averageEventsPerDay.toStringAsFixed(2)} events/day average');
    }

    return parts.join(', ');
  }
}
