// @tier: community
part of 'observations_spreadsheet_cubit.dart';

class ObservationsSpreadsheetState extends Equatable {
  const ObservationsSpreadsheetState({
    this.isLoadingGenets = false,
    this.errorMessage,
    this.selectedStructureIds = const {},
    this.selectedSiteIds = const {},
    this.selectedSpeciesIds = const {},
    this.selectedGenetIds = const {},
    this.selectedLifeStageIds = const {},
    this.selectedProvenanceTypeIds = const {},
    this.selectedDateRange,
    this.structureIds = const {},
    this.siteIds = const {},
    this.lifeStageIds = const {},
    this.provenanceTypes = const {},
    this.speciesLookup = const {},
    this.genetLookup = const {},
    this.siteLookup = const {},
    this.genetRecords = const {},
    this.coralCache = const {},
    this.userIdToName = const {},
    this.reloadToken = 0,
    this.organismFilter = OrganismKind.coral,
    this.selectedObservationTypes = const {},
    this.observationTypes = const {},
  });

  final bool isLoadingGenets;
  final String? errorMessage;
  final Set<String> selectedStructureIds;
  final Set<String> selectedSiteIds;
  final Set<String> selectedSpeciesIds;
  final Set<String> selectedGenetIds;
  final Set<String> selectedLifeStageIds;
  final Set<String> selectedProvenanceTypeIds;
  final DateTimeRange? selectedDateRange;
  final Set<String> structureIds;
  final Set<String> siteIds;
  final Set<String> lifeStageIds;
  final Set<String> provenanceTypes;
  final Map<String, String> speciesLookup;
  final Map<String, String> genetLookup;
  final Map<String, String> siteLookup;
  final Map<String, Genet> genetRecords;
  final Map<String, OrganismRecord> coralCache;
  final Map<String, String> userIdToName;
  final int reloadToken;
  final OrganismKind organismFilter;
  final Set<String> selectedObservationTypes;
  final Set<String> observationTypes;

  ObservationsSpreadsheetState copyWith({
    bool? isLoadingGenets,
    String? errorMessage,
    bool clearError = false,
    Set<String>? selectedStructureIds,
    Set<String>? selectedSiteIds,
    Set<String>? selectedSpeciesIds,
    Set<String>? selectedGenetIds,
    Set<String>? selectedLifeStageIds,
    Set<String>? selectedProvenanceTypeIds,
    DateTimeRange? selectedDateRange,
    bool clearDateRange = false,
    Set<String>? structureIds,
    Set<String>? siteIds,
    Set<String>? lifeStageIds,
    Set<String>? provenanceTypes,
    Map<String, String>? speciesLookup,
    Map<String, String>? genetLookup,
    Map<String, String>? siteLookup,
    Map<String, Genet>? genetRecords,
    Map<String, OrganismRecord>? coralCache,
    Map<String, String>? userIdToName,
    int? reloadToken,
    OrganismKind? organismFilter,
    Set<String>? selectedObservationTypes,
    Set<String>? observationTypes,
  }) {
    return ObservationsSpreadsheetState(
      isLoadingGenets: isLoadingGenets ?? this.isLoadingGenets,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      selectedStructureIds: selectedStructureIds ?? this.selectedStructureIds,
      selectedSiteIds: selectedSiteIds ?? this.selectedSiteIds,
      selectedSpeciesIds: selectedSpeciesIds ?? this.selectedSpeciesIds,
      selectedGenetIds: selectedGenetIds ?? this.selectedGenetIds,
      selectedLifeStageIds: selectedLifeStageIds ?? this.selectedLifeStageIds,
      selectedProvenanceTypeIds:
          selectedProvenanceTypeIds ?? this.selectedProvenanceTypeIds,
      selectedDateRange: clearDateRange
          ? null
          : selectedDateRange ?? this.selectedDateRange,
      structureIds: structureIds ?? this.structureIds,
      siteIds: siteIds ?? this.siteIds,
      lifeStageIds: lifeStageIds ?? this.lifeStageIds,
      provenanceTypes: provenanceTypes ?? this.provenanceTypes,
      speciesLookup: speciesLookup ?? this.speciesLookup,
      genetLookup: genetLookup ?? this.genetLookup,
      siteLookup: siteLookup ?? this.siteLookup,
      genetRecords: genetRecords ?? this.genetRecords,
      coralCache: coralCache ?? this.coralCache,
      userIdToName: userIdToName ?? this.userIdToName,
      reloadToken: reloadToken ?? this.reloadToken,
      organismFilter: organismFilter ?? this.organismFilter,
      selectedObservationTypes:
          selectedObservationTypes ?? this.selectedObservationTypes,
      observationTypes: observationTypes ?? this.observationTypes,
    );
  }

  @override
  List<Object?> get props => [
    isLoadingGenets,
    errorMessage,
    selectedStructureIds,
    selectedSiteIds,
    selectedSpeciesIds,
    selectedGenetIds,
    selectedLifeStageIds,
    selectedProvenanceTypeIds,
    selectedDateRange,
    structureIds,
    siteIds,
    lifeStageIds,
    provenanceTypes,
    speciesLookup,
    genetLookup,
    siteLookup,
    genetRecords,
    coralCache,
    userIdToName,
    reloadToken,
    organismFilter,
    selectedObservationTypes,
    observationTypes,
  ];
}
