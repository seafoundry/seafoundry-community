// @tier: community
part of 'outplanting_events_view_cubit.dart';

const _kNoValue = Object();

class OutplantingEventsViewState extends Equatable {
  const OutplantingEventsViewState({
    this.selectedSite,
    this.selectedStructure,
    this.selectedSpecies,
    this.selectedGenet,
    this.selectedLifeStage,
    this.selectedProvenanceType,
    this.selectedDateRange,
    this.search,
    this.siteNames = const {},
    this.siteOptions = const [],
    this.structureOptions = const [],
    this.speciesLabels = const {},
    this.speciesOptions = const [],
    this.genetLabels = const {},
    this.genetOptions = const [],
    this.lifeStageOptions = const [],
    this.provenanceTypeOptions = const [],
  });

  final String? selectedSite;
  final String? selectedStructure;
  final String? selectedSpecies;
  final String? selectedGenet;
  final String? selectedLifeStage;
  final String? selectedProvenanceType;
  final DateTimeRange? selectedDateRange;
  final String? search;
  final Map<String, String> siteNames;
  final List<String> siteOptions;
  final List<String> structureOptions;
  final Map<String, String> speciesLabels;
  final List<String> speciesOptions;
  final Map<String, String> genetLabels;
  final List<String> genetOptions;
  final List<String> lifeStageOptions;
  final List<String> provenanceTypeOptions;

  OutplantingEventsViewState copyWith({
    Object? selectedSite = _kNoValue,
    Object? selectedStructure = _kNoValue,
    Object? selectedSpecies = _kNoValue,
    Object? selectedGenet = _kNoValue,
    Object? selectedLifeStage = _kNoValue,
    Object? selectedProvenanceType = _kNoValue,
    DateTimeRange? selectedDateRange,
    bool clearDateRange = false,
    String? search,
    Map<String, String>? siteNames,
    List<String>? siteOptions,
    List<String>? structureOptions,
    Map<String, String>? speciesLabels,
    List<String>? speciesOptions,
    Map<String, String>? genetLabels,
    List<String>? genetOptions,
    List<String>? lifeStageOptions,
    List<String>? provenanceTypeOptions,
  }) {
    return OutplantingEventsViewState(
      selectedSite: _resolveFilter(selectedSite, this.selectedSite),
      selectedStructure:
          _resolveFilter(selectedStructure, this.selectedStructure),
      selectedSpecies: _resolveFilter(selectedSpecies, this.selectedSpecies),
      selectedGenet: _resolveFilter(selectedGenet, this.selectedGenet),
      selectedLifeStage:
          _resolveFilter(selectedLifeStage, this.selectedLifeStage),
      selectedProvenanceType: _resolveFilter(
        selectedProvenanceType,
        this.selectedProvenanceType,
      ),
      selectedDateRange:
          clearDateRange ? null : selectedDateRange ?? this.selectedDateRange,
      search: search ?? this.search,
      siteNames: siteNames ?? this.siteNames,
      siteOptions: siteOptions ?? this.siteOptions,
      structureOptions: structureOptions ?? this.structureOptions,
      speciesLabels: speciesLabels ?? this.speciesLabels,
      speciesOptions: speciesOptions ?? this.speciesOptions,
      genetLabels: genetLabels ?? this.genetLabels,
      genetOptions: genetOptions ?? this.genetOptions,
      lifeStageOptions: lifeStageOptions ?? this.lifeStageOptions,
      provenanceTypeOptions:
          provenanceTypeOptions ?? this.provenanceTypeOptions,
    );
  }

  @override
  List<Object?> get props => [
        selectedSite,
        selectedStructure,
        selectedSpecies,
        selectedGenet,
        selectedLifeStage,
        selectedProvenanceType,
        selectedDateRange,
        search,
        siteNames,
        siteOptions,
        structureOptions,
        speciesLabels,
        speciesOptions,
        genetLabels,
        genetOptions,
        lifeStageOptions,
        provenanceTypeOptions,
      ];
}

String? _resolveFilter(Object? candidate, String? currentValue) {
  if (candidate == _kNoValue) {
    return currentValue;
  }
  return candidate as String?;
}
