// @tier: community
part of 'monitoring_spreadsheet_cubit.dart';

class MonitoringSpreadsheetState extends Equatable {
  const MonitoringSpreadsheetState({
    this.isLoading = false,
    this.errorMessage,
    this.allEvents = const [],
    this.filteredEvents = const [],
    this.siteNameIndex = const {},
    this.organizationDomain,
    this.speciesByGenet = const {},
    this.genetLabels = const {},
    this.selectedEventId,
    this.siteFilter,
    this.speciesFilter,
    this.genetFilter,
    this.search,
    this.dateRange,
    this.eventReloadToken = 0,
    this.entryReloadToken = 0,
    this.organismFilter = OrganismKind.coral,
    this.holdingSummaries = const [],
  });

  final bool isLoading;
  final String? errorMessage;
  final List<MonitoringEventRecord> allEvents;
  final List<MonitoringEventRecord> filteredEvents;
  final Map<String, String> siteNameIndex;
  final String? organizationDomain;
  final Map<String, String> speciesByGenet;
  final Map<String, String> genetLabels;
  final String? selectedEventId;
  final String? siteFilter;
  final String? speciesFilter;
  final String? genetFilter;
  final String? search;
  final DateTimeRange? dateRange;
  final int eventReloadToken;
  final int entryReloadToken;
  final OrganismKind organismFilter;
  final List<HoldingSummary> holdingSummaries;

  MonitoringSpreadsheetState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<MonitoringEventRecord>? allEvents,
    List<MonitoringEventRecord>? filteredEvents,
    Map<String, String>? siteNameIndex,
    String? organizationDomain,
    Map<String, String>? speciesByGenet,
    Map<String, String>? genetLabels,
    String? selectedEventId,
    String? siteFilter,
    String? speciesFilter,
    String? genetFilter,
    String? search,
    DateTimeRange? dateRange,
    bool clearDate = false,
    int? eventReloadToken,
    int? entryReloadToken,
    OrganismKind? organismFilter,
    List<HoldingSummary>? holdingSummaries,
  }) {
    return MonitoringSpreadsheetState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      allEvents: allEvents ?? this.allEvents,
      filteredEvents: filteredEvents ?? this.filteredEvents,
      siteNameIndex: siteNameIndex ?? this.siteNameIndex,
      organizationDomain: organizationDomain ?? this.organizationDomain,
      speciesByGenet: speciesByGenet ?? this.speciesByGenet,
      genetLabels: genetLabels ?? this.genetLabels,
      selectedEventId: selectedEventId ?? this.selectedEventId,
      siteFilter: siteFilter ?? this.siteFilter,
      speciesFilter: speciesFilter ?? this.speciesFilter,
      genetFilter: genetFilter ?? this.genetFilter,
      search: search ?? this.search,
      dateRange: clearDate ? null : dateRange ?? this.dateRange,
      eventReloadToken: eventReloadToken ?? this.eventReloadToken,
      entryReloadToken: entryReloadToken ?? this.entryReloadToken,
      organismFilter: organismFilter ?? this.organismFilter,
      holdingSummaries: holdingSummaries ?? this.holdingSummaries,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        errorMessage,
        allEvents,
        filteredEvents,
        siteNameIndex,
        organizationDomain,
        speciesByGenet,
        genetLabels,
        selectedEventId,
        siteFilter,
        speciesFilter,
        genetFilter,
        search,
        dateRange,
        eventReloadToken,
        entryReloadToken,
        organismFilter,
        holdingSummaries,
      ];
}
