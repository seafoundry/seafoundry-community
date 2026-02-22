// @tier: community
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/historical/historical_filter_options.dart';
import 'package:seafoundry_app/models/historical/historical_impact_point.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/services/historical_data_service.dart';
import 'package:seafoundry_app/services/historical_nomenclature_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

part 'public_holdings_map_state.dart';

/// Cubit for managing public holdings map state.
///
/// Handles loading CRC historical data, managing filters with debouncing,
/// and computing filtered CRC points for map display.
class PublicHoldingsMapCubit extends Cubit<PublicHoldingsMapState> {
  PublicHoldingsMapCubit({
    required HistoricalDataService historicalDataService,
  })  : _historicalService = historicalDataService,
        super(const PublicHoldingsMapState());

  final HistoricalDataService _historicalService;

  Timer? _yearFilterDebounce;
  Timer? _genetFilterDebounce;
  int _yearFilterGeneration = 0;
  int _genetFilterGeneration = 0;

  @override
  Future<void> close() {
    _yearFilterDebounce?.cancel();
    _genetFilterDebounce?.cancel();
    return super.close();
  }

  /// Load CRC data from Firestore.
  Future<void> loadCrcData() async {
    emit(state.copyWith(
      isLoadingCrcData: true,
      clearCrcError: true,
      loadingStatus: 'Loading 1,163 restoration sites...',
    ));

    try {
      // Load all CRC impact points first (fast - just site locations)
      final points = await _historicalService.fetchAllHistoricalImpactPoints(
        datasetId: crcDatasetId,
      );

      emit(state.copyWith(
        crcPoints: points,
        loadingStatus: 'Building filter options...',
      ));

      // Build filter options from the data
      final options = await _historicalService.buildFilterOptionsFromData(
        datasetId: crcDatasetId,
      );

      emit(state.copyWith(
        filterOptions: options,
        isLoadingCrcData: false,
      ));

      // Load years and genets in the background (don't block UI)
      _loadYearsInBackground();
      _loadGenetsInBackground();
      _loadNomenclatureInBackground();
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load CRC data',
        {
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      emit(state.copyWith(
        crcError: 'Failed to load CRC data: $e',
        isLoadingCrcData: false,
      ));
    }
  }

  Future<void> _loadYearsInBackground() async {
    if (isClosed) return;
    emit(state.copyWith(isLoadingYears: true));
    try {
      final years = await _historicalService.fetchAvailableYears(
        datasetId: crcDatasetId,
      );
      if (isClosed) return;
      emit(state.copyWith(
        availableYears: years,
        isLoadingYears: false,
      ));
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load CRC years',
        {
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      if (isClosed) return;
      emit(state.copyWith(isLoadingYears: false));
    }
  }

  Future<void> _loadGenetsInBackground() async {
    if (isClosed) return;
    emit(state.copyWith(isLoadingGenets: true));
    try {
      final genets = await _historicalService.fetchAvailableGenets(
        datasetId: crcDatasetId,
      );
      if (isClosed) return;
      emit(state.copyWith(
        availableGenets: genets,
        isLoadingGenets: false,
      ));
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load CRC genets',
        {
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      if (isClosed) return;
      emit(state.copyWith(isLoadingGenets: false));
    }
  }

  /// Initializes the nomenclature service for genotype ID translation.
  Future<void> _loadNomenclatureInBackground() async {
    if (isClosed) return;
    await HistoricalNomenclatureService.instance.initialize();
    if (isClosed) return;
    // Emit to trigger rebuild with translated IDs
    emit(state.copyWith());
  }

  /// Update region filter. Clears reef when region changes.
  void setRegion(String? region) {
    emit(state.copyWith(
      selectedRegion: region,
      clearRegion: region == null,
      clearReef: region != null, // Clear reef when region changes
    ));
  }

  /// Update reef filter.
  void setReef(String? reef) {
    emit(state.copyWith(
      selectedReef: reef,
      clearReef: reef == null,
    ));
  }

  /// Update species filter (expects speciesId).
  void setSpecies(String? species) {
    emit(state.copyWith(
      selectedSpecies: species,
      clearSpecies: species == null,
    ));
  }

  /// Update year filter with debounced site ID lookup.
  Future<void> setYear(int? year) async {
    _yearFilterGeneration++;
    final currentGeneration = _yearFilterGeneration;

    emit(state.copyWith(
      selectedYear: year,
      clearYear: year == null,
      isLoadingYearFilter: year != null,
    ));

    if (year == null) {
      emit(state.copyWith(
        clearYearFilteredSiteIds: true,
        isLoadingYearFilter: false,
      ));
      return;
    }

    // Cancel existing debounce timer
    _yearFilterDebounce?.cancel();

    // Debounce for 300ms
    _yearFilterDebounce = Timer(const Duration(milliseconds: 300), () async {
      final siteIds = await _historicalService.fetchSiteIdsForYear(
        datasetId: crcDatasetId,
        year: year,
      );

      // Check if this result is still relevant
      if (isClosed || currentGeneration != _yearFilterGeneration) return;

      emit(state.copyWith(
        yearFilteredSiteIds: siteIds,
        isLoadingYearFilter: false,
      ));
    });
  }

  /// Update genet filter with debounced site ID lookup.
  Future<void> setGenet(String? genet) async {
    _genetFilterGeneration++;
    final currentGeneration = _genetFilterGeneration;

    emit(state.copyWith(
      selectedGenet: genet,
      clearGenet: genet == null,
      isLoadingGenetFilter: genet != null,
      clearGenetSearchError: true,
    ));

    if (genet == null) {
      emit(state.copyWith(
        clearGenetFilteredSiteIds: true,
        isLoadingGenetFilter: false,
      ));
      return;
    }

    // Cancel existing debounce timer
    _genetFilterDebounce?.cancel();

    // Debounce for 300ms
    _genetFilterDebounce = Timer(const Duration(milliseconds: 300), () async {
      final siteIds = await _historicalService.fetchSiteIdsForGenet(
        datasetId: crcDatasetId,
        genet: genet,
      );

      // Check if this result is still relevant
      if (isClosed || currentGeneration != _genetFilterGeneration) return;

      emit(state.copyWith(
        genetFilteredSiteIds: siteIds,
        isLoadingGenetFilter: false,
      ));
    });
  }

  /// Set genet search error for validation feedback.
  void setGenetSearchError(String? error) {
    emit(state.copyWith(
      genetSearchError: error,
      clearGenetSearchError: error == null,
    ));
  }

  /// Clear all filters.
  void clearFilters() {
    emit(state.copyWith(
      clearRegion: true,
      clearReef: true,
      clearSpecies: true,
      clearYear: true,
      clearGenet: true,
      clearYearFilteredSiteIds: true,
      clearGenetFilteredSiteIds: true,
      clearGenetSearchError: true,
    ));
  }

  /// Get filtered CRC points based on current filter state.
  ///
  /// Returns PublicImpactPoint list for map display.
  List<PublicImpactPoint> getFilteredCrcPoints() {
    if (state.isLoadingCrcData || state.crcPoints.isEmpty) {
      return [];
    }

    // Apply filters
    final filtered = state.crcPoints.where((point) {
      if (state.selectedRegion != null && point.region != state.selectedRegion) {
        return false;
      }
      if (state.selectedReef != null && point.reefName != state.selectedReef) {
        return false;
      }
      if (state.selectedSpecies != null) {
        final selectedSpeciesId = state.selectedSpecies!;
        var matchesSpecies = point.speciesId == selectedSpeciesId;

        if (!matchesSpecies) {
          String? selectedSpeciesName;
          for (final option in state.filterOptions.species) {
            if (option.id == selectedSpeciesId) {
              selectedSpeciesName = option.name;
              break;
            }
          }
          if (selectedSpeciesName != null &&
              point.speciesName == selectedSpeciesName) {
            matchesSpecies = true;
          }
        }

        if (!matchesSpecies) {
          return false;
        }
      }
      // Filter by year (using site IDs from outplant events)
      if (state.yearFilteredSiteIds != null) {
        final siteId = point.id.replaceFirst('crc_site_', '');
        if (!state.yearFilteredSiteIds!.contains(siteId)) {
          return false;
        }
      }
      // Filter by genet (using site IDs from outplant events)
      if (state.genetFilteredSiteIds != null) {
        final siteId = point.id.replaceFirst('crc_site_', '');
        if (!state.genetFilteredSiteIds!.contains(siteId)) {
          return false;
        }
      }
      return true;
    });

    // Convert to PublicImpactPoint for display
    return filtered
        .map((crc) => PublicImpactPoint.sample(
              id: 'crc-${crc.id}',
              organizationId: 'crc',
              latitude: crc.latitude,
              longitude: crc.longitude,
              magnitude: crc.magnitude,
              pointType: PublicImpactPointType.outplant,
              label: crc.reefName ?? crc.label ?? 'CRC Site',
            ))
        .toList();
  }

  /// Get available reefs filtered by selected region.
  List<String> getAvailableReefs() {
    if (state.selectedRegion == null) {
      return state.filterOptions.reefs.map((r) => r.name).toList();
    }
    // Filter reefs based on selected region
    return state.crcPoints
        .where((p) => p.region == state.selectedRegion)
        .map((p) => p.reefName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
  }

  // ============================================================
  // Filter Toggle Methods
  // ============================================================

  /// Toggle holdings visibility on the map.
  void setShowHoldings(bool value) {
    emit(state.copyWith(showHoldings: value));
  }

  /// Toggle outplants visibility on the map.
  void setShowOutplants(bool value) {
    emit(state.copyWith(showOutplants: value));
  }

  /// Toggle CRC data visibility on the map.
  void setShowCrcData(bool value) {
    emit(state.copyWith(showCrcData: value));
  }

  /// Set whether map gestures are enabled.
  void setMapGesturesEnabled(bool value) {
    emit(state.copyWith(mapGesturesEnabled: value));
  }
}
