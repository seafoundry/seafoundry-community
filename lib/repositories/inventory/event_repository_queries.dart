// @tier: community
part of 'event_repository.dart';

mixin _EventRepositoryQueries on _EventRepositoryBase, _EventRepositoryHelpers {
  // Stream cache to prevent duplicate Firestore subscriptions
  // StreamCache handles broadcast support and lazy subscription lifecycle
  final _organismRecordEventCache = StreamCache<String, List<Event>>();

  @override
  Future<List<PropagationReadyStatus>> getPropagationReadyEvents({
    required String genetId,
    required String siteUrlPath,
  }) async {
    final allEvents = await getRecordsForUrlPath(siteUrlPath);
    return allEvents
        .whereType<PropagationReadyStatus>()
        .where((event) => event.concludedAt == null && event.genetId == genetId)
        .toList();
  }

  @override
  Future<List<OutplantEvent>> fetchOutplantEvents({
    DateTime? start,
    DateTime? end,
    String? siteId,
    int? limit,
  }) async {
    try {
      // Always use organizationQuery to enforce organizationId filtering.
      // Firestore allows range filters on a single field, so keep createdAt ranges here.
      Query<Map<String, dynamic>> query = organizationQuery(collectionRef)
          .where('eventTypeId', isEqualTo: EventType.outplant.id)
          .orderBy('createdAt');

      if (siteId != null && siteId.isNotEmpty) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      if (start != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: start.toIso8601String(),
        );
      }
      if (end != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: end.toIso8601String(),
        );
      }

      // Apply limit when no date range is specified
      if (start == null && end == null) {
        query = query.limit(limit ?? 1000);
      }

      final snapshot = await query.get();
      final results = <OutplantEvent>[];
      for (final doc in snapshot.docs) {
        try {
          final event = RecordFactory.eventFromJson(_injectDocId(doc));
          if (event is OutplantEvent) {
            results.add(event);
          }
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse outplant event ${doc.id}',
            e,
            stackTrace,
          );
        }
      }
      return results;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Outplant event fetch failed',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<T>> fetchEventsByType<T extends Event>({
    required String eventTypeId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    try {
      // Always use organizationQuery to enforce organizationId filtering.
      Query<Map<String, dynamic>> query = organizationQuery(collectionRef)
          .where('eventTypeId', isEqualTo: eventTypeId)
          .orderBy('createdAt', descending: true);

      if (start != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: start.toIso8601String(),
        );
      }
      if (end != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: end.toIso8601String(),
        );
      }

      // Apply default limit when no date range is specified
      if (start == null && end == null && limit == null) {
        query = query.limit(1000);
      }
      // Apply custom limit if provided
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final results = <T>[];
      for (final doc in snapshot.docs) {
        try {
          final event = RecordFactory.eventFromJson(_injectDocId(doc));
          if (event is T) {
            results.add(event);
          }
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse event ${doc.id} of type $eventTypeId',
            error,
            stackTrace,
          );
        }
      }
      return results;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'fetchEventsByType($eventTypeId) failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Stream<List<OutplantEvent>> streamOutplantEvents({
    String? siteId,
    int limit = 50,
  }) {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    Query<Map<String, dynamic>> query =
        (collectionQuery(collectionRef) as Query<Map<String, dynamic>>).where(
          'eventTypeId',
          isEqualTo: EventType.outplant.id,
        );

    if (siteId != null) {
      query = query.where('siteId', isEqualTo: siteId);
    }

    if (limit > 0) {
      query = query.limit(limit);
    }

    return _guardStream(
      query.snapshots().map((snapshot) {
        final events = <OutplantEvent>[];
        for (final doc in snapshot.docs) {
          try {
            final event = RecordFactory.eventFromJson(_injectDocId(doc));
            if (event is OutplantEvent) {
              events.add(event);
            }
          } catch (e, stackTrace) {
            LoggingService.instance.error(
              'Failed to parse outplant event ${doc.id}',
              e,
              stackTrace,
            );
          }
        }
        // Sort in-memory by createdAt descending (newest first)
        events.sort((a, b) {
          final dateA =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        return events;
      }),
      debugLabel: 'streamOutplantEvents(siteId: $siteId)',
    );
  }

  @override
  Future<List<MonitoringEventRecord>> fetchMonitoringEvents({
    DateTime? start,
    DateTime? end,
    String? siteId,
    bool attachOutplantGeometry = false,
  }) async {
    try {
      var query =
          (collectionQuery(collectionRef) as Query<Map<String, dynamic>>).where(
            'eventTypeId',
            isEqualTo: EventType.observation.id,
          );

      final filterByMonitoringDate = start != null || end != null;
      if (filterByMonitoringDate) {
        query = query.orderBy('monitoringDate', descending: true);
      }
      query = query.orderBy('createdAt', descending: true);

      // Filter by monitoring date if available, otherwise use createdAt
      if (start != null) {
        final startIso = start.toIso8601String();
        query = query.where('monitoringDate', isGreaterThanOrEqualTo: startIso);
      }
      if (end != null) {
        final endIso = end.toIso8601String();
        query = query.where('monitoringDate', isLessThanOrEqualTo: endIso);
      }

      // Filter by site if provided
      if (siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      final snapshot = await query.get();
      final results = <MonitoringEventRecord>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        try {
          // Only include records that have monitoring data
          if (data['monitoringDate'] != null ||
              data['organismIds'] != null ||
              data['coralIds'] != null) {
            final event = RecordFactory.eventFromJson(_injectDocId(doc));
            if (event is MonitoringEventRecord) {
              results.add(event);
            }
          }
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse monitoring event ${doc.id}',
            e,
            stackTrace,
          );
        }
      }
      if (!attachOutplantGeometry) {
        return results;
      }

      return _attachOutplantGeometry(results);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Monitoring event fetch failed',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<List<MonitoringEventRecord>> _attachOutplantGeometry(
    List<MonitoringEventRecord> monitoringEvents,
  ) async {
    final missingGeometryIds = monitoringEvents
        .where(
          (event) =>
              event.outplantGeometry == null && event.outplantEventId != null,
        )
        .map((event) => event.outplantEventId!)
        .toSet();

    if (missingGeometryIds.isEmpty) {
      return monitoringEvents;
    }

    final geometryByOutplantId = <String, OutplantGeometry>{};
    const chunkSize = 10;
    final idList = missingGeometryIds.toList(growable: false);

    for (var index = 0; index < idList.length; index += chunkSize) {
      final chunk = idList.sublist(
        index,
        index + chunkSize > idList.length ? idList.length : index + chunkSize,
      );
      try {
          final snapshot = await organizationQuery(collectionRef)
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
        for (final doc in snapshot.docs) {
          try {
            final event = RecordFactory.eventFromJson(_injectDocId(doc));
            if (event is OutplantEvent && event.geometry != null) {
              geometryByOutplantId[event.id] = event.geometry!;
            }
          } catch (error, stackTrace) {
            LoggingService.instance.error(
              'Failed to parse outplant event ${doc.id} for monitoring geometry',
              error,
              stackTrace,
            );
          }
        }
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to fetch outplant geometry chunk',
          error,
          stackTrace,
        );
      }
    }

    if (geometryByOutplantId.isEmpty) {
      return monitoringEvents;
    }

    return monitoringEvents
        .map(
          (event) =>
              event.outplantGeometry != null || event.outplantEventId == null
              ? event
              : geometryByOutplantId.containsKey(event.outplantEventId!)
              ? event.copyWith(
                  outplantGeometry:
                      geometryByOutplantId[event.outplantEventId!],
                )
              : event,
        )
        .toList(growable: false);
  }

  @override
  Future<List<ObservationEvent>> fetchObservationEvents({
    String? recordId,
    ModelType? recordModelType,
    String? healthIssueTypeId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    try {
      // collectionQuery already adds orderBy('createdAt', descending: true)
      var query =
          (collectionQuery(collectionRef) as Query<Map<String, dynamic>>).where(
            'eventTypeId',
            isEqualTo: EventType.observation.id,
          );

      if (recordId != null) {
        query = query.where('recordId', isEqualTo: recordId);
      }

      if (recordModelType != null) {
        query = query.where('recordModelType', isEqualTo: recordModelType.name);
      }

      if (healthIssueTypeId != null) {
        query = query.where('healthIssueTypeId', isEqualTo: healthIssueTypeId);
      }

      if (start != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: start.toIso8601String(),
        );
      }

      if (end != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: end.toIso8601String(),
        );
      }

      // Apply limit when no recordId or date range is specified
      if (recordId == null && start == null && end == null) {
        query = query.limit(limit ?? 1000);
      } else if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final results = <ObservationEvent>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        try {
          // Exclude records that have monitoring data (those are MonitoringEventRecords)
          if (data['monitoringDate'] == null &&
              data['organismIds'] == null &&
              data['coralIds'] == null) {
            final event = RecordFactory.eventFromJson(_injectDocId(doc));
            if (event is ObservationEvent) {
              results.add(event);
            }
          }
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse observation event ${doc.id}',
            e,
            stackTrace,
          );
        }
      }
      return results;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Observation event fetch failed',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Stream<List<Event>> watchOrganismRecordEvents({
    required String recordId,
    int limit = 100,
  }) {
    // Cache streams by recordId to prevent duplicate Firestore subscriptions
    // StreamCache handles broadcast support and lazy subscription lifecycle
    return _organismRecordEventCache.getOrCreate(recordId, () {
      // CRITICAL: Must include organizationId filter to satisfy security rules
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      final query =
          (collectionQuery(collectionRef) as Query<Map<String, dynamic>>)
              .where('recordModelType', isEqualTo: ModelType.organismRecord.name)
              .where('recordId', isEqualTo: recordId)
              .limit(limit);
      return _guardStream(
        query.snapshots().map((snapshot) {
          final events = <Event>[];
          for (final doc in snapshot.docs) {
            try {
              events.add(RecordFactory.eventFromJson(_injectDocId(doc)));
            } catch (error, stackTrace) {
              LoggingService.instance.error(
                'Failed to parse organism record event ${doc.id}',
                error,
                stackTrace,
              );
            }
          }
          // Sort in-memory by createdAt descending (newest first)
          events.sort((a, b) {
            final dateA =
                DateTime.tryParse(a.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final dateB =
                DateTime.tryParse(b.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          return events;
        }),
        debugLabel: 'watchOrganismRecordEvents(recordId: $recordId)',
      );
    });
  }

  /// Fetch events created by a specific user.
  ///
  /// Returns a list of events where [createdById] matches the given [userId].
  /// Results are ordered by creation date (newest first) and limited to [limit].
  @override
  Future<List<Event>> getEventsForUser({
    required String userId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = organizationQuery(collectionRef)
          .where('createdById', isEqualTo: userId)
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

      query = query.limit(limit);

      final snapshot = await query.get();
      final events = <Event>[];
      for (final doc in snapshot.docs) {
        try {
          events.add(RecordFactory.eventFromJson(_injectDocId(doc)));
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse event ${doc.id} for user $userId',
            error,
            stackTrace,
          );
        }
      }
      return events;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to fetch events for user $userId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Fetch events created by a specific user with pagination support.
  ///
  /// Returns a page of events ordered by creation date (newest first).
  @override
  Future<PaginatedEvents> getEventsForUserPage({
    required String userId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = organizationQuery(collectionRef)
          .where('createdById', isEqualTo: userId)
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

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit + 1);

      final snapshot = await query.get();
      final docs = snapshot.docs;
      final events = <Event>[];
      DocumentSnapshot? lastProcessedDoc;

      for (var i = 0; i < docs.length && i < limit; i++) {
        lastProcessedDoc = docs[i];
        try {
          events.add(RecordFactory.eventFromJson(_injectDocId(docs[i])));
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse event ${docs[i].id} for user $userId',
            error,
            stackTrace,
          );
        }
      }

      final hasMore = docs.length > limit;

      return PaginatedEvents(
        events: events,
        lastDocument: lastProcessedDoc,
        hasMore: hasMore,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to fetch paginated events for user $userId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Count events created by a specific user.
  ///
  /// Returns the total count of events where [createdById] matches [userId].
  @override
  Future<int> countEventsForUser({required String userId}) async {
    try {
      final snapshot = await organizationQuery(collectionRef)
          .where('createdById', isEqualTo: userId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to count events for user $userId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Count events for the organization with optional filters.
  ///
  /// Supports filtering by event type, completion status, priority, and
  /// createdAt time window. When using a time window, the query orders by
  /// createdAt to satisfy Firestore range query requirements.
  Future<int> countEvents({
    String? eventTypeId,
    bool? isCompleted,
    String? priorityId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = organizationQuery(collectionRef);

      if (eventTypeId != null) {
        query = query.where('eventTypeId', isEqualTo: eventTypeId);
      }
      if (isCompleted != null) {
        query = query.where('isCompleted', isEqualTo: isCompleted);
      }
      if (priorityId != null) {
        query = query.where('priorityId', isEqualTo: priorityId);
      }

      final hasRange = startDate != null || endDate != null;
      if (hasRange) {
        query = query.orderBy('createdAt', descending: true);
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
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to count events (eventTypeId=$eventTypeId)',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Count overdue tasks (deadline in the past, not completed).
  Future<int> countOverdueTasks({required DateTime deadline}) async {
    try {
      Query<Map<String, dynamic>> query = organizationQuery(collectionRef)
          .where('eventTypeId', isEqualTo: EventType.task.id)
          .where('isCompleted', isEqualTo: false)
          .where('deadline', isLessThan: deadline.toIso8601String())
          .orderBy('deadline', descending: false);

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to count overdue tasks',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Count health issue observations using daily summary documents.
  ///
  /// Falls back to 0 if no summary docs exist for the requested range.
  Future<int> countHealthIssuesSummary({
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final rangeEnd = endDate ?? DateTime.now();
      final dates = _dateRangeDays(startDate, rangeEnd);
      if (dates.isEmpty) return 0;

      final snapshots = await Future.wait(
        dates.map((date) => _healthIssuesDailyDocRef(date).get()),
      );

      var total = 0;
      for (final snapshot in snapshots) {
        final data = snapshot.data();
        if (data == null) continue;
        final count = data['count'];
        if (count is int) {
          total += count;
        } else if (count is num) {
          total += count.toInt();
        }
      }
      return total;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to count health issue summaries',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Fetch the most recent event date for a given event type.
  Future<DateTime?> fetchMostRecentEventDate({
    required String eventTypeId,
  }) async {
    try {
      final snapshot = await organizationQuery(collectionRef)
          .where('eventTypeId', isEqualTo: eventTypeId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final createdAt = snapshot.docs.first.data()['createdAt']?.toString();
      if (createdAt == null || createdAt.isEmpty) return null;
      return DateTime.tryParse(createdAt);
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to fetch most recent event date for $eventTypeId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Stream events created by a specific user.
  ///
  /// Returns a stream of events where [createdById] matches the given [userId].
  /// Results are ordered by creation date (newest first) and limited to [limit].
  @override
  Stream<List<Event>> streamEventsForUser({
    required String userId,
    int limit = 50,
  }) {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    final query = organizationQuery(collectionRef)
        .where('createdById', isEqualTo: userId)
        .limit(limit);

    return _guardStream(
      query.snapshots().map((snapshot) {
        final events = <Event>[];
        for (final doc in snapshot.docs) {
          try {
            events.add(RecordFactory.eventFromJson(_injectDocId(doc)));
          } catch (error, stackTrace) {
            LoggingService.instance.error(
              'Failed to parse event ${doc.id} for user $userId',
              error,
              stackTrace,
            );
          }
        }
        // Sort in-memory by createdAt descending (newest first)
        events.sort((a, b) {
          final dateA =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        return events;
      }),
      debugLabel: 'streamEventsForUser(userId: $userId)',
    );
  }

  /// Stream pending/shipped transfers addressed to the organization.
  ///
  /// These events are created by the sender organization, so we filter on
  /// `toOrganizationId` instead of `organizationId` to surface inbound transfers.
  @override
  Stream<List<TransferEvent>> streamPendingTransfers({
    List<String>? eventTypeIds,
  }) {
    final queryIds = eventTypeIds ?? LoanEventType.queryIds;

    // CRITICAL: Filter by toOrganizationId for inbound transfers
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return _guardStream(
      collectionRef
          .where('toOrganizationId', isEqualTo: organization.id)
          .where('eventTypeId', whereIn: queryIds)
          .where(
            'status',
            whereIn: [
              TransferStatus.pending.value,
              TransferStatus.shipped.value,
            ],
          )
          .snapshots()
          .map((snapshot) {
            final transfers = <TransferEvent>[];
            for (final doc in snapshot.docs) {
              try {
                final transferEvent = TransferEvent.fromJson(_injectDocId(doc));
                transfers.add(transferEvent);
              } catch (e, stackTrace) {
                LoggingService.instance.error(
                  'Error parsing TransferEvent from doc ${doc.id}',
                  e,
                  stackTrace,
                );
              }
            }
            // Sort in-memory by createdAt descending (newest first)
            transfers.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dateB =
                  DateTime.tryParse(b.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA);
            });
            return transfers;
          }),
      debugLabel: 'streamPendingTransfers(toOrganizationId: ${organization.id})',
    );
  }

  /// Stream pending/shipped transfers created by the organization.
  ///
  /// Filters by `organizationId` and narrows to pending/shipped statuses
  /// in-memory to avoid adding a composite index.
  Stream<List<TransferEvent>> streamOutboundPendingTransfers({
    List<String>? eventTypeIds,
  }) {
    final queryIds = eventTypeIds ?? LoanEventType.queryIds;

    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return _guardStream(
      organizationQuery(collectionRef)
          .where('eventTypeId', whereIn: queryIds)
          .snapshots()
          .map((snapshot) {
            final transfers = <TransferEvent>[];
            for (final doc in snapshot.docs) {
              try {
                final transferEvent = TransferEvent.fromJson(_injectDocId(doc));
                final status = transferEvent.status;
                if (status != TransferStatus.pending.value &&
                    status != TransferStatus.shipped.value) {
                  continue;
                }
                transfers.add(transferEvent);
              } catch (e, stackTrace) {
                LoggingService.instance.error(
                  'Error parsing TransferEvent from doc ${doc.id}',
                  e,
                  stackTrace,
                );
              }
            }
            // Sort in-memory by createdAt descending (newest first)
            transfers.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dateB =
                  DateTime.tryParse(b.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA);
            });
            return transfers;
          }),
      debugLabel:
          'streamOutboundPendingTransfers(organizationId: ${organization.id})',
    );
  }

  /// Stream events linked to a specific mission.
  ///
  /// Returns events where [missionId] matches the given mission ID.
  /// Results are ordered by creation date (newest first) and limited to [limit].
  @override
  Stream<List<Event>> watchEventsForMission({
    required String missionId,
    int limit = 100,
  }) {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    final query = organizationQuery(collectionRef)
        .where('missionId', isEqualTo: missionId)
        .limit(limit);

    return _guardStream(
      query.snapshots().map((snapshot) {
        final events = <Event>[];
        for (final doc in snapshot.docs) {
          try {
            events.add(RecordFactory.eventFromJson(_injectDocId(doc)));
          } catch (error, stackTrace) {
            LoggingService.instance.error(
              'Failed to parse event ${doc.id} for mission $missionId',
              error,
              stackTrace,
            );
          }
        }
        // Sort in-memory by createdAt descending (newest first)
        events.sort((a, b) {
          final dateA =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        return events;
      }),
      debugLabel: 'watchEventsForMission(missionId: $missionId)',
    );
  }

  /// Fetch events linked to a specific mission.
  ///
  /// Returns events where [missionId] matches the given mission ID.
  /// Results are ordered by creation date (newest first) and limited to [limit].
  @override
  Future<List<Event>> getEventsForMission({
    required String missionId,
    int limit = 100,
  }) async {
    try {
      final query = organizationQuery(collectionRef)
          .where('missionId', isEqualTo: missionId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      final events = <Event>[];
      for (final doc in snapshot.docs) {
        try {
          events.add(RecordFactory.eventFromJson(_injectDocId(doc)));
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse event ${doc.id} for mission $missionId',
            error,
            stackTrace,
          );
        }
      }
      return events;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to fetch events for mission $missionId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }
}
