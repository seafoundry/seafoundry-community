import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/schemas/provenance_schema.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/spreadsheet/genetics_data_loader.dart';
import 'package:seafoundry_app/services/spreadsheet/genetics_filter_service.dart';
import 'package:seafoundry_app/services/spreadsheet/genetics_spreadsheet_helper.dart';

part 'genetics_spreadsheet_state.dart';

class GeneticsSpreadsheetCubit extends Cubit<GeneticsSpreadsheetState>
    with CubitStreamSubscriptionMixin {
  GeneticsSpreadsheetCubit({
    required ProvenanceRepository provenanceRepository,
    required OrganismRecordRepository organismRepository,
    required CurrentUser currentUser,
    String? initialSpeciesId,
    GeneticsFilterService? filterService,
    GeneticsSpreadsheetDataLoader? dataLoader,
    OrganismKind organismKind = OrganismKind.coral,
  })  : _provenanceRepository = provenanceRepository,
        _currentUser = currentUser,
        _initialSpeciesId = initialSpeciesId,
        _filterService = filterService ?? const GeneticsFilterService(),
        _dataLoader = dataLoader ??
            GeneticsSpreadsheetDataLoader(
              provenanceRepository: provenanceRepository,
              organismRepository: organismRepository,
            ),
        super(GeneticsSpreadsheetState.initial(organismFilter: organismKind));

  final ProvenanceRepository _provenanceRepository;
  final CurrentUser _currentUser;
  final String? _initialSpeciesId;
  final GeneticsFilterService _filterService;
  final GeneticsSpreadsheetDataLoader _dataLoader;

  bool _hasStreamError = false;

  static const Map<String, dynamic> exampleRow = {
    '__example': true,
    'genet_name': 'Example Genet',
    'genet_slug': 'example-genet',
    'genet_type': 'fgen',
    'genet_type_label': 'Founder',
    'speciesId': 'sp-001',
    'species_name': 'Acropora cervicornis',
    'provenanceId': 'PID-ACER-0001',
    'clonal_id': 'CLN-01',
    'accession_number': 'ACC-101',
    'total_quantity': 24,
    'num_nurseries': 3,
    'tagId': 'Example Record',
    'cluster_type': 'plug',
    'physical_form': 'plug',
    'coral_size': 'M',
    'coral_notes': 'Example notes',
    'groupId': '/nursery/site-a',
    'cross_date': '2024-04-21',
    'dam_gamete_ids': 'DAM-01, DAM-02',
    'sire_gamete_ids': 'SIRE-01, SIRE-02',
    'genotype_provenance': 'Collected from reef crest',
    'cohort_parent_gamete_ids': 'DAM-01, SIRE-01',
    'recruit_parent_cohort_id': 'COHORT-12',
    'gamete_donor_genotype_id': 'GEN-09',
    'reef_of_origin': 'Example Reef',
    'collection_date': '2023-09-14',
    'depth': '3.2',
    'habitatType': 'reef_crest',
    'collecting_institution': 'NOAA',
    'latitude': '25.12345',
    'longitude': '-80.54321',
    'parent_genet_id': 'GEN-08',
    'parent_genet_name': 'Example Parent',
    'spawn_date': '2023-08-01',
    'settlement_date': '2023-08-21',
    'cohort_size': '120',
    'cohort_notes': 'Example cohort notes',
    'sending_organization': 'Mote Marine Laboratory',
    'transfer_date': '2024-01-12',
    'transfer_notes': 'Example transfer notes',
    'genet_notes': 'Example genet notes',
    'created_at_display': '2023-05-10',
    'created_by': 'user_123',
    'archived': false,
    'archived_at': null,
    'provenanceKind': 'broodstock',
    'provenanceType': 'wild',
    'provenanceType_label': 'Wild Collection',
  };

  Future<void> initialize() async {
    _hasStreamError = false;
    await refresh(forceRemote: true);
    _subscribeToGenets();
  }

  void _subscribeToGenets() {
    listenWithKey<List<ProvenanceRecord>>(
      'genets',
      _provenanceRepository.streamAll,
      onData: (_) {
        if (isClosed) return;
        if (_hasStreamError) {
          _hasStreamError = false;
        }
        refresh(forceRemote: true);
      },
      onError: (error, stackTrace) {
        if (isClosed) return;
        LoggingService.instance.error('Genet stream error', error, stackTrace);
        _hasStreamError = true;
        cancelSubscription('genets');
        emit(state.copyWith(errorMessage: 'Failed to load genets: ${error.toString()}'));
      },
    );
  }

  Future<void> refresh({bool forceRemote = false}) async {
    if (isClosed) return;
    if (state.isRefreshing && !forceRemote) return;

    // Re-create subscription if it errored
    if (_hasStreamError) {
      _hasStreamError = false;
      _subscribeToGenets();
    }

    emit(
      state.copyWith(
        isRefreshing: true,
        isInitializing: state.isInitializing,
        errorMessage: GeneticsSpreadsheetState._unset,
      ),
    );

    try {
      final organization = _resolveOrganization();
      final rows = await _dataLoader.loadRows(
        includeInactiveCorals: state.includeInactive,
        includeArchivedGenets: state.includeArchived,
        speciesFilter: _initialSpeciesId,
        organization: organization,
        provenanceTypeLabel: _provenanceTypeLabel,
        physicalFormLabel: _organismTypeLabel,
        formatDate: _formatDateCell,
        joinIds: _joinIds,
        aggregateParentGametes: _aggregateParentGametes,
        genotypeProvenanceText: _genotypeProvenanceText,
      );

      if (isClosed) return;
      _emitWithRecalculated(
        baseState: state.copyWith(
          isInitializing: false,
          isRefreshing: false,
          errorMessage: GeneticsSpreadsheetState._unset,
          allRows: rows,
        ),
        incrementReloadToken: true,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'GeneticsSpreadsheetCubit: failed to load data',
        error,
        stackTrace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isInitializing: false,
          isRefreshing: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void toggleIncludeInactive(bool value) {
    if (value == state.includeInactive) return;
    emit(state.copyWith(includeInactive: value));
    refresh(forceRemote: true);
  }

  void toggleIncludeArchived(bool value) {
    if (value == state.includeArchived) return;
    emit(state.copyWith(includeArchived: value));
    refresh(forceRemote: true);
  }

  void updateStructure(String? value) {
    _emitWithRecalculated(
      baseState: state.copyWith(structureFilter: value),
    );
  }

  void updateSite(String? value) {
    _emitWithRecalculated(
      baseState: state.copyWith(siteFilter: value),
    );
  }

  void updateSpecies(String? value) {
    _emitWithRecalculated(
      baseState: state.copyWith(speciesFilter: value),
    );
  }

  void updateGenet(String? value) {
    _emitWithRecalculated(
      baseState: state.copyWith(genetFilter: value),
    );
  }

  void setDateRange(DateTimeRange? range) {
    _emitWithRecalculated(
      baseState: state.copyWith(dateRange: range),
    );
  }

  void updateProvenanceType(String? value) {
    _emitWithRecalculated(
      baseState: state.copyWith(provenanceTypeFilter: value),
    );
  }

  void setOrganismKind(OrganismKind kind) {
    if (state.organismFilter == kind) return;
    _emitWithRecalculated(
      baseState: state.copyWith(organismFilter: kind),
    );
  }

  String speciesLabel(String speciesId) {
    return _filterService.getSpeciesLabel(speciesId, state.allRows);
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin

  void _emitWithRecalculated({
    required GeneticsSpreadsheetState baseState,
    bool incrementReloadToken = true,
  }) {
    final rows = baseState.allRows;
    final filteredRows = _filterService.applyFilters(
      allRows: rows,
      includeArchived: baseState.includeArchived,
      siteFilter: baseState.siteFilter,
      structureFilter: baseState.structureFilter,
      speciesFilter: baseState.speciesFilter,
      genetFilter: baseState.genetFilter,
      dateRange: baseState.dateRange,
      provenanceTypeFilter: baseState.provenanceTypeFilter,
    );
    final effectiveRows = baseState.organismFilter == OrganismKind.coral
        ? filteredRows
        : const <Map<String, dynamic>>[];

    final availableStructures =
        _filterService.extractAvailableStructures(rows);
    final availableSites = _filterService.extractAvailableSites(rows);
    final availableSpecies = _filterService.extractAvailableSpeciesIds(rows);
    final availableGenets = _filterService.extractAvailableGenetIds(rows);
    final availableProvenanceTypes =
        _filterService.extractAvailableProvenanceTypes(rows);

    emit(
      baseState.copyWith(
        filteredRows: effectiveRows,
        availableStructures: availableStructures,
        availableSites: availableSites,
        availableSpecies: availableSpecies,
        availableGenets: availableGenets,
        availableProvenanceTypes: availableProvenanceTypes,
        reloadToken: incrementReloadToken
            ? baseState.reloadToken + 1
            : baseState.reloadToken,
      ),
    );
  }

  Organization? _resolveOrganization() {
    final currentUserState = _currentUser.state;
    if (currentUserState is CurrentUserLoaded) {
      return currentUserState.organization;
    }
    return null;
  }

  static String _provenanceTypeLabel(String provenanceTypeId) {
    final parsed = ProvenanceTypeX.tryParse(provenanceTypeId);
    return parsed?.displayName ?? provenanceTypeId;
  }

  static String _organismTypeLabel(String formId) =>
      formatSnakeCaseToTitleCase(formId);

  static String _joinIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) return '';
    return ids.join(', ');
  }

  static String _aggregateParentGametes(ProvenanceRecord genet) {
    final combined = <String>{};
    combined.addAll(genet.parentGameteIds);
    combined.addAll(genet.damGameteIds);
    combined.addAll(genet.sireGameteIds);
    final list = combined.toList()..sort();
    return list.join(', ');
  }

  static String _genotypeProvenanceText(ProvenanceRecord genet) =>
      GeneticsSpreadsheetHelper.formatProvenanceText(genet);

  static String _formatDateCell(DateTime? date) {
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
