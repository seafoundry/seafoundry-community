part of 'inventory_events_table.dart';

/// Hydration logic for inventory events: fetching, filtering candidates by
/// supported types, and resolving organism + user references.
///
/// The lifecycle state ([isLoading], [loadingProgress], [loadingStatus],
/// [error], [rows]) is owned by [EventsTableScaffoldState]; this mixin
/// writes into those inherited fields directly.
mixin _InventoryEventHydrationMixin
    on EventsTableScaffoldState<InventoryEventsTable, _InventoryEventRow> {
  static const _eventFetchLimit = 250;
  static const _eventHydrationBatchSize = 20;

  final Map<String, String> _userNameCache = {};
  final Map<String, OrganismRecord?> _organismCache = {};

  Set<String> get _eventTypeFilter;

  /// Hook implemented by the table state to refresh derived/filtered rows
  /// after the canonical [rows] list changes.
  void _onRowsLoaded();

  @override
  Future<void> loadEvents() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      loadingProgress = null;
      loadingStatus = 'Loading $title...';
      error = null;
    });

    final providerResult = safeReadProviders(() => (
          context.read<EventRepository>(),
          context.read<RecordRepository>(),
          context.read<OrganismRecordRepository>(),
          context.read<CurrentUser>().state,
        ));

    if (!providerResult.success) {
      if (!mounted) return;
      setState(() {
        error = providerResult.errorMessage;
        isLoading = false;
      });
      return;
    }

    final (
      eventRepository,
      recordRepository,
      organismRepository,
      currentUserState,
    ) = providerResult.value!;

    String? organizationId;
    if (currentUserState is CurrentUserLoaded) {
      organizationId = currentUserState.organization.id;
    }
    if (organizationId == null || organizationId.isEmpty) {
      if (!mounted) return;
      setState(() {
        error = 'Session expired. Please refresh the page.';
        isLoading = false;
        loadingProgress = null;
        loadingStatus = null;
      });
      return;
    }

    try {
      if (!mounted) return;

      // Event-type filtering is applied client-side because Firestore's
      // whereIn is capped at 30 entries.
      final events = await eventRepository.fetchRecentEventsForOrganization(
        limit: _eventFetchLimit,
      );

      LoggingService.instance.info(
        '$title: Loaded ${events.length} events from EventRepository',
      );

      LoggingService.instance.info(
        '$title: Parsed ${events.length} events from Firestore',
      );

      // Filter to supported event types
      final candidates = <_InventoryEventCandidate>[];
      for (final event in events) {
        final eventTypeId = event.eventTypeId;
        if (eventTypeId.isEmpty) continue;
        if (!_eventTypeFilter.contains(eventTypeId)) continue;
        candidates.add(_InventoryEventCandidate(event, eventTypeId));
      }

      if (!mounted) return;
      setState(() {
        loadingProgress = candidates.isEmpty ? null : 0;
        loadingStatus = candidates.isEmpty
            ? 'No events to hydrate.'
            : 'Hydrating ${candidates.length} events...';
      });

      // Hydrate events in batches
      final hydratedRows = <_InventoryEventRow>[];
      var hydratedCount = 0;
      for (var i = 0; i < candidates.length; i += _eventHydrationBatchSize) {
        final batch =
            candidates.skip(i).take(_eventHydrationBatchSize).toList();
        final batchRows = await Future.wait(
          batch.map((candidate) async {
            try {
              return await _hydrateEvent(
                candidate.event,
                candidate.eventTypeId,
                recordRepository,
                organismRepository,
              );
            } catch (err, stackTrace) {
              LoggingService.instance.error(
                'Failed to hydrate event ${candidate.event.id}',
                err,
                stackTrace,
              );
              return null;
            }
          }),
        );

        hydratedRows.addAll(batchRows.whereType<_InventoryEventRow>());
        hydratedCount += batch.length;
        if (!mounted) return;
        if (candidates.isNotEmpty) {
          setState(() {
            loadingProgress = hydratedCount / candidates.length;
            loadingStatus =
                'Hydrating events $hydratedCount/${candidates.length}';
          });
        }
      }

      LoggingService.instance.info(
        '$title: ${hydratedRows.length} events hydrated',
      );

      if (!mounted) return;
      setState(() {
        rows
          ..clear()
          ..addAll(hydratedRows);
        _onRowsLoaded();
        isLoading = false;
        loadingProgress = null;
        loadingStatus = null;
      });
    } catch (err, stackTrace) {
      LoggingService.instance.error(
        'Failed to load $title',
        err,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        error = 'Failed to load events: $err';
        isLoading = false;
        loadingProgress = null;
        loadingStatus = null;
      });
    }
  }

  Future<_InventoryEventRow?> _hydrateEvent(
    Event event,
    String eventTypeId,
    RecordRepository recordRepository,
    OrganismRecordRepository organismRepository,
  ) async {
    if (!mounted) return null;

    final userName = await resolveUserDisplayName(
      recordRepository: recordRepository,
      userId: event.createdById,
      cache: _userNameCache,
    );

    OrganismRecord? organism;
    if (event.recordId.isNotEmpty) {
      organism = await _resolveOrganism(event.recordId, organismRepository);
    }

    final recordDisplay = organism?.tagId ?? event.recordId;
    final genetLocalId = organism?.localGenetId;
    final siteName = organism?.siteId ?? '';

    final details = _buildEventDetails(event, eventTypeId, organism);

    final eventLabel = _inventoryEventLabels[eventTypeId] ??
        EventType.builtins[eventTypeId]?.name ??
        eventTypeId;

    return _InventoryEventRow(
      eventId: event.id,
      eventTypeId: eventTypeId,
      eventLabel: eventLabel,
      recordDisplay: recordDisplay,
      genetLocalId: genetLocalId ?? '',
      details: details,
      siteName: siteName,
      userName: userName,
      createdAt: event.createdAtDateTime,
    );
  }

  Future<OrganismRecord?> _resolveOrganism(
    String organismId,
    OrganismRecordRepository organismRepository,
  ) async {
    final id = organismId.trim();
    if (id.isEmpty) return null;
    if (_organismCache.containsKey(id)) {
      return _organismCache[id];
    }

    try {
      if (!mounted) return null;
      final organism = await organismRepository.getRecordForId(id);
      if (!mounted) return null;
      // Only cache successful, non-null lookups so a transient failure does
      // not poison the cache for the rest of the session.
      if (mounted && organism != null) {
        _organismCache[id] = organism;
      }
      return organism;
    } catch (err, stackTrace) {
      LoggingService.instance.error(
        'Failed to resolve organism $id',
        err,
        stackTrace,
      );
      // Do not cache the failure — let the next attempt retry.
      return null;
    }
  }

  String _buildEventDetails(
    Event event,
    String eventTypeId,
    OrganismRecord? organism,
  ) {
    final parts = <String>[];
    final metadata = event.metadata;

    if (metadata != null) {
      final oldCount = metadata['oldCount'];
      final newCount = metadata['newCount'];
      if (oldCount != null && newCount != null) {
        parts.add('$oldCount -> $newCount');
      }

      final oldLifeStage = metadata['oldLifeStageId'];
      final newLifeStage = metadata['newLifeStageId'];
      if (oldLifeStage != null && newLifeStage != null) {
        parts.add('$oldLifeStage -> $newLifeStage');
      }

      final notes = metadata['notes'];
      if (notes is String && notes.isNotEmpty) {
        parts.add(notes);
      }
    }

    return parts.join(' | ');
  }
}
