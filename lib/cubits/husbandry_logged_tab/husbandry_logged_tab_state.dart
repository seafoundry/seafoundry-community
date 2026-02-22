// @tier: community
part of 'husbandry_logged_tab_cubit.dart';

class HusbandryLoggedTabState extends Equatable {
  const HusbandryLoggedTabState({
    this.organism = OrganismKind.coral,
    this.selectedStructureIds = const {},
    this.selectedSpeciesIds = const {},
    this.selectedGenetIds = const {},
    this.selectedSiteIds = const {},
    this.selectedLifeStageIds = const {},
    this.selectedProvenanceTypeIds = const {},
    this.selectedDateRange,
    this.speciesLookup = const {},
    this.genetLookup = const {},
    this.siteLookup = const {},
    this.structureOptions = const [],
    this.siteOptions = const [],
    this.speciesOptions = const [],
    this.genetOptions = const [],
    this.lifeStageOptions = const [],
    this.provenanceTypeOptions = const [],
    this.errorMessage,
  });

  final OrganismKind organism;
  final Set<String> selectedStructureIds;
  final Set<String> selectedSpeciesIds;
  final Set<String> selectedGenetIds;
  final Set<String> selectedSiteIds;
  final Set<String> selectedLifeStageIds;
  final Set<String> selectedProvenanceTypeIds;
  final DateTimeRange? selectedDateRange;
  final Map<String, String> speciesLookup;
  final Map<String, String> genetLookup;
  final Map<String, String> siteLookup;
  final List<String> structureOptions;
  final List<String> siteOptions;
  final List<String> speciesOptions;
  final List<String> genetOptions;
  final List<String> lifeStageOptions;
  final List<String> provenanceTypeOptions;
  final String? errorMessage;

  HusbandryLoggedTabState copyWith({
    OrganismKind? organism,
    Set<String>? selectedStructureIds,
    Set<String>? selectedSpeciesIds,
    Set<String>? selectedGenetIds,
    Set<String>? selectedSiteIds,
    Set<String>? selectedLifeStageIds,
    Set<String>? selectedProvenanceTypeIds,
    DateTimeRange? selectedDateRange,
    bool clearDateRange = false,
    Map<String, String>? speciesLookup,
    Map<String, String>? genetLookup,
    Map<String, String>? siteLookup,
    List<String>? structureOptions,
    List<String>? siteOptions,
    List<String>? speciesOptions,
    List<String>? genetOptions,
    List<String>? lifeStageOptions,
    List<String>? provenanceTypeOptions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HusbandryLoggedTabState(
      organism: organism ?? this.organism,
      selectedStructureIds: selectedStructureIds ?? this.selectedStructureIds,
      selectedSpeciesIds: selectedSpeciesIds ?? this.selectedSpeciesIds,
      selectedGenetIds: selectedGenetIds ?? this.selectedGenetIds,
      selectedSiteIds: selectedSiteIds ?? this.selectedSiteIds,
      selectedLifeStageIds: selectedLifeStageIds ?? this.selectedLifeStageIds,
      selectedProvenanceTypeIds:
          selectedProvenanceTypeIds ?? this.selectedProvenanceTypeIds,
      selectedDateRange: clearDateRange
          ? null
          : selectedDateRange ?? this.selectedDateRange,
      speciesLookup: speciesLookup ?? this.speciesLookup,
      genetLookup: genetLookup ?? this.genetLookup,
      siteLookup: siteLookup ?? this.siteLookup,
      structureOptions: structureOptions ?? this.structureOptions,
      siteOptions: siteOptions ?? this.siteOptions,
      speciesOptions: speciesOptions ?? this.speciesOptions,
      genetOptions: genetOptions ?? this.genetOptions,
      lifeStageOptions: lifeStageOptions ?? this.lifeStageOptions,
      provenanceTypeOptions:
          provenanceTypeOptions ?? this.provenanceTypeOptions,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    organism,
    selectedStructureIds,
    selectedSpeciesIds,
    selectedGenetIds,
    selectedSiteIds,
    selectedLifeStageIds,
    selectedProvenanceTypeIds,
    selectedDateRange,
    speciesLookup,
    genetLookup,
    siteLookup,
    structureOptions,
    siteOptions,
    speciesOptions,
    genetOptions,
    lifeStageOptions,
    provenanceTypeOptions,
    errorMessage,
  ];
}
