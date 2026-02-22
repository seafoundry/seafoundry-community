// @tier: community
part of 'public_holdings_map_cubit.dart';

/// State for the public holdings map screen.
///
/// Manages CRC historical data filters and loading states.
class PublicHoldingsMapState extends Equatable {
  const PublicHoldingsMapState({
    this.crcPoints = const [],
    this.filterOptions = const HistoricalFilterOptions(),
    this.availableYears = const [],
    this.availableGenets = const [],
    this.selectedRegion,
    this.selectedReef,
    this.selectedSpecies,
    this.selectedYear,
    this.selectedGenet,
    this.yearFilteredSiteIds,
    this.genetFilteredSiteIds,
    this.isLoadingCrcData = false,
    this.isLoadingYears = false,
    this.isLoadingGenets = false,
    this.isLoadingYearFilter = false,
    this.isLoadingGenetFilter = false,
    this.loadingStatus = 'Loading map data...',
    this.crcError,
    this.genetSearchError,
    // Filter toggles
    this.showHoldings = true,
    this.showOutplants = true,
    this.showCrcData = true,
    // UI state
    this.mapGesturesEnabled = true,
  });

  /// All CRC historical impact points (unfiltered source data).
  final List<HistoricalImpactPoint> crcPoints;

  /// Available filter options derived from CRC data.
  final HistoricalFilterOptions filterOptions;

  /// Available years for year filter dropdown.
  final List<int> availableYears;

  /// Available genets for genet autocomplete.
  final List<String> availableGenets;

  // Selected filter values
  final String? selectedRegion;
  final String? selectedReef;
  final String? selectedSpecies;
  final int? selectedYear;
  final String? selectedGenet;

  /// Site IDs that match the selected year filter.
  final Set<String>? yearFilteredSiteIds;

  /// Site IDs that match the selected genet filter.
  final Set<String>? genetFilteredSiteIds;

  // Loading states
  final bool isLoadingCrcData;
  final bool isLoadingYears;
  final bool isLoadingGenets;
  final bool isLoadingYearFilter;
  final bool isLoadingGenetFilter;

  /// Loading status message for CRC data.
  final String loadingStatus;

  /// Error message for CRC data loading.
  final String? crcError;

  /// Error message for genet search validation.
  final String? genetSearchError;

  // Filter toggles for map layer visibility
  /// Whether to show holdings on the map.
  final bool showHoldings;

  /// Whether to show outplants on the map.
  final bool showOutplants;

  /// Whether to show CRC data on the map.
  final bool showCrcData;

  // UI state
  /// Whether map gestures (zoom, pan) are enabled.
  /// Disabled when mouse is over the filter panel.
  final bool mapGesturesEnabled;

  /// Returns true if any filter is currently loading.
  bool get isFilterLoading => isLoadingYearFilter || isLoadingGenetFilter;

  /// Returns true if any filter is active.
  bool get hasActiveFilters =>
      selectedRegion != null ||
      selectedReef != null ||
      selectedSpecies != null ||
      selectedYear != null ||
      selectedGenet != null;

  PublicHoldingsMapState copyWith({
    List<HistoricalImpactPoint>? crcPoints,
    HistoricalFilterOptions? filterOptions,
    List<int>? availableYears,
    List<String>? availableGenets,
    String? selectedRegion,
    bool clearRegion = false,
    String? selectedReef,
    bool clearReef = false,
    String? selectedSpecies,
    bool clearSpecies = false,
    int? selectedYear,
    bool clearYear = false,
    String? selectedGenet,
    bool clearGenet = false,
    Set<String>? yearFilteredSiteIds,
    bool clearYearFilteredSiteIds = false,
    Set<String>? genetFilteredSiteIds,
    bool clearGenetFilteredSiteIds = false,
    bool? isLoadingCrcData,
    bool? isLoadingYears,
    bool? isLoadingGenets,
    bool? isLoadingYearFilter,
    bool? isLoadingGenetFilter,
    String? loadingStatus,
    String? crcError,
    bool clearCrcError = false,
    String? genetSearchError,
    bool clearGenetSearchError = false,
    bool? showHoldings,
    bool? showOutplants,
    bool? showCrcData,
    bool? mapGesturesEnabled,
  }) {
    return PublicHoldingsMapState(
      crcPoints: crcPoints ?? this.crcPoints,
      filterOptions: filterOptions ?? this.filterOptions,
      availableYears: availableYears ?? this.availableYears,
      availableGenets: availableGenets ?? this.availableGenets,
      selectedRegion: clearRegion ? null : selectedRegion ?? this.selectedRegion,
      selectedReef: clearReef ? null : selectedReef ?? this.selectedReef,
      selectedSpecies:
          clearSpecies ? null : selectedSpecies ?? this.selectedSpecies,
      selectedYear: clearYear ? null : selectedYear ?? this.selectedYear,
      selectedGenet: clearGenet ? null : selectedGenet ?? this.selectedGenet,
      yearFilteredSiteIds: clearYearFilteredSiteIds
          ? null
          : yearFilteredSiteIds ?? this.yearFilteredSiteIds,
      genetFilteredSiteIds: clearGenetFilteredSiteIds
          ? null
          : genetFilteredSiteIds ?? this.genetFilteredSiteIds,
      isLoadingCrcData: isLoadingCrcData ?? this.isLoadingCrcData,
      isLoadingYears: isLoadingYears ?? this.isLoadingYears,
      isLoadingGenets: isLoadingGenets ?? this.isLoadingGenets,
      isLoadingYearFilter: isLoadingYearFilter ?? this.isLoadingYearFilter,
      isLoadingGenetFilter: isLoadingGenetFilter ?? this.isLoadingGenetFilter,
      loadingStatus: loadingStatus ?? this.loadingStatus,
      crcError: clearCrcError ? null : crcError ?? this.crcError,
      genetSearchError:
          clearGenetSearchError ? null : genetSearchError ?? this.genetSearchError,
      showHoldings: showHoldings ?? this.showHoldings,
      showOutplants: showOutplants ?? this.showOutplants,
      showCrcData: showCrcData ?? this.showCrcData,
      mapGesturesEnabled: mapGesturesEnabled ?? this.mapGesturesEnabled,
    );
  }

  @override
  List<Object?> get props => [
        crcPoints,
        filterOptions,
        availableYears,
        availableGenets,
        selectedRegion,
        selectedReef,
        selectedSpecies,
        selectedYear,
        selectedGenet,
        yearFilteredSiteIds,
        genetFilteredSiteIds,
        isLoadingCrcData,
        isLoadingYears,
        isLoadingGenets,
        isLoadingYearFilter,
        isLoadingGenetFilter,
        loadingStatus,
        crcError,
        genetSearchError,
        showHoldings,
        showOutplants,
        showCrcData,
        mapGesturesEnabled,
      ];
}
