// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/inventory/holding_summary.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/monitoring_event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/holding_summary_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/monitoring_growth_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';

part 'monitoring_spreadsheet_state.dart';

/// Aggregates monitoring entries for the spreadsheet view, exposing refresh/filter hooks.
class MonitoringSpreadsheetCubit extends SafeCubit<MonitoringSpreadsheetState> {
  MonitoringSpreadsheetCubit({
    required SiteRepository siteRepository,
    required ProvenanceRepository provenanceRepository,
    required OrganizationRepository organizationRepository,
    required FirebaseFirestore firestore,
    required CurrentUserState currentUserState,
    MonitoringGrowthService? growthService,
    HoldingSummaryService? holdingSummaryService,
    OrganismKind organismKind = OrganismKind.coral,
    Tier tier = Tier.pro,
    bool monitoringFeatureEnabled = true,
  }) : _siteRepository = siteRepository,
       _provenanceRepository = provenanceRepository,
       _organizationRepository = organizationRepository,
       _firestore = firestore,
       _currentUserState = currentUserState,
       _growthService = growthService ?? const MonitoringGrowthService(),
       _holdingSummaryService = holdingSummaryService,
       _tier = tier,
       _monitoringFeatureEnabled = monitoringFeatureEnabled,
       super(MonitoringSpreadsheetState(organismFilter: organismKind));

  final SiteRepository _siteRepository;
  final ProvenanceRepository _provenanceRepository;
  final OrganizationRepository _organizationRepository;
  final FirebaseFirestore _firestore;
  final CurrentUserState _currentUserState;
  final MonitoringGrowthService _growthService;
  final HoldingSummaryService? _holdingSummaryService;
  final Tier _tier;
  final bool _monitoringFeatureEnabled;
  MonitoringEventRepository? _monitoringEventRepository;
  Set<String> _monitoringOnlySiteIds = const {};

  MonitoringEventRepository get monitoringEventRepository =>
      _monitoringEventRepository!;
  MonitoringGrowthService get growthService => _growthService;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final siteIndex = await _loadSiteIndex();
      final genetMetadata = await _loadGenetMetadata();
      final speciesByGenet = genetMetadata.$1;
      final genetLabels = genetMetadata.$2;
      final resolved = await _resolveCurrentUser();
      if (resolved == null) {
        throw StateError('Organization or User not found');
      }
      final (organization, user) = resolved;
      _monitoringEventRepository = MonitoringEventRepository(
        organization: organization,
        user: user,
        firestore: _firestore,
        featureEnabled: _monitoringFeatureEnabled,
      );

      final events = await PerformanceAnalyzer.measure(
        'MonitoringSpreadsheet.initialize',
        () => _monitoringEventRepository!.fetchMonitoringEvents(),
        metadata: {
          'organizationId': organization.id,
          'operation': 'data_loading',
        },
      );
      final scopedEvents = _filterEventsForTier(events);
      final enrichedSiteIndex = _mergeSiteNames(siteIndex, scopedEvents);
      final filtered = _filterEvents(
        events: scopedEvents,
        site: null,
        species: null,
        genet: null,
        search: null,
        dateRange: null,
        speciesByGenet: speciesByGenet,
        genetLabels: genetLabels,
        organismFilter: state.organismFilter,
      );

