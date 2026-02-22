// @tier: community
part of 'outplant_events_spreadsheet_cubit.dart';

class OutplantEventsSpreadsheetState extends Equatable {
  const OutplantEventsSpreadsheetState({
    this.isLoading = true,
    this.errorMessage,
    this.streamEvents = const [],
    this.fetchedEvents = const {},
    this.filteredEvents = const [],
    this.selectedSiteIds = const {},
    this.selectedStructureIds = const {},
    this.selectedSpeciesIds = const {},
    this.selectedGenetIds = const {},
    this.selectedLifeStageIds = const {},
    this.selectedProvenanceTypeIds = const {},
    this.selectedEventIds = const {},
    this.selectedDateRange,
    this.searchTerm,
    this.widgetSiteFilter,
    this.widgetStructureFilter,
    this.widgetSpeciesFilter,
    this.widgetGenetFilter,
    this.widgetLifeStageFilter,
    this.widgetProvenanceTypeFilter,
    this.widgetDateRange,
    this.widgetSearchTerm,
    this.siteNameIndex = const {},
    this.coralCache = const {},
    this.genetCache = const {},
    this.outplantSites = const [],
    this.reloadToken = 0,
    this.organismFilter = OrganismKind.coral,
    this.holdingSummaries = const [],
  });

  final bool isLoading;
  final String? errorMessage;
  final List<OutplantEvent> streamEvents;
  final Map<String, OutplantEvent> fetchedEvents;
  final List<OutplantEvent> filteredEvents;
  final Set<String> selectedSiteIds;
  final Set<String> selectedStructureIds;
  final Set<String> selectedSpeciesIds;
  final Set<String> selectedGenetIds;
  final Set<String> selectedLifeStageIds;
  final Set<String> selectedProvenanceTypeIds;
  final Set<String> selectedEventIds;
  final DateTimeRange? selectedDateRange;
  final String? searchTerm;
  final String? widgetSiteFilter;
  final String? widgetStructureFilter;
  final String? widgetSpeciesFilter;
  final String? widgetGenetFilter;
  final String? widgetLifeStageFilter;
  final String? widgetProvenanceTypeFilter;
  final DateTimeRange? widgetDateRange;
  final String? widgetSearchTerm;
  final Map<String, String> siteNameIndex;
  final Map<String, OrganismRecord?> coralCache;
  final Map<String, ProvenanceRecord?> genetCache;
  final List<Site> outplantSites;
  final int reloadToken;
  final OrganismKind organismFilter;
  final List<HoldingSummary> holdingSummaries;

  OutplantEventsSpreadsheetState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<OutplantEvent>? streamEvents,
    Map<String, OutplantEvent>? fetchedEvents,
    List<OutplantEvent>? filteredEvents,
    Set<String>? selectedSiteIds,
    Set<String>? selectedStructureIds,
    Set<String>? selectedSpeciesIds,
    Set<String>? selectedGenetIds,
    Set<String>? selectedLifeStageIds,
    Set<String>? selectedProvenanceTypeIds,
    Set<String>? selectedEventIds,
    DateTimeRange? selectedDateRange,
    bool clearDateRange = false,
    String? searchTerm,
    bool clearSearchTerm = false,
    String? widgetSiteFilter,
    String? widgetStructureFilter,
    String? widgetSpeciesFilter,
    String? widgetGenetFilter,
    String? widgetLifeStageFilter,
    String? widgetProvenanceTypeFilter,
    DateTimeRange? widgetDateRange,
    String? widgetSearchTerm,
    Map<String, String>? siteNameIndex,
    Map<String, OrganismRecord?>? coralCache,
    Map<String, ProvenanceRecord?>? genetCache,
    List<Site>? outplantSites,
    int? reloadToken,
    OrganismKind? organismFilter,
    List<HoldingSummary>? holdingSummaries,
  }) {
    return OutplantEventsSpreadsheetState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      streamEvents: streamEvents ?? this.streamEvents,
      fetchedEvents: fetchedEvents ?? this.fetchedEvents,
      filteredEvents: filteredEvents ?? this.filteredEvents,
      selectedSiteIds: selectedSiteIds ?? this.selectedSiteIds,
      selectedStructureIds: selectedStructureIds ?? this.selectedStructureIds,
      selectedSpeciesIds: selectedSpeciesIds ?? this.selectedSpeciesIds,
      selectedGenetIds: selectedGenetIds ?? this.selectedGenetIds,
      selectedLifeStageIds: selectedLifeStageIds ?? this.selectedLifeStageIds,
      selectedProvenanceTypeIds:
          selectedProvenanceTypeIds ?? this.selectedProvenanceTypeIds,
      selectedEventIds: selectedEventIds ?? this.selectedEventIds,
      selectedDateRange: clearDateRange
          ? null
          : selectedDateRange ?? this.selectedDateRange,
      searchTerm: clearSearchTerm ? null : searchTerm ?? this.searchTerm,
      widgetSiteFilter: widgetSiteFilter ?? this.widgetSiteFilter,
      widgetStructureFilter:
          widgetStructureFilter ?? this.widgetStructureFilter,
      widgetSpeciesFilter: widgetSpeciesFilter ?? this.widgetSpeciesFilter,
      widgetGenetFilter: widgetGenetFilter ?? this.widgetGenetFilter,
      widgetLifeStageFilter:
          widgetLifeStageFilter ?? this.widgetLifeStageFilter,
      widgetProvenanceTypeFilter:
          widgetProvenanceTypeFilter ?? this.widgetProvenanceTypeFilter,
      widgetDateRange: widgetDateRange ?? this.widgetDateRange,
      widgetSearchTerm: widgetSearchTerm ?? this.widgetSearchTerm,
      siteNameIndex: siteNameIndex ?? this.siteNameIndex,
      coralCache: coralCache ?? this.coralCache,
      genetCache: genetCache ?? this.genetCache,
      outplantSites: outplantSites ?? this.outplantSites,
      reloadToken: reloadToken ?? this.reloadToken,
      organismFilter: organismFilter ?? this.organismFilter,
      holdingSummaries: holdingSummaries ?? this.holdingSummaries,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    errorMessage,
    streamEvents,
    fetchedEvents,
    filteredEvents,
    selectedSiteIds,
    selectedStructureIds,
    selectedSpeciesIds,
    selectedGenetIds,
    selectedLifeStageIds,
    selectedProvenanceTypeIds,
    selectedEventIds,
    selectedDateRange,
    searchTerm,
    widgetSiteFilter,
    widgetStructureFilter,
    widgetSpeciesFilter,
    widgetGenetFilter,
    widgetLifeStageFilter,
    widgetProvenanceTypeFilter,
    widgetDateRange,
    widgetSearchTerm,
    siteNameIndex,
    coralCache,
    genetCache,
    outplantSites,
    reloadToken,
    organismFilter,
    holdingSummaries,
  ];
}
