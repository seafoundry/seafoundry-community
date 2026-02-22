// @tier: community
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/models/events/events.dart';
import 'package:seafoundry_app/models/schemas/provenance_schema.dart';
import 'package:seafoundry_app/models/inventory/holding_summary.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/types/attachment_method.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/holding_summary_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/location_display_service.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';
import 'package:seafoundry_app/widgets/spreadsheet/outplant/outplant_events_filter_metadata.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';

part 'outplant_events_spreadsheet_state.dart';

class OutplantEventsSpreadsheetCubit
    extends Cubit<OutplantEventsSpreadsheetState>
    with CubitStreamSubscriptionMixin {
  OutplantEventsSpreadsheetCubit({
    required EventRepository eventRepository,
    required SiteRepository siteRepository,
    required OrganismRecordRepository organismRepository,
    required ProvenanceRepository provenanceRepository,
    String? siteFilter,
    String? structureFilter,
    String? speciesFilter,
    String? genetFilter,
    String? lifeStageFilter,
    String? provenanceTypeFilter,
    DateTimeRange? dateRange,
    String? searchTerm,
    OrganismKind organismKind = OrganismKind.coral,
    HoldingSummaryService? holdingSummaryService,
  }) : _eventRepository = eventRepository,
       _siteRepository = siteRepository,
       _organismRepository = organismRepository,
       _provenanceRepository = provenanceRepository,
       _holdingSummaryService = holdingSummaryService,
       super(
         OutplantEventsSpreadsheetState(
           selectedSiteIds: siteFilter != null ? {siteFilter} : const {},
           selectedStructureIds:
               structureFilter != null ? {structureFilter} : const {},
           selectedSpeciesIds:
               speciesFilter != null ? {speciesFilter} : const {},
           selectedGenetIds: genetFilter != null ? {genetFilter} : const {},
           selectedLifeStageIds:
               lifeStageFilter != null ? {lifeStageFilter} : const {},
           selectedProvenanceTypeIds:
               provenanceTypeFilter != null ? {provenanceTypeFilter} : const {},
           selectedDateRange: dateRange,
           searchTerm: searchTerm,
           widgetSiteFilter: siteFilter,
           widgetStructureFilter: structureFilter,
           widgetSpeciesFilter: speciesFilter,
           widgetGenetFilter: genetFilter,
           widgetLifeStageFilter: lifeStageFilter,
           widgetProvenanceTypeFilter: provenanceTypeFilter,
           widgetDateRange: dateRange,
           widgetSearchTerm: searchTerm,
           organismFilter: organismKind,
         ),
       ) {
    LoggingService.instance.debug(
      'OutplantEventsSpreadsheetCubit: Initializing with filters: site=$siteFilter, structure=$structureFilter',
    );

    _listenForUpdates();
    _loadInitialSites();

    // Add a timeout to ensure loading state doesn't stay forever
    // If stream hasn't emitted after 5 seconds, set loading to false
    Future.delayed(const Duration(seconds: 5), () {
      if (!isClosed && state.isLoading && state.streamEvents.isEmpty) {
        LoggingService.instance.warning(
          'OutplantEventsSpreadsheet: Stream timeout - no events received after 5 seconds. Setting loading to false.',
        );
        emit(state.copyWith(isLoading: false));
      }
    });

    // Debug initial state
    LoggingService.instance.debug(
      'OutplantEventsSpreadsheet: Initial state - isLoading: ${state.isLoading}, '
      'streamEvents: ${state.streamEvents.length}, filteredEvents: ${state.filteredEvents.length}',
    );
  }

  final EventRepository _eventRepository;
  final SiteRepository _siteRepository;
  final OrganismRecordRepository _organismRepository;
  final ProvenanceRepository _provenanceRepository;
  final HoldingSummaryService? _holdingSummaryService;

  void _listenForUpdates() {
    LoggingService.instance.debug(
      'OutplantEventsSpreadsheet: Subscribing to event stream',
    );

    final eventStream = _eventRepository.streamAll;

    if (!eventStream.isBroadcast) {
      LoggingService.instance.warning(
        'OutplantEventsSpreadsheet: EventRepository streamAll is not a broadcast stream',
      );
    }

    try {
      listenWithKey<List<Event>>(
        'events',
        eventStream,
        onData: (events) {
          if (isClosed) return;
          LoggingService.instance.debug(
            'OutplantEventsSpreadsheet: Received ${events.length} total events from stream',
          );
          _handleEventStream(events);
        },
        onError: (error, stackTrace) {
          if (isClosed) return;

          // Suppress permission-denied errors during navigation/logout
          if (_isPermissionDeniedError(error)) {
            LoggingService.instance.debug(
              'OutplantEventsSpreadsheet: Ignoring permission-denied error during navigation',
            );
            return;
          }

          LoggingService.instance.error(
            'Outplant event stream failed',
            error,
            stackTrace,
          );
          emit(
            state.copyWith(isLoading: false, errorMessage: error.toString()),
          );
        },
      );

      LoggingService.instance.debug(
        'OutplantEventsSpreadsheet: Successfully subscribed to event stream (isBroadcast: ${eventStream.isBroadcast})',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'OutplantEventsSpreadsheet: Failed to subscribe to event stream',
        e,
        stackTrace,
      );
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to subscribe to event stream: $e',
        ),
      );
    }
  }

  void _handleEventStream(List<Event> events) {
    if (isClosed) return;

    try {
      final outplantEvents = events.whereType<OutplantEvent>().toList();

      LoggingService.instance.debug(
        'OutplantEventsSpreadsheet: Received ${events.length} total events, found ${outplantEvents.length} OutplantEvent instances',
      );

      // Always emit, even if empty, to clear loading state
      emit(
        state.copyWith(
          streamEvents: outplantEvents,
          isLoading: false,
          errorMessage: null,
        ),
      );

      // Apply filters to update filteredEvents
      unawaited(_applyFilters());
    } catch (e, stackTrace) {
      if (isClosed) return;
      LoggingService.instance.error(
        'OutplantEventsSpreadsheet: Error handling event stream',
        e,
        stackTrace,
      );
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Error processing events: $e',
        ),
      );
    }
  }

  void _listenForSiteUpdates() {
    listenWithKey<List<Site>>(
      'sites',
      _siteRepository.streamAll,
      onData: (sites) {
        if (isClosed) return;
        _applySiteSnapshot(sites);
      },
      onError: (error, stackTrace) {
        if (isClosed) return;

        // Suppress permission-denied errors during navigation/logout
        // These are expected when RepositoriesProvider is disposed
        if (_isPermissionDeniedError(error)) {
          LoggingService.instance.debug(
            'OutplantEventsSpreadsheet: Ignoring permission-denied error during navigation',
          );
          return;
        }

        LoggingService.instance.error(
          'OutplantEventsSpreadsheet: Site stream failed',
          error,
          stackTrace,
        );
        emit(
          state.copyWith(
            errorMessage: 'Failed to load sites: $error',
            isLoading: false,
          ),
        );
      },
    );
  }

  /// Checks if an error is a permission-denied error from Firestore.
  /// These errors are expected during logout/navigation when auth is invalidated.
  bool _isPermissionDeniedError(Object error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission-denied') ||
        errorStr.contains('permission denied') ||
        errorStr.contains('missing or insufficient permissions');
  }

  Future<void> _loadInitialSites() async {
    try {
      final sites = await _siteRepository.getAll();
      if (isClosed) return;
      _applySiteSnapshot(sites);
      _listenForSiteUpdates();
    } catch (e, stackTrace) {
      if (isClosed) return;

      // Suppress permission-denied errors during navigation/logout
      if (_isPermissionDeniedError(e)) {
        LoggingService.instance.debug(
          'OutplantEventsSpreadsheet: Ignoring permission-denied error during navigation',
        );
        return;
      }

      LoggingService.instance.error(
        'Failed to load sites for outplant spreadsheet',
        e,
        stackTrace,
      );
      emit(
        state.copyWith(
          errorMessage: 'Failed to load sites: $e',
          isLoading: false,
        ),
      );
    }
  }

  void _applySiteSnapshot(List<Site> sites) {
    final outplantSites = sites
        .where((site) => site.siteTypeId == SiteType.outplanting.id)
        .toList();

    final siteNameIndex = {
      for (final site in outplantSites) site.id: site.name,
    };

    final shouldSetLoading = state.isLoading && state.streamEvents.isEmpty;

    if (!isClosed) {
      emit(
        state.copyWith(
          siteNameIndex: siteNameIndex,
          outplantSites: outplantSites,
          isLoading: shouldSetLoading ? false : state.isLoading,
        ),
      );
    }
  }

  List<OutplantEvent> get _allEvents {
    final combined = <String, OutplantEvent>{};
    for (final event in state.streamEvents) {
      combined[event.id] = event;
    }
    for (final entry in state.fetchedEvents.entries) {
      combined[entry.key] = entry.value;
    }
    return combined.values.toList();
  }

  Future<void> fetchAdditionalEvents(DateTimeRange range) async {
    try {
      final fetched = await _eventRepository.fetchOutplantEvents(
        start: range.start,
        end: range.end,
      );
      if (isClosed) return;
      if (fetched.isEmpty) return;

      final fetchedEvents = Map<String, OutplantEvent>.from(
        state.fetchedEvents,
      );
      for (final event in fetched) {
        fetchedEvents[event.id] = event;
      }

      emit(state.copyWith(fetchedEvents: fetchedEvents));
    } catch (e, stackTrace) {
      if (isClosed) return;
      LoggingService.instance.error(
        'Fetch outplant events failed',
        e,
        stackTrace,
      );
      emit(state.copyWith(errorMessage: 'Failed to fetch additional data: $e'));
    }
  }

  /// Apply multiselect filters with cascading logic.
  /// When upstream filter changes, downstream filters are cleared.
  void applyFilters({
    Set<String>? siteIds,
    Set<String>? eventIds,
    Set<String>? structureIds,
    Set<String>? speciesIds,
    Set<String>? genetIds,
    Set<String>? lifeStageIds,
    Set<String>? provenanceTypeIds,
    String? search,
    DateTimeRange? dateRange,
    bool clearDate = false,
    bool updateSearch = false,
    // Flags to indicate which filter is the "trigger" for cascading
    bool updateSite = false,
    bool updateEvent = false,
    bool updateStructure = false,
    bool updateSpecies = false,
    bool updateGenet = false,
    bool updateLifeStage = false,
    bool updateProvenanceType = false,
  }) {
    // Determine final filter values based on what was passed
    var finalSiteIds = siteIds ?? state.selectedSiteIds;
    var finalEventIds = eventIds ?? state.selectedEventIds;
    var finalStructureIds = structureIds ?? state.selectedStructureIds;
    var finalSpeciesIds = speciesIds ?? state.selectedSpeciesIds;
    var finalGenetIds = genetIds ?? state.selectedGenetIds;
    var finalLifeStageIds = lifeStageIds ?? state.selectedLifeStageIds;
    var finalProvenanceTypeIds =
        provenanceTypeIds ?? state.selectedProvenanceTypeIds;
    final finalSearch = updateSearch ? search : state.searchTerm;

    // Cascading logic: clear downstream filters when upstream changes
    if (updateSite) {
      // Site changed -> clear all downstream filters
      finalEventIds = const {};
      finalStructureIds = const {};
      finalSpeciesIds = const {};
      finalGenetIds = const {};
      finalLifeStageIds = const {};
      finalProvenanceTypeIds = const {};
    } else if (updateEvent) {
      // Event changed -> clear structure and below
      finalStructureIds = const {};
      finalSpeciesIds = const {};
      finalGenetIds = const {};
      finalLifeStageIds = const {};
      finalProvenanceTypeIds = const {};
    } else if (updateStructure) {
      // Structure changed -> clear species and below
      finalSpeciesIds = const {};
      finalGenetIds = const {};
      finalLifeStageIds = const {};
      finalProvenanceTypeIds = const {};
    } else if (updateSpecies) {
      // Species changed -> clear genet and below
      finalGenetIds = const {};
      finalLifeStageIds = const {};
      finalProvenanceTypeIds = const {};
    } else if (updateGenet) {
      // Genet changed -> clear life stage and below
      finalLifeStageIds = const {};
      finalProvenanceTypeIds = const {};
    } else if (updateLifeStage) {
      // Life stage changed -> clear provenance type
      finalProvenanceTypeIds = const {};
    }

    emit(
      state.copyWith(
        selectedSiteIds: finalSiteIds,
        selectedEventIds: finalEventIds,
        selectedStructureIds: finalStructureIds,
        selectedSpeciesIds: finalSpeciesIds,
        selectedGenetIds: finalGenetIds,
        selectedLifeStageIds: finalLifeStageIds,
        selectedProvenanceTypeIds: finalProvenanceTypeIds,
        searchTerm: finalSearch,
        clearSearchTerm: updateSearch && (search == null || search.isEmpty),
        selectedDateRange: dateRange,
        clearDateRange: clearDate,
      ),
    );

    unawaited(_applyFilters());
  }

  void setOrganismFilter(OrganismKind kind) {
    if (state.organismFilter == kind) {
      return;
    }

    emit(
      state.copyWith(
        organismFilter: kind,
        filteredEvents: kind == OrganismKind.coral
            ? state.filteredEvents
            : const [],
        // Clear all filters when organism changes
        selectedSiteIds: const {},
        selectedEventIds: const {},
        selectedStructureIds: const {},
        selectedSpeciesIds: const {},
        selectedGenetIds: const {},
        selectedLifeStageIds: const {},
        selectedProvenanceTypeIds: const {},
        reloadToken: state.reloadToken + 1,
      ),
    );
    unawaited(_refreshHoldingSummaries());

    if (kind == OrganismKind.coral) {
      unawaited(_applyFilters());
    }
  }

  Future<void> _applyFilters() async {
    // Prevent filtering if we're still loading initial data
    if (state.isLoading) {
      LoggingService.instance.debug(
        'OutplantEventsSpreadsheet._applyFilters: Skipping because still loading',
      );
      return;
    }

    if (state.organismFilter != OrganismKind.coral) {
      emit(
        state.copyWith(
          filteredEvents: const [],
          reloadToken: state.reloadToken + 1,
        ),
      );
      return;
    }

    var events = _allEvents;
    await ensureAllocationMetadata(events);
    LoggingService.instance.debug(
      'OutplantEventsSpreadsheet._applyFilters: Filtering ${events.length} total events',
    );
    events = events.where((event) {
      final eventKind = _organismKindForEvent(event);
      return eventKind == null || eventKind == OrganismKind.coral;
    }).toList();

    final availableEventNames = events.map((event) => event.name).toSet();

    // Check if selected event names are still valid
    final validatedEventIds = state.selectedEventIds
        .where((name) => availableEventNames.contains(name))
        .toSet();

    // Filter by event name (OR logic)
    if (validatedEventIds.isNotEmpty) {
      events = events
          .where((event) => validatedEventIds.contains(event.name))
          .toList();
    }

    final dateRange = state.selectedDateRange;
    if (dateRange != null) {
      final start = DateRangePresets.startOfDay(dateRange.start);
      final end = DateRangePresets.endOfDay(dateRange.end);
      events = events.where((event) {
        final eventDate = _tryParseCreatedAt(event.createdAt);
        if (eventDate == null) {
          return false;
        }
        return !eventDate.isBefore(start) && !eventDate.isAfter(end);
      }).toList();
    }

    // Site filter - OR logic
    if (state.selectedSiteIds.isNotEmpty) {
      events = events
          .where((event) => state.selectedSiteIds.contains(event.siteId))
          .toList();
    }

    // Species filter - OR logic
    if (state.selectedSpeciesIds.isNotEmpty) {
      events = events
          .where(
            (event) => event.allocations.any(
              (allocation) =>
                  state.selectedSpeciesIds.contains(allocation.speciesId),
            ),
          )
          .toList();
    }

    // Genet filter - OR logic
    if (state.selectedGenetIds.isNotEmpty) {
      events = events
          .where(
            (event) => event.allocations.any(
              (allocation) =>
                  allocation.genetId != null &&
                  state.selectedGenetIds.contains(allocation.genetId),
            ),
          )
          .toList();
    }

    // Life stage filter - OR logic
    if (state.selectedLifeStageIds.isNotEmpty) {
      events = events
          .where(
            (event) => event.allocations.any(
              (allocation) => _matchesAnyLifeStageFilter(
                allocation,
                state.selectedLifeStageIds,
              ),
            ),
          )
          .toList();
    }

    // Provenance type filter - OR logic
    if (state.selectedProvenanceTypeIds.isNotEmpty) {
      events = events
          .where(
            (event) => event.allocations.any(
              (allocation) => _matchesAnyProvenanceTypeFilter(
                allocation,
                state.selectedProvenanceTypeIds,
              ),
            ),
          )
          .toList();
    }

    final search = state.searchTerm?.trim();
    if (search != null && search.isNotEmpty) {
      final query = search.toLowerCase();
      events = events.where((event) {
        final matchesName = event.name.toLowerCase().contains(query);
        final matchesAlloc = event.allocations.any(
          (allocation) =>
              allocation.recordName.toLowerCase().contains(query) ||
              allocation.genetId?.toLowerCase().contains(query) == true ||
              allocation.speciesId.toLowerCase().contains(query),
        );
        return matchesName || matchesAlloc;
      }).toList();
    }

    events.sort((a, b) => _eventDateForSort(b).compareTo(_eventDateForSort(a)));

    LoggingService.instance.debug(
      'OutplantEventsSpreadsheet._applyFilters: Result - ${events.length} filtered events, '
      'reloadToken: ${state.reloadToken + 1}',
    );

    if (!isClosed) {
      emit(
        state.copyWith(
          filteredEvents: events,
          selectedEventIds: validatedEventIds,
          reloadToken: state.reloadToken + 1,
        ),
      );
    }
    unawaited(_refreshHoldingSummaries());
  }

  Future<void> ensureAllocationMetadata(List<OutplantEvent> events) async {
    final coralIds = <String>{};
    final genetIds = <String>{};

    for (final event in events) {
      for (final allocation in event.allocations) {
        if (allocation.organismId.isNotEmpty &&
            !state.coralCache.containsKey(allocation.organismId)) {
          coralIds.add(allocation.organismId);
        }
        final genetId = allocation.genetId;
        if (genetId != null &&
            genetId.isNotEmpty &&
            !state.genetCache.containsKey(genetId)) {
          genetIds.add(genetId);
        }
      }
    }

    // Skip if nothing to fetch
    if (coralIds.isEmpty && genetIds.isEmpty) {
      return;
    }

    LoggingService.instance.debug(
      'OutplantEventsSpreadsheet: Fetching metadata for ${coralIds.length} corals and ${genetIds.length} genets',
    );

    final organismCache = Map<String, OrganismRecord?>.from(state.coralCache);
    final genetCache = Map<String, ProvenanceRecord?>.from(state.genetCache);

    // Batch the requests to avoid overwhelming Firebase
    const batchSize = 10;

    // Process organism IDs in batches
    final organismIdList = coralIds.toList();
    for (var i = 0; i < organismIdList.length; i += batchSize) {
      final batch = organismIdList.sublist(
        i,
        (i + batchSize > organismIdList.length)
            ? organismIdList.length
            : i + batchSize,
      );

      await Future.wait(
        batch.map((id) async {
          try {
            final organism = await _organismRepository.getRecordForId(id);
            organismCache[id] = organism;
          } catch (error, stackTrace) {
            LoggingService.instance.error(
              'Failed to load organism $id for outplant metadata',
              error,
              stackTrace,
            );
            organismCache[id] = null;
          }
        }),
      );
      if (isClosed) return;
    }

    // Process genet IDs in batches
    final genetIdList = genetIds.toList();
    for (var i = 0; i < genetIdList.length; i += batchSize) {
      final batch = genetIdList.sublist(
        i,
        (i + batchSize > genetIdList.length)
            ? genetIdList.length
            : i + batchSize,
      );

      await Future.wait(
        batch.map((id) async {
          try {
            final genet = await _provenanceRepository.getRecordForId(id);
            genetCache[id] = genet;
          } catch (error, stackTrace) {
            LoggingService.instance.error(
              'Failed to load genet $id for outplant metadata',
              error,
              stackTrace,
            );
            genetCache[id] = null;
          }
        }),
      );
      if (isClosed) return;
    }

    emit(state.copyWith(coralCache: organismCache, genetCache: genetCache));
  }

  List<String> get availableSpeciesIds {
    final ids = <String>{};
    for (final event in _allEvents) {
      for (final allocation in event.allocations) {
        if (allocation.speciesId.isNotEmpty) {
          ids.add(allocation.speciesId);
        }
      }
    }
    final sorted = ids.toList()
      ..sort((a, b) => _speciesName(a).compareTo(_speciesName(b)));
    return sorted;
  }

  List<String> get availableGenetIds {
    final ids = <String>{};
    for (final event in _allEvents) {
      for (final allocation in event.allocations) {
        final genetId = allocation.genetId;
        if (genetId != null && genetId.isNotEmpty) {
          ids.add(genetId);
        }
      }
    }
    final sorted = ids.toList()..sort();
    return sorted;
  }

  Map<String, String> get availableGenetLabels {
    final labels = <String, String>{};
    for (final event in _allEvents) {
      for (final allocation in event.allocations) {
        final genetId = allocation.genetId;
        if (genetId == null || genetId.isEmpty) continue;
        if (labels.containsKey(genetId)) continue;

        final genet = state.genetCache[genetId];
        final genetName = genet?.displayName;
        final displayName = genetName?.trim();
        if (displayName != null && displayName.isNotEmpty) {
          labels[genetId] = displayName;
        } else {
          labels[genetId] = genetId;
        }
      }
    }

    // Ensure deterministic order by sorting values
    final sortedEntries = labels.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return {for (final entry in sortedEntries) entry.key: entry.value};
  }

  List<String> get availableStructurePaths {
    final paths = <String>{};
    for (final event in _allEvents) {
      for (final allocation in event.allocations) {
        final path = allocation.sourcePath;
        if (path.isNotEmpty) {
          paths.add(path);
        }
      }
    }
    final sorted = paths.toList()..sort();
    return sorted;
  }

  List<String> get availableLifeStageIds {
    final ids = <String>{};
    for (final organism
        in state.coralCache.values.whereType<OrganismRecord>()) {
      final lifeStageId = organism.lifeStageId;
      final normalized = _normalizeLifeStageId(lifeStageId);
      if (normalized != null) {
        ids.add(normalized);
      }
    }
    for (final event in _allEvents) {
      for (final allocation in event.allocations) {
        final snapshotStage = _normalizeLifeStageId(
          _metadataString(allocation.snapshot, 'lifeStageId'),
        );
        if (snapshotStage != null) {
          ids.add(snapshotStage);
        }
      }
    }
    final sorted = ids.toList()
      ..sort((a, b) => _lifeStageDisplay(a).compareTo(_lifeStageDisplay(b)));
    return sorted;
  }

  List<String> get availableProvenanceTypeIds {
    final ids = <String>{};
    for (final genet in state.genetCache.values.whereType<ProvenanceRecord>()) {
      final type = genet.provenanceTypeId;
      if (type != null) {
        ids.add(type);
      }
    }
    for (final event in _allEvents) {
      for (final allocation in event.allocations) {
        final snapshotType = _normalizeProvenanceType(
          _metadataString(allocation.snapshot, 'provenanceType'),
        );
        if (snapshotType != null) {
          ids.add(snapshotType);
        }
      }
    }
    final sorted = ids.toList()
      ..sort(
        (a, b) =>
            _provenanceTypeDisplay(a).compareTo(_provenanceTypeDisplay(b)),
      );
    return sorted;
  }

  List<String> get availableEventNames {
    final events = List<OutplantEvent>.from(_allEvents);
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final seen = <String>{};
    final names = <String>[];
    for (final event in events) {
      final name = event.name.trim();
      if (name.isEmpty) continue;
      if (seen.add(name)) {
        names.add(name);
      }
    }
    return names;
  }

  static String _speciesName(String speciesId) {
    if (speciesId.isEmpty) return '';
    final species = SpeciesRegistry.globalById(speciesId);
    return species?.name ?? speciesId;
  }

  Future<PageResult<Map<String, dynamic>>> loadPage({
    required int pageSize,
    PageCursor? startAfter,
    String? sortField,
    bool descending = true,
    void Function(OutplantEventsFilterMetadata)? onMetadataChanged,
  }) async {
    try {
      if (state.organismFilter != OrganismKind.coral) {
        return const PageResult<Map<String, dynamic>>(
          items: [],
          nextCursor: null,
          totalCount: 0,
        );
      }

      LoggingService.instance.debug(
        'OutplantEventsSpreadsheet.loadPage: Loading page with ${state.filteredEvents.length} filtered events',
      );

      // Ensure we have metadata for all allocations
      await ensureAllocationMetadata(state.filteredEvents);

      // Widget filters take precedence over cubit filters
      final dateFilter = state.widgetDateRange ?? state.selectedDateRange;
      final queries = <String>[];
      if (state.widgetSearchTerm != null &&
          state.widgetSearchTerm!.trim().isNotEmpty) {
        queries.add(state.widgetSearchTerm!.trim().toLowerCase());
      }
      final search = state.searchTerm?.trim();
      if (search != null && search.isNotEmpty) {
        queries.add(search.toLowerCase());
      }

      LoggingService.instance.debug(
        'OutplantEventsSpreadsheet.loadPage: Processing events with dateFilter: $dateFilter, '
        'queries: $queries, widgetFilters: site=${state.widgetSiteFilter}, '
        'species=${state.widgetSpeciesFilter}, genet=${state.widgetGenetFilter}',
      );

      // Create one row per allocation with event information
      final rows = <Map<String, dynamic>>[];
      final siteNames = <String, String>{};
      final structurePaths = <String>{};
      final speciesIds = <String>{};
      final speciesLabels = <String, String>{};
      final genetIds = <String>{};
      final genetLabels = <String, String>{};
      final lifeStageIds = <String>{};
      final provenanceTypes = <String>{};

      for (final event in state.filteredEvents) {
        final widgetSiteFilter = state.widgetSiteFilter;
        if (widgetSiteFilter != null && widgetSiteFilter.isNotEmpty) {
          if (event.siteId != widgetSiteFilter) {
            continue;
          }
        }

        final eventDate = _tryParseCreatedAt(event.createdAt);
        if (dateFilter != null) {
          final normalizedStart = DateRangePresets.startOfDay(dateFilter.start);
          final normalizedEnd = DateRangePresets.endOfDay(dateFilter.end);
          if (eventDate == null ||
              eventDate.isBefore(normalizedStart) ||
              eventDate.isAfter(normalizedEnd)) {
            continue;
          }
        }

        final siteName = state.siteNameIndex[event.siteId] ?? event.siteId;
        siteNames[event.siteId] = siteName;

        for (final allocation in event.allocations) {
          // Apply allocation-level filters
          final widgetStructureFilter = state.widgetStructureFilter;
          if (widgetStructureFilter != null &&
              widgetStructureFilter.isNotEmpty) {
            final structure = allocation.sourcePath;
            if (structure.isEmpty ||
                !structure.contains(widgetStructureFilter)) {
              continue;
            }
          }

          final effectiveSpeciesFilter = state.widgetSpeciesFilter;
          if (effectiveSpeciesFilter != null &&
              effectiveSpeciesFilter.isNotEmpty &&
              allocation.speciesId != effectiveSpeciesFilter) {
            continue;
          }

          final effectiveGenetFilter = state.widgetGenetFilter;
          if (effectiveGenetFilter != null &&
              effectiveGenetFilter.isNotEmpty &&
              allocation.genetId != effectiveGenetFilter) {
            continue;
          }

          final effectiveLifeStageFilter = state.widgetLifeStageFilter;
          if (effectiveLifeStageFilter != null &&
              effectiveLifeStageFilter.isNotEmpty &&
              !_matchesLifeStageFilter(allocation, effectiveLifeStageFilter)) {
            continue;
          }

          final effectiveProvenanceFilter = state.widgetProvenanceTypeFilter;
          if (effectiveProvenanceFilter != null &&
              effectiveProvenanceFilter.isNotEmpty &&
              !_matchesProvenanceTypeFilter(
                allocation,
                effectiveProvenanceFilter,
              )) {
            continue;
          }

          final effectiveSearch = state.widgetSearchTerm ?? state.searchTerm;
          if (effectiveSearch != null && effectiveSearch.isNotEmpty) {
            final query = effectiveSearch.toLowerCase();
            final matchesAlloc =
                allocation.recordName.toLowerCase().contains(query) ||
                allocation.genetId?.toLowerCase().contains(query) == true ||
                allocation.speciesId.toLowerCase().contains(query);
            if (!matchesAlloc && !event.name.toLowerCase().contains(query)) {
              continue;
            }
          }

          final matchesQueries = queries.every((query) {
            final lowerEventName = event.name.toLowerCase();
            final lowerCoralName = allocation.recordName.toLowerCase();
            final lowerGenetId = allocation.genetId?.toLowerCase() ?? '';
            final lowerSpeciesId = allocation.speciesId.toLowerCase();
            final lowerSite = siteName.toLowerCase();
            return lowerEventName.contains(query) ||
                lowerCoralName.contains(query) ||
                lowerGenetId.contains(query) ||
                lowerSpeciesId.contains(query) ||
                lowerSite.contains(query);
          });
          if (!matchesQueries) continue;

          rows.add(_createRow(event, allocation));

          structurePaths.add(allocation.sourcePath);
          if (allocation.speciesId.isNotEmpty) {
            speciesIds.add(allocation.speciesId);
            speciesLabels[allocation.speciesId] = _speciesName(
              allocation.speciesId,
            );
          }
          final genetId = allocation.genetId;
          if (genetId != null && genetId.isNotEmpty) {
            genetIds.add(genetId);
            genetLabels[genetId] =
                state.genetCache[genetId]?.displayName ?? genetId;
          }
          final lifeStageId = _lifeStageFromAllocation(allocation);
          if (lifeStageId != null) {
            lifeStageIds.add(lifeStageId);
          }
          final provenanceTypeId = _provenanceTypeFromAllocation(allocation);
          if (provenanceTypeId != null) {
            provenanceTypes.add(provenanceTypeId);
          }
        }
      }

      onMetadataChanged?.call(
        OutplantEventsFilterMetadata(
          siteNames: siteNames,
          structurePaths: structurePaths,
          speciesIds: speciesIds,
          speciesLabels: speciesLabels,
          genetIds: genetIds,
          genetLabels: genetLabels,
          lifeStageIds: lifeStageIds,
          provenanceTypes: provenanceTypes,
        ),
      );

      final totalCount = rows.length;
      final orderedRows = descending
          ? rows
          : rows.reversed.toList(growable: false);
      var startIndex = 0;
      if (startAfter is int) {
        startIndex = startAfter;
        if (startIndex < 0) {
          startIndex = 0;
        } else if (startIndex > totalCount) {
          startIndex = totalCount;
        }
      }
      final endIndex = (startIndex + pageSize) > totalCount
          ? totalCount
          : startIndex + pageSize;
      final pageItems = orderedRows.sublist(startIndex, endIndex);
      final nextCursor = endIndex < totalCount ? endIndex : null;

      return PageResult<Map<String, dynamic>>(
        items: pageItems,
        nextCursor: nextCursor,
        totalCount: totalCount,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'OutplantEventsSpreadsheet.loadPage failed',
        e,
        stackTrace,
      );
      // Return empty result instead of throwing to prevent UI crash
      return const PageResult<Map<String, dynamic>>(
        items: [],
        nextCursor: null,
        totalCount: 0,
      );
    }
  }

  Future<void> _refreshHoldingSummaries() async {
    final service = _holdingSummaryService;
    if (service == null) return;
    try {
      final summaries = await service.fetchSummaries(
        organismFilter: state.organismFilter == OrganismKind.coral
            ? null
            : state.organismFilter,
      );
      if (isClosed) return;
      emit(state.copyWith(holdingSummaries: summaries));
    } catch (error, stackTrace) {
      if (isClosed) return;
      LoggingService.instance.warning(
        'OutplantEventsSpreadsheet: holding summary refresh failed: $error',
      );
      LoggingService.instance.trace(
        'OutplantEventsSpreadsheet holding summary stack trace',
        stackTrace,
      );
    }
  }

  bool _matchesLifeStageFilter(
    OutplantAllocation allocation,
    String requiredStageId,
  ) {
    final lifeStageId = _lifeStageFromAllocation(allocation);
    return lifeStageId != null && lifeStageId == requiredStageId;
  }

  bool _matchesAnyLifeStageFilter(
    OutplantAllocation allocation,
    Set<String> requiredStageIds,
  ) {
    final lifeStageId = _lifeStageFromAllocation(allocation);
    return lifeStageId != null && requiredStageIds.contains(lifeStageId);
  }

  bool _matchesProvenanceTypeFilter(
    OutplantAllocation allocation,
    String requiredTypeId,
  ) {
    final provenanceId = _provenanceTypeFromAllocation(allocation);
    return provenanceId != null && provenanceId == requiredTypeId;
  }

  bool _matchesAnyProvenanceTypeFilter(
    OutplantAllocation allocation,
    Set<String> requiredTypeIds,
  ) {
    final provenanceId = _provenanceTypeFromAllocation(allocation);
    return provenanceId != null && requiredTypeIds.contains(provenanceId);
  }

  String? _lifeStageFromAllocation(OutplantAllocation allocation) {
    final snapshotStage = _normalizeLifeStageId(
      _metadataString(allocation.snapshot, 'lifeStageId'),
    );
    if (snapshotStage != null) return snapshotStage;
    final organism = allocation.organismId.isNotEmpty
        ? state.coralCache[allocation.organismId]
        : null;
    final lifeStageId = organism?.lifeStageId;
    return _normalizeLifeStageId(lifeStageId);
  }

  String? _provenanceTypeFromAllocation(OutplantAllocation allocation) {
    final snapshotType = _normalizeProvenanceType(
      _metadataString(allocation.snapshot, 'provenanceType'),
    );
    if (snapshotType != null) return snapshotType;
    final genetId = allocation.genetId;
    final genet = (genetId != null && genetId.isNotEmpty)
        ? state.genetCache[genetId]
        : null;
    return _provenanceTypeFromGenet(genet);
  }

  String? _provenanceTypeFromGenet(ProvenanceRecord? genet) {
    if (genet == null) return null;
    return genet.provenanceTypeId;
  }

  String? _normalizeLifeStageId(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = LifeStageX.tryParse(value);
    return parsed?.id ?? value.trim();
  }

  String? _normalizeProvenanceType(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = ProvenanceTypeX.tryParse(value);
    return parsed?.metadata.id ?? value.trim();
  }

  String _lifeStageDisplay(String value) {
    return LifeStageX.tryParse(value)?.displayName ?? value;
  }

  String _provenanceTypeDisplay(String value) {
    return ProvenanceTypeX.tryParse(value)?.displayName ?? value;
  }

  String? _metadataString(Map<String, dynamic>? source, String key) {
    if (source == null || source.isEmpty) return null;
    final value = source[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  OrganismKind? _organismKindForEvent(OutplantEvent event) {
    final raw = event.metadata == null ? null : event.metadata!['organismKind'];
    if (raw == null) return null;
    return OrganismKindX.tryParse(raw.toString());
  }

  Map<String, dynamic> _createRow(
    OutplantEvent event,
    OutplantAllocation allocation,
  ) {
    final genetId = allocation.genetId;
    final genet = (genetId != null && genetId.isNotEmpty)
        ? state.genetCache[genetId]
        : null;
    final genetLabel = genet?.displayName.trim();
    final genetDisplay =
        (genetLabel != null && genetLabel.isNotEmpty)
            ? genetLabel
            : (genetId ?? '');
    final createdAt = _tryParseCreatedAt(event.createdAt);

    // Get life stage from allocation snapshot or organism record
    final lifeStageId = _lifeStageFromAllocation(allocation);
    final lifeStageDisplay = lifeStageId != null
        ? _lifeStageDisplay(lifeStageId)
        : '';

    // Get physical form from allocation snapshot
    final physicalFormId = _metadataString(allocation.snapshot, 'physicalFormId');
    final physicalFormDisplay = physicalFormId != null
        ? _formatPhysicalFormId(physicalFormId)
        : '';

    // Get attachment method from event
    final attachmentMethod = AttachmentMethod.maybeFromId(
      event.attachmentMethodId,
    );
    final attachmentMethodDisplay = attachmentMethod?.name ?? '';

    final organizationDomain = _eventRepository.organization.domain;
    final locationLabel = allocation.groupPath != null &&
            allocation.groupPath!.isNotEmpty
        ? LocationDisplayService.formatFromPath(
            allocation.groupPath,
            organizationDomain: organizationDomain,
            fallback: state.siteNameIndex[event.siteId] ?? event.siteId,
          )
        : LocationDisplayService.formatFromEvent(
            event,
            organizationDomain: organizationDomain,
            fallback: state.siteNameIndex[event.siteId] ?? event.siteId,
          );

    return {
      'date': createdAt != null ? _formatDate(createdAt) : '',
      'event': event.name,
      'location': locationLabel,
      'plot': allocation.groupName ?? '',
      'coral': allocation.recordName,
      'species': _speciesName(allocation.speciesId),
      'genet': genetDisplay,
      'life_stage': lifeStageDisplay,
      'physical_form': physicalFormDisplay,
      'attachment_method': attachmentMethodDisplay,
      'quantity': allocation.quantity.toString(),
      'source': allocation.sourcePath,
      'comment': event.comment ?? '',
      'site_id': event.siteId,
      'plot_id': allocation.groupId ?? '',
      'plot_path': allocation.groupPath ?? '',
      'species_id': allocation.speciesId,
      'genet_id': allocation.genetId,
      'record_url_path':
          allocation.snapshot?['urlPath'] ??
          allocation.snapshot?['url_path'] ??
          '',
      'provenance_type_id': genet?.provenanceTypeId ?? '',
      'structure_path': allocation.sourcePath,
      'coral_id': allocation.organismId,
      'tag': allocation.tagName ?? allocation.tagId ?? '',
      'life_stage_id': lifeStageId ?? '',
      'physical_form_id': physicalFormId ?? '',
      'attachment_method_id': event.attachmentMethodId ?? '',
    };
  }

  /// Formats a physical form ID (snake_case) to display name (Title Case)
  static String _formatPhysicalFormId(String id) {
    return id
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  DateTime _eventDateForSort(OutplantEvent event) {
    return _tryParseCreatedAt(event.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _tryParseCreatedAt(String createdAt) {
    if (createdAt.isEmpty ||
        createdAt == Missing.string ||
        createdAt == Missing.dateTimeString) {
      return null;
    }
    return DateTime.tryParse(createdAt);
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin
}