      emit(
        state.copyWith(
          isLoading: false,
          siteNameIndex: enrichedSiteIndex,
          organizationDomain: organization.domain,
          speciesByGenet: speciesByGenet,
          genetLabels: genetLabels,
          allEvents: scopedEvents,
          filteredEvents: filtered,
          selectedEventId: filtered.isEmpty ? null : filtered.first.id,
          eventReloadToken: state.eventReloadToken + 1,
          entryReloadToken: state.entryReloadToken + 1,
        ),
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load monitoring events',
        error,
        stackTrace,
      );
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }

  Future<void> reloadEvents() async {
    final repository = _monitoringEventRepository;
    if (repository == null) return;
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final events = await repository.fetchMonitoringEvents();
      final scopedEvents = _filterEventsForTier(events);
      final siteIndex = _mergeSiteNames(state.siteNameIndex, scopedEvents);
      final filtered = _filterEvents(
        events: scopedEvents,
        site: state.siteFilter,
        species: state.speciesFilter,
        genet: state.genetFilter,
        search: state.search,
        dateRange: state.dateRange,
        speciesByGenet: state.speciesByGenet,
        genetLabels: state.genetLabels,
        organismFilter: state.organismFilter,
      );
      emit(
        state.copyWith(
          isLoading: false,
          allEvents: scopedEvents,
          filteredEvents: filtered,
          siteNameIndex: siteIndex,
          organizationDomain: state.organizationDomain,
          selectedEventId: _resolveSelectedEventId(filtered),
          eventReloadToken: state.eventReloadToken + 1,
          entryReloadToken: state.entryReloadToken + 1,
        ),
      );
      unawaited(_refreshHoldingSummaries());
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to reload monitoring events',
        error,
        stackTrace,
      );
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }

  void applyFilters({
    String? site,
    String? species,
    String? genet,
    String? search,
    DateTimeRange? dateRange,
    bool clearDate = false,
    bool updateSite = false,
    bool updateSpecies = false,
    bool updateGenet = false,
    bool updateSearch = false,
  }) {
    String? normalize(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    String? normalizeGenet(String? value) {
      final normalized = normalize(value);
      if (normalized == null) return null;
      return state.genetLabels[normalized] ?? normalized;
    }

    final updatedSite = updateSite ? normalize(site) : state.siteFilter;
    final updatedSpecies = updateSpecies
        ? normalize(species)
        : state.speciesFilter;
    final updatedGenet = updateGenet
        ? normalizeGenet(genet)
        : state.genetFilter;
    final updatedSearch = updateSearch ? normalize(search) : state.search;
    final updatedDate = clearDate ? null : dateRange ?? state.dateRange;

    final filtered = _filterEvents(
      events: state.allEvents,
      site: updatedSite,
      species: updatedSpecies,
      genet: updatedGenet,
      search: updatedSearch,
      dateRange: updatedDate,
      speciesByGenet: state.speciesByGenet,
      genetLabels: state.genetLabels,
      organismFilter: state.organismFilter,
    );

    emit(
      state.copyWith(
        siteFilter: updatedSite,
        speciesFilter: updatedSpecies,
        genetFilter: updatedGenet,
        search: updatedSearch,
        dateRange: updatedDate,
        clearDate: clearDate,
        filteredEvents: filtered,
        selectedEventId: _resolveSelectedEventId(filtered),
        eventReloadToken: state.eventReloadToken + 1,
        entryReloadToken: state.entryReloadToken + 1,
      ),
    );
    unawaited(_refreshHoldingSummaries());
  }

  void setOrganismFilter(OrganismKind kind) {
    if (state.organismFilter == kind) return;
    final filtered = _filterEvents(
      events: state.allEvents,
      site: state.siteFilter,
      species: state.speciesFilter,
      genet: state.genetFilter,
      search: state.search,
      dateRange: state.dateRange,
      speciesByGenet: state.speciesByGenet,
      genetLabels: state.genetLabels,
      organismFilter: kind,
    );
    emit(
      state.copyWith(
        organismFilter: kind,
        filteredEvents: filtered,
        selectedEventId: _resolveSelectedEventId(filtered),
        eventReloadToken: state.eventReloadToken + 1,
        entryReloadToken: state.entryReloadToken + 1,
      ),
    );
    unawaited(_refreshHoldingSummaries());
  }

  void selectEvent(String? eventId) {
    if (eventId == state.selectedEventId) return;
    emit(
      state.copyWith(
        selectedEventId: eventId,
        entryReloadToken: state.entryReloadToken + 1,
      ),
    );
  }

  Future<Map<String, String>> _loadSiteIndex() async {
    final siteMap = <String, String>{};
    final sites = await _siteRepository.getAll();
    // Limit Community tier to monitoring-only sites; Pro/Scale include all sites.
    _monitoringOnlySiteIds = sites
        .where((site) => site.siteType.isMonitoringOnly)
        .map((site) => site.id)
        .toSet();
    for (final site in sites) {
      if (_tier == Tier.community &&
          !_monitoringOnlySiteIds.contains(site.id)) {
        continue;
      }
      siteMap[site.id] = site.name;
    }
    return siteMap;
  }

  List<MonitoringEventRecord> _filterEventsForTier(
    List<MonitoringEventRecord> events,
  ) {
    if (_tier != Tier.community) {
      return events;
    }
    if (_monitoringOnlySiteIds.isEmpty) {
      return const <MonitoringEventRecord>[];
    }
    return events
        .where((event) => _monitoringOnlySiteIds.contains(event.siteId))
        .toList();
  }

  Future<(Map<String, String>, Map<String, String>)>
  _loadGenetMetadata() async {
    final genets = await _provenanceRepository.getAll();
    final speciesByGenet = <String, String>{};
    final genetLabels = <String, String>{};
    for (final genet in genets) {
      speciesByGenet[genet.id] = genet.speciesId;
      final label = genet.displayName.trim();
      genetLabels[genet.id] = label.isNotEmpty ? label : genet.id;
    }
    return (speciesByGenet, genetLabels);
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
      emit(state.copyWith(holdingSummaries: summaries));
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'MonitoringSpreadsheet: holding summary refresh failed: $error',
      );
      LoggingService.instance.trace(
        'MonitoringSpreadsheet holding summary stack trace',
        stackTrace,
      );
    }
  }

  Future<(Organization, User)?> _resolveCurrentUser() async {
    switch (_currentUserState) {
      case CurrentUserLoaded(:final organization, :final user):
        return (organization, user);
      case CurrentUserOrganizationUninitialized(:final user):
        final organization = await _organizationRepository.getById(
          user.organizationId,
        );
        if (organization != null) {
          return (organization, user);
        }
        return null;
      default:
        return null;
    }
  }

  Map<String, String> _mergeSiteNames(
    Map<String, String> existing,
    List<MonitoringEventRecord> events,
  ) {
    final merged = Map<String, String>.from(existing);
    for (final event in events) {
      final siteId = _eventSiteId(event);
      if (siteId != null && siteId.isNotEmpty) {
        final existingName = merged[siteId];
        if ((existingName == null || existingName.isEmpty) &&
            (event.siteNameSnapshot?.isNotEmpty ?? false)) {
          merged[siteId] = event.siteNameSnapshot!;
        }
      }
    }
    return merged;
  }

  List<MonitoringEventRecord> _filterEvents({
    required List<MonitoringEventRecord> events,
    required String? site,
    required String? species,
    required String? genet,
    required String? search,
    required DateTimeRange? dateRange,
    required Map<String, String> speciesByGenet,
    required Map<String, String> genetLabels,
    required OrganismKind organismFilter,
  }) {
    var filtered = events
        .where((event) => _eventOrganism(event) == organismFilter)
        .toList();

    if (dateRange != null) {
      final start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
        999,
      );
      filtered = filtered.where((event) {
        final eventDate = DateTime.parse(event.createdAt);
        return !eventDate.isBefore(start) && !eventDate.isAfter(end);
      }).toList();
    }

    if (site != null && site.isNotEmpty) {
      filtered = filtered
          .where((event) => _eventSiteId(event) == site)
          .toList();
    }

    if (species != null && species.isNotEmpty) {
      filtered = filtered
          .where(
            (event) => event.entries.any(
              (entry) => speciesByGenet[entry.genetId] == species,
            ),
          )
          .toList();
    }

    if (genet != null && genet.isNotEmpty) {
      filtered = filtered
          .where(
            (event) => event.entries.any((entry) {
              final label = genetLabels[entry.genetId] ?? entry.genetId;
              return label == genet || entry.genetId == genet;
            }),
          )
          .toList();
    }

    if (search != null && search.isNotEmpty) {
      final query = search.toLowerCase();
      filtered = filtered.where((event) {
        final matchesSite = (event.siteNameSnapshot ?? '')
            .toLowerCase()
            .contains(query);
        final matchesNotes = (event.notes ?? '').toLowerCase().contains(query);
        final matchesEntry = event.entries.any(
          (entry) =>
              (genetLabels[entry.genetId] ?? entry.genetId)
                  .toLowerCase()
                  .contains(query) ||
              entry.genetId.toLowerCase().contains(query) ||
              (speciesByGenet[entry.genetId] ?? '').toLowerCase().contains(
                query,
              ) ||
              (entry.notes ?? '').toLowerCase().contains(query),
        );
        return matchesSite || matchesNotes || matchesEntry;
      }).toList();
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  String? _eventSiteId(MonitoringEventRecord event) {
    final directSiteId = event.siteId;
    if (directSiteId != null && directSiteId.isNotEmpty) {
      return directSiteId;
    }
    if (event.recordModelType == ModelType.site && event.recordId.isNotEmpty) {
      return event.recordId;
    }
    final measurements = event.measurements;
    if (measurements != null && measurements.isNotEmpty) {
      final fromCamel = measurements['siteId'];
      if (fromCamel is String && fromCamel.isNotEmpty) {
        return fromCamel;
      }
      final fromSnake = measurements['site_id'];
      if (fromSnake is String && fromSnake.isNotEmpty) {
        return fromSnake;
      }
    }
    return null;
  }

  OrganismKind _eventOrganism(MonitoringEventRecord event) {
    final raw =
        event.metadata?['organismKind'] ?? event.metadata?['organism_kind'];
    if (raw is String && raw.isNotEmpty) {
      final normalized = raw.toLowerCase();
      for (final kind in OrganismKind.values) {
        if (kind.name.toLowerCase() == normalized) {
          return kind;
        }
      }
    }
    return OrganismKind.coral;
  }

  String? _resolveSelectedEventId(List<MonitoringEventRecord> filtered) {
    if (filtered.isEmpty) return null;
    if (state.selectedEventId == null) {
      return filtered.first.id;
    }
    final exists = filtered.any((event) => event.id == state.selectedEventId);
    return exists ? state.selectedEventId : filtered.first.id;
  }
}
