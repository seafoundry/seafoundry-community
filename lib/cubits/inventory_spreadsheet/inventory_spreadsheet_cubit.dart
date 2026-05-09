// @tier: community
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

part 'inventory_spreadsheet_state.dart';

/// Cubit for the inventory holdings spreadsheet.
///
/// Loads all organism records plus group and site data, builds flat rows
/// for display, and subscribes to the organism record stream as a change
/// signal to refresh when data changes.
class InventorySpreadsheetCubit extends Cubit<InventorySpreadsheetState>
    with CubitStreamSubscriptionMixin {
  InventorySpreadsheetCubit({
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
    required SiteRepository siteRepository,
    required this.organization,
  })  : _organismRecordRepository = organismRecordRepository,
        _groupRepository = groupRepository,
        _siteRepository = siteRepository,
        super(InventorySpreadsheetState.initial());

  final OrganismRecordRepository _organismRecordRepository;
  final GroupRepository _groupRepository;
  final SiteRepository _siteRepository;

  /// The organization whose inventory is being displayed.
  final Organization organization;

  bool _hasStreamError = false;

  Future<void> initialize() async {
    _hasStreamError = false;
    await refresh();
    _subscribeToOrganisms();
  }

  void _subscribeToOrganisms() {
    listenWithKey<List<OrganismRecord>>(
      'organisms',
      _organismRecordRepository.streamAll,
      onData: (_) {
        if (isClosed) return;
        if (_hasStreamError) {
          _hasStreamError = false;
        }
        refresh();
      },
      onError: (error, stackTrace) {
        if (isClosed) return;
        LoggingService.instance
            .error('Organism stream error', error, stackTrace);
        _hasStreamError = true;
        cancelSubscription('organisms');
        emit(state.copyWith(
          errorMessage: 'Failed to load organisms: ${error.toString()}',
        ));
      },
    );
  }

  Future<void> refresh() async {
    if (isClosed) return;
    if (state.isRefreshing) return;

    // Re-create subscription if it errored
    if (_hasStreamError) {
      _hasStreamError = false;
      _subscribeToOrganisms();
    }

    emit(
      state.copyWith(
        isRefreshing: true,
        isInitializing: state.isInitializing,
        errorMessage: InventorySpreadsheetState._unset,
      ),
    );

    try {
      final organisms = await _organismRecordRepository.getAll();
      final groups = await _groupRepository.getAll();
      final sites = await _siteRepository.getAll();

      if (isClosed) return;

      final groupById = <String, Group>{
        for (final g in groups) g.id: g,
      };
      final siteById = <String, Site>{
        for (final s in sites) s.id: s,
      };

      final rows = organisms
          .map((organism) => _buildRow(organism, groupById, siteById))
          .toList();

      if (isClosed) return;
      _emitWithRecalculated(
        baseState: state.copyWith(
          isInitializing: false,
          isRefreshing: false,
          errorMessage: InventorySpreadsheetState._unset,
          allRows: rows,
        ),
        incrementReloadToken: true,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'InventorySpreadsheetCubit: failed to load data',
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

  void updateSiteFilter(String? value) {
    _emitWithRecalculated(
      baseState: state.copyWith(siteFilter: value),
    );
  }

  void updateSpeciesFilter(String? value) {
    _emitWithRecalculated(
      baseState: state.copyWith(speciesFilter: value),
    );
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin

  void _emitWithRecalculated({
    required InventorySpreadsheetState baseState,
    bool incrementReloadToken = true,
  }) {
    final rows = baseState.allRows;
    final filteredRows = _applyFilters(
      allRows: rows,
      siteFilter: baseState.siteFilter,
      speciesFilter: baseState.speciesFilter,
    );

    final availableSites = _extractAvailableSites(rows);
    final availableSpecies = _extractAvailableSpecies(rows);

    emit(
      baseState.copyWith(
        filteredRows: filteredRows,
        availableSites: availableSites,
        availableSpecies: availableSpecies,
        reloadToken: incrementReloadToken
            ? baseState.reloadToken + 1
            : baseState.reloadToken,
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters({
    required List<Map<String, dynamic>> allRows,
    required String? siteFilter,
    required String? speciesFilter,
  }) {
    Iterable<Map<String, dynamic>> rows = allRows;

    // Exclude archived records by default
    rows = rows.where((row) => row['isArchived'] != true);

    if (siteFilter != null && siteFilter.isNotEmpty) {
      rows = rows.where((row) => row['siteId'] == siteFilter);
    }

    if (speciesFilter != null && speciesFilter.isNotEmpty) {
      rows = rows.where((row) => row['speciesId'] == speciesFilter);
    }

    return rows.toList();
  }

  List<String> _extractAvailableSites(List<Map<String, dynamic>> rows) {
    final sites = <String>{};
    for (final row in rows) {
      final siteId = row['siteId'] as String?;
      if (siteId != null && siteId.isNotEmpty) {
        sites.add(siteId);
      }
    }
    final sorted = sites.toList()..sort();
    return sorted;
  }

  List<String> _extractAvailableSpecies(List<Map<String, dynamic>> rows) {
    final species = <String>{};
    for (final row in rows) {
      final speciesId = row['speciesId'] as String?;
      if (speciesId != null && speciesId.isNotEmpty) {
        species.add(speciesId);
      }
    }
    final sorted = species.toList()..sort();
    return sorted;
  }

  /// Returns the display name for a site given its ID.
  String siteLabel(String siteId) {
    for (final row in state.allRows) {
      if (row['siteId'] == siteId) {
        final name = row['siteName'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return siteId;
  }

  /// Returns the display name for a species given its ID.
  String speciesLabel(String speciesId) {
    return SpeciesRegistry.globalById(speciesId)?.name ?? speciesId;
  }

  Map<String, dynamic> _buildRow(
    OrganismRecord organism,
    Map<String, Group> groupById,
    Map<String, Site> siteById,
  ) {
    final group = organism.groupId != null ? groupById[organism.groupId] : null;
    final site = organism.siteId != null ? siteById[organism.siteId] : null;
    return {
      'id': organism.id,
      'localGenetId': organism.localGenetId,
      'tagId': organism.tagId,
      'speciesId': organism.speciesId,
      'speciesName':
          SpeciesRegistry.globalById(organism.speciesId)?.name ??
              organism.speciesId,
      'quantity': organism.inventoryMetrics.count,
      'lifeStage': organism.lifeStage.stage.displayName,
      'physicalForm': organism.physicalForm?.formId ?? '',
      'siteId': organism.siteId ?? '',
      'siteName': site?.name ?? '',
      'structureId': organism.groupId ?? '',
      'structureName': group?.name ?? '',
      'createdAt': organism.createdAt,
      'urlPath': organism.urlPath,
      'isArchived': organism.isArchived,
    };
  }
}
