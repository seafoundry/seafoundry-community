// @tier: community
part of 'species_cubit.dart';

const _stateNoValue = Object();

class SpeciesState extends Equatable {
  const SpeciesState({
    required this.allSpecies,
    required this.filteredSpecies,
    required this.searchTerm,
    required this.selectedGenus,
    required this.selectedMorphology,
    required this.showOrganizationOnly,
    required this.organizationSpeciesIds,
    required this.organizationLabel,
  });

  final List<Species> allSpecies;
  final List<Species> filteredSpecies;
  final String searchTerm;
  final String? selectedGenus;
  final CoralMorphology? selectedMorphology;
  final bool showOrganizationOnly;
  final Set<String> organizationSpeciesIds;
  final String organizationLabel;

  bool get hasOrganizationFilter => organizationSpeciesIds.isNotEmpty;

  List<String> get availableGenera {
    final genera = SplayTreeSet<String>(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    for (final species in allSpecies) {
      genera.add(species.genus);
    }
    return List<String>.unmodifiable(genera);
  }

  List<CoralMorphology> get availableMorphologies {
    final morphologies = SplayTreeSet<CoralMorphology>(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    for (final species in allSpecies) {
      if (species.morphology != null) {
        morphologies.add(species.morphology!);
      }
    }
    return List<CoralMorphology>.unmodifiable(morphologies);
  }

  bool isOrganizationSpecies(Species species) =>
      organizationSpeciesIds.contains(species.id);

  SpeciesState copyWith({
    List<Species>? filteredSpecies,
    String? searchTerm,
    Object? selectedGenus = _stateNoValue,
    Object? selectedMorphology = _stateNoValue,
    bool? showOrganizationOnly,
  }) {
    final nextSelectedGenus = selectedGenus == _stateNoValue
        ? this.selectedGenus
        : selectedGenus as String?;
    final nextSelectedMorphology = selectedMorphology == _stateNoValue
        ? this.selectedMorphology
        : selectedMorphology as CoralMorphology?;
    return SpeciesState(
      allSpecies: allSpecies,
      filteredSpecies: filteredSpecies ?? this.filteredSpecies,
      searchTerm: searchTerm ?? this.searchTerm,
      selectedGenus: nextSelectedGenus,
      selectedMorphology: nextSelectedMorphology,
      showOrganizationOnly: showOrganizationOnly ?? this.showOrganizationOnly,
      organizationSpeciesIds: organizationSpeciesIds,
      organizationLabel: organizationLabel,
    );
  }

  @override
  List<Object?> get props => [
    allSpecies,
    filteredSpecies,
    searchTerm,
    selectedGenus,
    selectedMorphology,
    showOrganizationOnly,
    organizationSpeciesIds,
    organizationLabel,
  ];
}
