// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/utils/filter_label_formatter.dart';
import 'package:seafoundry_app/widgets/spreadsheet/husbandry_filter_metadata.dart';

part 'husbandry_logged_tab_state.dart';

class HusbandryLoggedTabCubit extends SafeCubit<HusbandryLoggedTabState> {
  HusbandryLoggedTabCubit({required RecordRepository recordRepository})
    : _recordRepository = recordRepository,
      super(const HusbandryLoggedTabState()) {
    _loadLookupData();
  }

  final RecordRepository _recordRepository;

  Future<void> _loadLookupData() async {
    try {
      final species = SpeciesRegistry.globalAll();
      final speciesLookup = {
        for (var s in species) s.id: '${s.genus} ${s.species}',
      };

      final genets = await _recordRepository.getRecordsForModelType<Genet>(
        ModelType.genet,
      );
      String genetLabel(Genet genet) {
        final name = genet.name.trim();
        if (name.isNotEmpty) return name;
        final clonalId = ClonalIdDisplayService.resolveForGenet(genet);
        if (clonalId != null) return clonalId;
        return genet.id;
      }
      final genetLookup = {for (var g in genets) g.id: genetLabel(g)};

      final sites = await _recordRepository.getRecordsForModelType<Site>(
        ModelType.site,
      );
      final siteLookup = {for (final site in sites) site.id: site.name};

      final speciesOptions = speciesLookup.keys.toList()
        ..sort(
          (a, b) => (speciesLookup[a] ?? a).compareTo(speciesLookup[b] ?? b),
        );
      final genetOptions = genetLookup.keys.toList()
        ..sort((a, b) => (genetLookup[a] ?? a).compareTo(genetLookup[b] ?? b));

      emit(
        state.copyWith(
          speciesLookup: speciesLookup,
          genetLookup: genetLookup,
          siteLookup: siteLookup,
          speciesOptions: speciesOptions,
          genetOptions: genetOptions,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load lookup data',
        e,
        stackTrace,
      );
      emit(state.copyWith(errorMessage: 'Failed to load initial data: $e'));
    }
  }

  /// Set the site filter (multiselect with cascading).
  void setSiteFilter(Set<String> siteIds, {bool clearDownstream = false}) {
    var newStructureIds = state.selectedStructureIds;
    var newSpeciesIds = state.selectedSpeciesIds;
    var newGenetIds = state.selectedGenetIds;
    var newLifeStageIds = state.selectedLifeStageIds;
    var newProvenanceTypeIds = state.selectedProvenanceTypeIds;

    if (clearDownstream) {
      newStructureIds = {};
      newSpeciesIds = {};
      newGenetIds = {};
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
    }

    emit(state.copyWith(
      selectedSiteIds: siteIds,
      selectedStructureIds: newStructureIds,
      selectedSpeciesIds: newSpeciesIds,
      selectedGenetIds: newGenetIds,
      selectedLifeStageIds: newLifeStageIds,
      selectedProvenanceTypeIds: newProvenanceTypeIds,
    ));
  }

  /// Set the structure filter (multiselect with cascading).
  void setStructureFilter(Set<String> structureIds, {bool clearDownstream = false}) {
    var newSpeciesIds = state.selectedSpeciesIds;
    var newGenetIds = state.selectedGenetIds;
    var newLifeStageIds = state.selectedLifeStageIds;
    var newProvenanceTypeIds = state.selectedProvenanceTypeIds;

    if (clearDownstream) {
      newSpeciesIds = {};
      newGenetIds = {};
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
    }

    emit(state.copyWith(
      selectedStructureIds: structureIds,
      selectedSpeciesIds: newSpeciesIds,
      selectedGenetIds: newGenetIds,
      selectedLifeStageIds: newLifeStageIds,
      selectedProvenanceTypeIds: newProvenanceTypeIds,
    ));
  }

  /// Set the species filter (multiselect with cascading).
  void setSpeciesFilter(Set<String> speciesIds, {bool clearDownstream = false}) {
    var newGenetIds = state.selectedGenetIds;
    var newLifeStageIds = state.selectedLifeStageIds;
    var newProvenanceTypeIds = state.selectedProvenanceTypeIds;

    if (clearDownstream) {
      newGenetIds = {};
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
    }

    emit(state.copyWith(
      selectedSpeciesIds: speciesIds,
      selectedGenetIds: newGenetIds,
      selectedLifeStageIds: newLifeStageIds,
      selectedProvenanceTypeIds: newProvenanceTypeIds,
    ));
  }

  /// Set the genet filter (multiselect with cascading).
  void setGenetFilter(Set<String> genetIds, {bool clearDownstream = false}) {
    var newLifeStageIds = state.selectedLifeStageIds;
    var newProvenanceTypeIds = state.selectedProvenanceTypeIds;

    if (clearDownstream) {
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
    }

    emit(state.copyWith(
      selectedGenetIds: genetIds,
      selectedLifeStageIds: newLifeStageIds,
      selectedProvenanceTypeIds: newProvenanceTypeIds,
    ));
  }

  /// Set the life stage filter (multiselect with cascading).
  void setLifeStageFilter(Set<String> lifeStageIds, {bool clearDownstream = false}) {
    var newProvenanceTypeIds = state.selectedProvenanceTypeIds;

    if (clearDownstream) {
      newProvenanceTypeIds = {};
    }

    emit(state.copyWith(
      selectedLifeStageIds: lifeStageIds,
      selectedProvenanceTypeIds: newProvenanceTypeIds,
    ));
  }

  /// Set the provenance type filter (multiselect).
  void setProvenanceTypeFilter(Set<String> provenanceTypeIds) {
    emit(state.copyWith(selectedProvenanceTypeIds: provenanceTypeIds));
  }

  /// Set the date range filter.
  void setDateRangeFilter(DateTimeRange? dateRange) {
    emit(state.copyWith(
      selectedDateRange: dateRange,
      clearDateRange: dateRange == null,
    ));
  }

  void setOrganismFilter(OrganismKind kind) {
    emit(state.copyWith(organism: kind));
  }

  void updateMetadata(HusbandryFilterMetadata metadata) {
    final structureOptions = metadata.structurePaths.toList()..sort();
    final siteLookup = Map<String, String>.from(state.siteLookup)
      ..addAll(metadata.siteNames);
    final siteOptions = metadata.siteNames.keys.toList()
      ..sort((a, b) => (siteLookup[a] ?? a).compareTo(siteLookup[b] ?? b));
    final speciesOptions = metadata.speciesIds.toList()
      ..sort(
        (a, b) => (state.speciesLookup[a] ?? a).compareTo(
          state.speciesLookup[b] ?? b,
        ),
      );
    final genetOptions = metadata.genetIds.toList()
      ..sort(
        (a, b) =>
            (state.genetLookup[a] ?? a).compareTo(state.genetLookup[b] ?? b),
      );
    final lifeStageOptions = metadata.lifeStageIds.toList()
      ..sort((a, b) => FilterLabelFormatter.lifeStage(a).compareTo(FilterLabelFormatter.lifeStage(b)));
    final provenanceTypeOptions = metadata.provenanceTypes.toList()
      ..sort(
        (a, b) => FilterLabelFormatter.provenanceType(a).compareTo(FilterLabelFormatter.provenanceType(b)),
      );

    // Validate and prune selections to only include options that still exist
    final selectedStructureIds = state.selectedStructureIds
        .where((id) => structureOptions.contains(id))
        .toSet();
    final selectedSiteIds = state.selectedSiteIds
        .where((id) => siteOptions.contains(id))
        .toSet();
    final selectedSpeciesIds = state.selectedSpeciesIds
        .where((id) => speciesOptions.contains(id))
        .toSet();
    final selectedGenetIds = state.selectedGenetIds
        .where((id) => genetOptions.contains(id))
        .toSet();
    final selectedLifeStageIds = state.selectedLifeStageIds
        .where((id) => lifeStageOptions.contains(id))
        .toSet();
    final selectedProvenanceTypeIds = state.selectedProvenanceTypeIds
        .where((id) => provenanceTypeOptions.contains(id))
        .toSet();

    emit(
      state.copyWith(
        structureOptions: structureOptions,
        siteLookup: siteLookup,
        siteOptions: siteOptions,
        speciesOptions: speciesOptions,
        genetOptions: genetOptions,
        lifeStageOptions: lifeStageOptions,
        provenanceTypeOptions: provenanceTypeOptions,
        selectedStructureIds: selectedStructureIds,
        selectedSiteIds: selectedSiteIds,
        selectedSpeciesIds: selectedSpeciesIds,
        selectedGenetIds: selectedGenetIds,
        selectedLifeStageIds: selectedLifeStageIds,
        selectedProvenanceTypeIds: selectedProvenanceTypeIds,
      ),
    );
  }
}
