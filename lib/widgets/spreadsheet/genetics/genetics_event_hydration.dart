part of 'genetics_events_table.dart';

/// Hydration logic for genetics events: fetching, filtering candidates by
/// supported types and record types, and resolving genets/organisms/users.
mixin _GeneticsEventHydrationMixin
    on
        State<GeneticsEventsTable>,
        SafeProviderReadMixin<GeneticsEventsTable> {
  static const _eventFetchLimit = 250;
  static const _eventHydrationBatchSize = 20;

  bool _isLoading = true;
  double? _loadingProgress;
  String? _loadingStatus;
  String? _error;

  final List<_GeneticsEventRow> _rows = [];
  final Map<String, String> _userNameCache = {};
  final Map<String, Genet?> _genetCache = {};
  final Map<String, OrganismRecord?> _organismCache = {};

  /// Hook implemented by the table state to refresh derived/filtered rows
  /// after the canonical [_rows] list changes.
  void _onRowsLoaded();

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadingProgress = null;
      _loadingStatus = 'Loading genetics events...';
      _error = null;
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
        _error = providerResult.errorMessage;
        _isLoading = false;
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
        _error = 'Session expired. Please refresh the page.';
        _isLoading = false;
        _loadingProgress = null;
        _loadingStatus = null;
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

      final rows = <_GeneticsEventRow>[];
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
        _loadingProgress = candidates.isEmpty ? null : 0;
        _loadingStatus = candidates.isEmpty
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
            } catch (error, stackTrace) {
              LoggingService.instance.error(
                'Failed to parse genetics event ${candidate.event.id}',
                error,
                stackTrace,
              );
              return null;
            }
          }),
        );

        rows.addAll(batchRows.whereType<_GeneticsEventRow>());
        hydratedCount += batch.length;
        if (!mounted) return;
        if (candidates.isNotEmpty) {
          setState(() {
            _loadingProgress = hydratedCount / candidates.length;
            _loadingStatus =
                'Hydrating events $hydratedCount/${candidates.length}';
          });
        }
      }

      LoggingService.instance.info(
        'GeneticsEventsTable: ${rows.length} events included, '
        '$skippedUnsupportedType unsupported type, '
        '$skippedIrrelevantRecord irrelevant record, '
        '$skippedNullRow null rows',
      );

      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(rows);
        _onRowsLoaded();
        _isLoading = false;
        _loadingProgress = null;
        _loadingStatus = null;
      });
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load genetics events',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load events: $error';
        _isLoading = false;
        _loadingProgress = null;
        _loadingStatus = null;
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
      if (mounted) {
        _genetCache[id] = genet;
      }
      return genet;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to resolve genet $id',
        error,
        stackTrace,
      );
      if (mounted) {
        _genetCache[id] = null;
      }
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
      if (mounted) {
        _organismCache[id] = organism;
      }
      return organism;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to resolve organism $id',
        error,
        stackTrace,
      );
      if (mounted) {
        _organismCache[id] = null;
      }
      return null;
    }
  }
}
