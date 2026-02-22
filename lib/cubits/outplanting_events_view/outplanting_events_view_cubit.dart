// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/spreadsheet/outplant/outplant_events_filter_metadata.dart';

part 'outplanting_events_view_state.dart';

class OutplantingEventsViewCubit extends Cubit<OutplantingEventsViewState> {
  OutplantingEventsViewCubit() : super(const OutplantingEventsViewState());

  void updateFilters({
    String? site,
    String? structure,
    String? species,
    String? genet,
    String? lifeStage,
    String? provenanceType,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    String? search,
  }) {
    emit(
      state.copyWith(
        selectedSite: site ?? state.selectedSite,
        selectedStructure: structure ?? state.selectedStructure,
        selectedSpecies: species ?? state.selectedSpecies,
        selectedGenet: genet ?? state.selectedGenet,
        selectedLifeStage: lifeStage ?? state.selectedLifeStage,
        selectedProvenanceType:
            provenanceType ?? state.selectedProvenanceType,
        selectedDateRange: dateRange,
        clearDateRange: clearDateRange,
        search: search ?? state.search,
      ),
    );
  }

  void updateMetadata(OutplantEventsFilterMetadata metadata) {
    final siteNames = Map<String, String>.from(metadata.siteNames);
    final siteOptions = metadata.siteNames.keys.toList()
      ..sort((a, b) => (siteNames[a] ?? a).compareTo(siteNames[b] ?? b));

    final selectedSite = state.selectedSite != null &&
            siteOptions.contains(state.selectedSite)
        ? state.selectedSite
        : null;
    
    final structureOptions = metadata.structurePaths.toList()..sort();
    
    final speciesLabels = Map<String, String>.from(metadata.speciesLabels);
    final speciesOptions = metadata.speciesIds.toList()
      ..sort(
        (a, b) => (speciesLabels[a] ?? a).compareTo(speciesLabels[b] ?? b),
      );
    
    final genetLabels = Map<String, String>.from(metadata.genetLabels);
    final genetOptions = metadata.genetIds.toList()
      ..sort(
        (a, b) => (genetLabels[a] ?? a).compareTo(genetLabels[b] ?? b),
      );
    
    final lifeStageOptions = metadata.lifeStageIds.toList()
      ..sort((a, b) => _lifeStageLabel(a).compareTo(_lifeStageLabel(b)));

    final provenanceTypeOptions = metadata.provenanceTypes.toList()
      ..sort(
        (a, b) =>
            _provenanceTypeLabel(a).compareTo(_provenanceTypeLabel(b)),
      );

    // Validate and update selections
    final selectedStructure = state.selectedStructure != null &&
            structureOptions.contains(state.selectedStructure)
        ? state.selectedStructure
        : null;
    final selectedSpecies = state.selectedSpecies != null &&
            speciesOptions.contains(state.selectedSpecies)
        ? state.selectedSpecies
        : null;
    final selectedGenet = state.selectedGenet != null &&
            genetOptions.contains(state.selectedGenet)
        ? state.selectedGenet
        : null;
    final selectedLifeStage = state.selectedLifeStage != null &&
            lifeStageOptions.contains(state.selectedLifeStage)
        ? state.selectedLifeStage
        : null;
    final selectedProvenanceType = state.selectedProvenanceType != null &&
            provenanceTypeOptions.contains(state.selectedProvenanceType)
        ? state.selectedProvenanceType
        : null;

    emit(
      state.copyWith(
        siteNames: siteNames,
        siteOptions: siteOptions,
        structureOptions: structureOptions,
        speciesLabels: speciesLabels,
        speciesOptions: speciesOptions,
        genetLabels: genetLabels,
        genetOptions: genetOptions,
        lifeStageOptions: lifeStageOptions,
        provenanceTypeOptions: provenanceTypeOptions,
        selectedSite: selectedSite,
        selectedStructure: selectedStructure,
        selectedSpecies: selectedSpecies,
        selectedGenet: selectedGenet,
        selectedLifeStage: selectedLifeStage,
        selectedProvenanceType: selectedProvenanceType,
      ),
    );
  }
}

String _lifeStageLabel(String value) {
  return LifeStageX.tryParse(value)?.displayName ?? value;
}

String _provenanceTypeLabel(String value) {
  return ProvenanceTypeX.tryParse(value)?.displayName ?? value;
}
