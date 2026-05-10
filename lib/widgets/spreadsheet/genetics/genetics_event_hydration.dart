part of 'genetics_events_table.dart';

/// Hydration logic for genetics events: fetching, filtering candidates by
/// supported types and record types, and resolving genets/organisms/users.
///
/// The lifecycle state ([isLoading], [loadingProgress], [loadingStatus],
/// [error], [rows]) is owned by [EventsTableScaffoldState]; this mixin
/// writes into those inherited fields directly.
mixin _GeneticsEventHydrationMixin
    on EventsTableScaffoldState<GeneticsEventsTable, _GeneticsEventRow> {
  static const _eventFetchLimit = 250;
  static const _eventHydrationBatchSize = 20;

  final Map<String, String> _userNameCache = {};
  final Map<String, Genet?> _genetCache = {};
  final Map<String, OrganismRecord?> _organismCache = {};

  /// Hook implemented by the table state to refresh derived/filtered rows
  /// after the canonical [rows] list changes.
  void _onRowsLoaded();

  @override
  Future<void> loadEvents() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      loadingProgress = null;
      loadingStatus = 'Loading genetics events...';
      error = null;
    });

    // Cache provider references before async operations
    final providerResult = safeReadProviders(() => (
          context.read<EventRepository>(),
          context.read<RecordRepository>(),
          context.read<GenetRepository>(),
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
      genetRepository,
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

      final events = await eventRepository.fetchRecentEventsForOrganization(
        limit: _eventFetchLimit,
      );

      LoggingService.instance.info(
        'GeneticsEventsTable: Loaded ${events.length} events from EventRepository',
      );

      final hydratedRows = <_GeneticsEventRow>[];
      final candidates = <_GeneticsEventCandidate>[];
      var skippedUnsupportedType = 0;
      var skippedIrrelevantRecord = 0;
      var skippedNullRow = 0;
      for (final event in events) {
        final eventTypeId = _sanitizeEventTypeId(event.eventTypeId);
        if (eventTypeId == null) {
          LoggingService.instance.warning(
            'Skipping genetics event with missing type: ${event.id}',
          );
          continue;
        }
        if (!_isSupportedEventType(eventTypeId)) {
          skippedUnsupportedType++;
          continue;
        }
        if (!_isRelevantRecordType(event.recordModelType)) {
          skippedIrrelevantRecord++;
          continue;
        }
        candidates.add(_GeneticsEventCandidate(event, eventTypeId));
      }

      if (!mounted) return;
      setState(() {
        loadingProgress = candidates.isEmpty ? null : 0;
        loadingStatus = candidates.isEmpty
            ? 'No events to hydrate.'
            : 'Hydrating ${candidates.length} events...';
      });

      var hydratedCount = 0;
      for (var i = 0; i < candidates.length; i += _eventHydrationBatchSize) {
        final batch =
            candidates.skip(i).take(_eventHydrationBatchSize).toList();
        final batchRows = await Future.wait(
          batch.map((candidate) async {
            try {
              final row = await _GeneticsEventRow.fromEvent(
                event: candidate.event,
                eventTypeId: candidate.eventTypeId,
                resolveUserName: (userId) =>
                    _resolveUserName(userId, recordRepository),
                resolveGenet: (genetRecordId) =>
                    _resolveGenet(genetRecordId, genetRepository),
                resolveOrganism: (organismId) =>
                    _resolveOrganism(organismId, organismRepository),
              );
              if (row == null) {
                skippedNullRow++;
                LoggingService.instance.warning(
                  'GeneticsEventsTable: null row for event ${candidate.event.id} '
                  '(type: ${candidate.eventTypeId}, record: ${candidate.event.recordModelType}, '
                  'runtime: ${candidate.event.runtimeType})',
                );
                return null;
              }
              return row;
            } catch (err, stackTrace) {
              LoggingService.instance.error(
                'Failed to parse genetics event ${candidate.event.id}',
                err,
                stackTrace,
              );
              return null;
            }
          }),
        );

        hydratedRows.addAll(batchRows.whereType<_GeneticsEventRow>());
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
        'GeneticsEventsTable: ${hydratedRows.length} events included, '
        '$skippedUnsupportedType unsupported type, '
        '$skippedIrrelevantRecord irrelevant record, '
        '$skippedNullRow null rows',
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
        'Failed to load genetics events',
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

  Future<String> _resolveUserName(
    String userId,
    RecordRepository recordRepository,
  ) async {
    return resolveUserDisplayName(
      recordRepository: recordRepository,
      userId: userId,
      cache: _userNameCache,
    );
  }

  Future<Genet?> _resolveGenet(
    String? genetRecordId,
    GenetRepository genetRepository,
  ) async {
    final id = genetRecordId?.trim();
    if (id == null || id.isEmpty) return null;
    if (_genetCache.containsKey(id)) {
      return _genetCache[id];
    }

    try {
      if (!mounted) return null;
      final genet = await genetRepository.getRecordForId(id);
      if (!mounted) return null;
      // Only cache successful, non-null lookups so a transient failure does
      // not poison the cache for the rest of the session.
      if (mounted && genet != null) {
        _genetCache[id] = genet;
      }
      return genet;
    } catch (err, stackTrace) {
      LoggingService.instance.error(
        'Failed to resolve genet $id',
        err,
        stackTrace,
      );
      // Do not cache the failure — let the next attempt retry.
      return null;
    }
  }

  Future<OrganismRecord?> _resolveOrganism(
    String? organismId,
    OrganismRecordRepository organismRepository,
  ) async {
    final id = organismId?.trim();
    if (id == null || id.isEmpty) return null;
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
}
