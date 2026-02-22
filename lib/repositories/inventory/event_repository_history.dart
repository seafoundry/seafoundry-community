// @tier: community
part of 'event_repository.dart';

/// Cache key for streamEventsForUrlPath using type-safe Dart records.
/// Prevents cache key collisions and provides better debugging.
typedef _EventStreamCacheKey = ({
  String urlPath,
  String? recordId,
  bool shallow,
  int limit,
});

/// Cache key for streamRecentEvents based on window duration and limit.
typedef _RecentEventsCacheKey = ({
  Duration window,
  int? limit,
});

mixin _EventRepositoryHistory on _EventRepositoryBase, _EventRepositoryHelpers {
  // Stream cache to prevent duplicate Firestore subscriptions
  // Uses StreamCache with Dart records for type-safe, collision-free keys
  final _urlPathEventCache = StreamCache<_EventStreamCacheKey, List<Event>>();
  final _recentEventsCache = StreamCache<_RecentEventsCacheKey, List<Event>>();

  /// Stream recent events within a configurable time window.
  ///
  /// This is the preferred method for UI components. For full history, use
  /// [fetchHistoricalEvents] with pagination.
  @override
  Stream<List<Event>> streamRecentEvents({
    Duration window = const Duration(days: 30),
    int? limit = 10000,
  }) {
    // Cache streams by window duration and limit to prevent duplicate subscriptions
    // Note: We cache by window duration, not absolute cutoff date, since the
    // stream naturally filters events based on their createdAt timestamp
    final cacheKey = (window: window, limit: limit);

    return _recentEventsCache.getOrCreate(cacheKey, () {
      final cutoffDate = DateTime.now().subtract(window);
      final cutoffIso = cutoffDate.toUtc().toIso8601String();

      // CRITICAL: Must include organizationId filter to satisfy security rules
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      Query<Map<String, dynamic>> query = collectionRef
          .where('organizationId', isEqualTo: organization.id)
          .where('createdAt', isGreaterThanOrEqualTo: cutoffIso);

      if (limit != null) {
        query = query.limit(limit);
      }

      return _retryIndexStream(
        () => query.snapshots().map((snapshot) {
          final events = snapshot.docs
              .map(_parseEventSafe)
              .whereType<Event>()
              .toList();
          // Sort in-memory instead of using orderBy
          events.sort((a, b) {
            final dateA = DateTime.tryParse(a.createdAt) ?? DateTime(1970);
            final dateB = DateTime.tryParse(b.createdAt) ?? DateTime(1970);
            return dateB.compareTo(dateA); // descending
          });
          return events;
        }),
        debugLabel: 'streamRecentEvents(${organization.id})',
      );
    });
  }

  /// Stream events for a specific URL path using server-side range query.
  ///
  /// Uses Firestore range query on urlPath (requires no composite index beyond
  /// organizationId) to efficiently filter events. Orders by urlPath then createdAt
  /// descending to guarantee recent events are included.
  ///
  /// Replaces time-window filtering with limit-based approach to avoid missing
  /// recent events when total event count exceeds window threshold.
  @override
  Stream<List<Event>> streamEventsForUrlPath(
    String urlPath, {
    String? recordId,
    bool shallow = false,
    int limit = 100,
  }) {
    // Cache streams using type-safe Dart record key to prevent:
    // 1. Duplicate Firestore subscriptions
    // 2. Cache key collisions (record keys are type-safe and unique)
    // StreamCache handles broadcast support and lazy subscription lifecycle
    final cacheKey = (
      urlPath: urlPath,
      recordId: recordId,
      shallow: shallow,
      limit: limit,
    );
    return _urlPathEventCache.getOrCreate(cacheKey, () {
      final upperBound = _incrementLastChar(urlPath);

      // CRITICAL: Must include organizationId filter to satisfy security rules
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      Query<Map<String, dynamic>> query = collectionRef
          .where('organizationId', isEqualTo: organization.id)
          .where('urlPath', isGreaterThanOrEqualTo: urlPath)
          .where('urlPath', isLessThan: upperBound)
          .limit(limit);

      return _retryIndexStream(
        () => query.snapshots().map((snapshot) {
        var events = snapshot.docs
            .map(_parseEventSafe)
            .whereType<Event>()
            .toList();

        // Apply recordId filter client-side if specified
        if (recordId != null) {
          events = events.where((event) => event.recordId == recordId).toList();
        }

        // Apply shallow filter client-side (exclude nested children)
        if (shallow) {
          events = events.where((event) {
            if (event.urlPath == urlPath) return true;
            final remainder = event.urlPath.substring(urlPath.length);
            return !(remainder.startsWith('/') &&
                remainder.substring(1).contains('/'));
          }).toList();
        }

        // Sort by createdAt descending (in-memory instead of orderBy)
        events.sort((a, b) {
          DateTime dateA =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          DateTime dateB =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);

          // For completed tasks, use completion date for sorting
          if (a is TaskEvent && a.completedAt != null) {
            dateA = a.completedAt!;
          }
          if (b is TaskEvent && b.completedAt != null) {
            dateB = b.completedAt!;
          }

          return dateB.compareTo(dateA);
        });

        return events;
        }),
        debugLabel: 'streamEventsForUrlPath($urlPath)',
      );
    });
  }

  /// Paginated access to historical events beyond the default window.
  ///
  /// NOTE: This method uses orderBy for cursor-based pagination (startAfter).
  /// Requires composite index: organizationId + createdAt (descending).
  /// See: firestore.indexes.json
  @override
  Future<List<Event>> fetchHistoricalEvents({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
    DocumentSnapshot? startAfter,
  }) async {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // NOTE: orderBy required for cursor-based pagination - ensure index is deployed
    Query<Map<String, dynamic>> query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: startDate.toUtc().toIso8601String(),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: endDate.toUtc().toIso8601String(),
        )
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final events = <Event>[];
    for (final doc in snapshot.docs) {
      try {
        events.add(RecordFactory.eventFromJson(_injectDocId(doc)));
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to parse historical event',
          e,
          stackTrace,
        );
      }
    }
    return events;
  }

  /// Fetch historical events for a specific URL path with pagination support.
  ///
  /// Uses urlPath range query with optional date filtering and pagination cursor.
  /// Returns PaginatedEvents with cursor for fetching next page.
  ///
  /// NOTE: This method uses orderBy for cursor-based pagination (startAfter).
  /// Requires composite index: organizationId + urlPath + createdAt (descending).
  /// See: firestore.indexes.json
  @override
  Future<PaginatedEvents> fetchHistoricalEventsForUrlPath({
    required String urlPath,
    String? recordId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    DocumentSnapshot? startAfter,
  }) async {
    if (_isOrganizationRootPath(urlPath)) {
      return _fetchHistoricalEventsForOrganization(
        recordId: recordId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        startAfter: startAfter,
      );
    }

    final upperBound = _incrementLastChar(urlPath);

    // CRITICAL: Must include organizationId filter to satisfy security rules
    // NOTE: orderBy required for cursor-based pagination - ensure index is deployed
    Query<Map<String, dynamic>> query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('urlPath', isGreaterThanOrEqualTo: urlPath)
        .where('urlPath', isLessThan: upperBound)
        .orderBy('urlPath')
        .orderBy('createdAt', descending: true);

    // Add optional date filtering
    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: startDate.toUtc().toIso8601String(),
      );
    }
    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: endDate.toUtc().toIso8601String(),
      );
    }

    return _executePaginatedQuery(
      query: query,
      limit: limit,
      startAfter: startAfter,
      recordId: recordId,
      debugLabel: 'fetchHistoricalEventsForUrlPath',
    );
  }

  bool _isOrganizationRootPath(String urlPath) =>
      urlPath == organization.urlPath ||
      urlPath == organization.domain ||
      urlPath == organization.slug ||
      urlPath == organization.id;

  Future<PaginatedEvents> _fetchHistoricalEventsForOrganization({
    String? recordId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    DocumentSnapshot? startAfter,
  }) async {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // NOTE: orderBy required for cursor-based pagination - ensure index is deployed
    Query<Map<String, dynamic>> query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .orderBy('createdAt', descending: true);

    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: startDate.toUtc().toIso8601String(),
      );
    }
    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: endDate.toUtc().toIso8601String(),
      );
    }

    return _executePaginatedQuery(
      query: query,
      limit: limit,
      startAfter: startAfter,
      recordId: recordId,
      debugLabel: 'fetchHistoricalEventsForOrganization',
    );
  }

  /// Executes a paginated Firestore query and returns parsed events.
  ///
  /// This helper handles the common pagination pattern:
  /// - Fetches limit + 1 documents to determine if more results exist
  /// - Parses documents into Event objects with error handling
  /// - Tracks the last QUERIED document for cursor-based pagination
  /// - Optionally filters by recordId client-side
  ///
  /// CRITICAL: The cursor tracks the last queried document position, NOT the
  /// last successfully processed event. This ensures pagination always advances
  /// through the raw Firestore result set, even when:
  /// - Documents fail to parse (exception thrown)
  /// - Documents are filtered out by the recordId filter
  /// Without this, filtered/failed documents would cause pagination to skip
  /// events or loop infinitely on the same page.
  Future<PaginatedEvents> _executePaginatedQuery({
    required Query<Map<String, dynamic>> query,
    required int limit,
    DocumentSnapshot? startAfter,
    String? recordId,
    required String debugLabel,
  }) async {
    // Apply pagination cursor
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Fetch limit + 1 to determine if more results exist
    query = query.limit(limit + 1);

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final events = <Event>[];

    // Track the last QUERIED doc, not the last successfully processed doc.
    // This ensures pagination always advances by the raw query cursor,
    // regardless of parse failures or client-side filtering.
    //
    // We use the limit-th doc (index limit-1) as the cursor, or the last doc
    // if fewer than limit docs were returned. This positions the cursor at
    // the boundary of what we've processed from the query.
    final lastQueriedDoc = docs.length > limit
        ? docs[limit - 1]
        : (docs.isNotEmpty ? docs.last : null);

    // Process up to `limit` documents (not limit+1 - that's just for hasMore)
    for (var i = 0; i < docs.length && i < limit; i++) {
      try {
        final event = RecordFactory.eventFromJson(_injectDocId(docs[i]));

        // Apply recordId filter client-side if specified
        if (recordId != null && event.recordId != recordId) continue;

        events.add(event);
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to parse historical event ($debugLabel)',
          e,
          stackTrace,
        );
      }
    }

    final hasMore = docs.length > limit;

    return PaginatedEvents(
      events: events,
      lastDocument: lastQueriedDoc,
      hasMore: hasMore,
    );
  }
}
