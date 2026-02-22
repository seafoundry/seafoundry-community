// @tier: community
import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/coral_morphology.dart';

part 'species_state.dart';

/// Cubit responsible for managing species directory filters.
class SpeciesCubit extends Cubit<SpeciesState> {
  SpeciesCubit({
    required List<Species> species,
    required Set<String> organizationSpeciesIds,
    required String organizationLabel,
  }) : _allSpecies = List<Species>.unmodifiable(_sorted(species)),
       _organizationSpeciesIds = Set<String>.unmodifiable(
         organizationSpeciesIds,
       ),
       super(
         SpeciesState(
           allSpecies: List<Species>.unmodifiable(_sorted(species)),
           filteredSpecies: List<Species>.unmodifiable(_sorted(species)),
           searchTerm: '',
           selectedGenus: null,
           selectedMorphology: null,
           showOrganizationOnly: false,
           organizationSpeciesIds: Set<String>.unmodifiable(
             organizationSpeciesIds,
           ),
           organizationLabel: organizationLabel,
         ),
       );

  final List<Species> _allSpecies;
  final Set<String> _organizationSpeciesIds;

  static List<Species> _sorted(List<Species> species) {
    final sorted = List<Species>.from(species);
    sorted.sort((a, b) {
      final genusCompare = a.genus.toLowerCase().compareTo(
        b.genus.toLowerCase(),
      );
      if (genusCompare != 0) {
        return genusCompare;
      }
      return a.species.toLowerCase().compareTo(b.species.toLowerCase());
    });
    return sorted;
  }

  void search(String query) {
    _emitUpdated(searchTerm: query);
  }

  void toggleOrganizationOnly(bool value) {
    if (_organizationSpeciesIds.isEmpty) {
      return;
    }
    _emitUpdated(showOrganizationOnly: value);
  }

  void selectGenus(String? genus) {
    _emitUpdated(
      selectedGenus: genus?.isEmpty == true ? null : genus,
      overrideGenus: true,
    );
  }

  void selectMorphology(CoralMorphology? morphology) {
    _emitUpdated(selectedMorphology: morphology, overrideMorphology: true);
  }

  void clearFilters() {
    emit(
      state.copyWith(
        searchTerm: '',
        selectedGenus: null,
        selectedMorphology: null,
        showOrganizationOnly: false,
        filteredSpecies: List<Species>.unmodifiable(_allSpecies),
      ),
    );
  }

  static const _noUpdate = Object();

  void _emitUpdated({
    String? searchTerm,
    Object? selectedGenus = _noUpdate,
    Object? selectedMorphology = _noUpdate,
    bool? showOrganizationOnly,
    bool overrideGenus = false,
    bool overrideMorphology = false,
  }) {
    final nextSearch = searchTerm ?? state.searchTerm;
    final nextGenus = overrideGenus
        ? (selectedGenus == _noUpdate ? null : selectedGenus as String?)
        : (selectedGenus == _noUpdate
              ? state.selectedGenus
              : selectedGenus as String?);
    final nextMorphology = overrideMorphology
        ? (selectedMorphology == _noUpdate
              ? null
              : selectedMorphology as CoralMorphology?)
        : (selectedMorphology == _noUpdate
              ? state.selectedMorphology
              : selectedMorphology as CoralMorphology?);
    final nextOrgOnly = showOrganizationOnly ?? state.showOrganizationOnly;

    final next = _applyFilters(
      searchTerm: nextSearch,
      selectedGenus: nextGenus,
      selectedMorphology: nextMorphology,
      showOrganizationOnly: nextOrgOnly,
    );

    emit(
      state.copyWith(
        searchTerm: nextSearch,
        selectedGenus: nextGenus,
        selectedMorphology: nextMorphology,
        showOrganizationOnly: nextOrgOnly,
        filteredSpecies: next,
      ),
    );
  }

  List<Species> _applyFilters({
    required String searchTerm,
    required String? selectedGenus,
    required CoralMorphology? selectedMorphology,
    required bool showOrganizationOnly,
  }) {
    Iterable<Species> results = _allSpecies;

    if (showOrganizationOnly && _organizationSpeciesIds.isNotEmpty) {
      results = results.where(
        (species) => _organizationSpeciesIds.contains(species.id),
      );
    }

    if (selectedGenus != null && selectedGenus.isNotEmpty) {
      final normalizedGenus = selectedGenus.toLowerCase();
      results = results.where(
        (species) => species.genus.toLowerCase() == normalizedGenus,
      );
    }

    if (selectedMorphology != null) {
      results = results.where(
        (species) => species.morphology == selectedMorphology,
      );
    }

    final query = searchTerm.trim().toLowerCase();
    if (query.isNotEmpty) {
      results = results.where((species) {
        final code = species.code.toLowerCase();
        final genus = species.genus.toLowerCase();
        final speciesName = species.species.toLowerCase();
        final fullName = species.name.toLowerCase();
        final morphologyLabel = species.morphology?.label.toLowerCase() ?? '';
        return code.contains(query) ||
            genus.contains(query) ||
            speciesName.contains(query) ||
            fullName.contains(query) ||
            morphologyLabel.contains(query);
      });
    }

    return List<Species>.unmodifiable(results);
  }
}
