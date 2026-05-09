// @tier: community
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';

/// Mixin providing provenance alias search, debounce, conflict detection,
/// and selection handling. Used by OrganismCreationCubit to avoid
/// duplicating ~180 lines of search logic.
///
/// Implementors must provide:
/// - [provenanceLookupService]: the service to search
/// - [currentSpeciesCode]: species code for species-scoped search
/// - [currentProvenanceSearch]: current search state from host state
/// - [emitProvenanceSearch]: callback to emit updated search state into host
mixin ProvenanceSearchMixin<S> on Cubit<S> {
  ProvenanceLookupService? get provenanceLookupService;
  String? get currentSpeciesCode;
  ProvenanceSearchState get currentProvenanceSearch;
  void emitProvenanceSearch(ProvenanceSearchState search);

  Timer? _clonalIdDebounce;
  Timer? _accessionDebounce;
  Timer? _aliasDebounce;
  Timer? _provenanceIdDebounce;
  int _clonalIdSearchId = 0;
  int _accessionSearchId = 0;
  int _aliasSearchId = 0;
  int _provenanceIdSearchId = 0;
  String? _lastSelectedClonalId;
  String? _lastSelectedAccessionNumber;
  String? _lastSelectedAlias;
  String? _lastSelectedProvenanceId;

  /// Called when user types in the clonalId field. Debounces search.
  void onClonalIdSearchChanged(String prefix) {
    _clonalIdDebounce?.cancel();

    // Skip search if text matches the last selected suggestion value
    // (prevents re-searching when text is set programmatically after selection)
    if (_lastSelectedClonalId != null && prefix == _lastSelectedClonalId) return;
    _lastSelectedClonalId = null;

    // Clear match if text changed manually
    final search = currentProvenanceSearch;
    if (search.clonalIdMatch != null) {
      emitProvenanceSearch(search.copyWith(
        clonalIdMatch: null,
        clonalIdSuggestions: const [],
      ));
    }

    // Allow empty search (dropdown behavior)
    // if (prefix.trim().length < 2) { ... }
    
    _clonalIdDebounce = Timer(const Duration(milliseconds: 300), () {
      _performClonalIdSearch(prefix);
    });
  }

  Future<void> _performClonalIdSearch(String prefix) async {
    final service = provenanceLookupService;
    if (service == null || isClosed) return;

    final requestId = ++_clonalIdSearchId;
    final speciesCode = currentSpeciesCode;
    // Allow search even if species is not yet selected (global search)
    // if (speciesCode == null) return;

    // Start searching state
    emitProvenanceSearch(currentProvenanceSearch.copyWith(
      isSearchingClonalId: true,
    ));

    try {
      final results = await service.searchAliases(
        prefix: prefix,
        speciesCode: speciesCode ?? '',
        aliasType: ProvenanceAliasType.clonalId,
      );

      if (requestId != _clonalIdSearchId || isClosed) return;

      emitProvenanceSearch(currentProvenanceSearch.copyWith(
        clonalIdSuggestions: results,
        isSearchingClonalId: false,
      ));
    } catch (e, _) {
      // Prevent crash on search failure
      if (requestId == _clonalIdSearchId && !isClosed) {
        emitProvenanceSearch(currentProvenanceSearch.copyWith(
          isSearchingClonalId: false,
          clonalIdSuggestions: const [],
        ));
      }
    }
  }

  /// Called when user types in the accessionNumber field. Debounces search.
  void onAccessionSearchChanged(String prefix) {
    _accessionDebounce?.cancel();

    // Skip search if text matches the last selected suggestion value
    if (_lastSelectedAccessionNumber != null &&
        prefix == _lastSelectedAccessionNumber) {
      return;
    }
    _lastSelectedAccessionNumber = null;

    // Clear match if text changed manually
    final search = currentProvenanceSearch;
    if (search.accessionMatch != null) {
      emitProvenanceSearch(search.copyWith(
        accessionMatch: null,
        accessionSuggestions: const [],
      ));
    }

    // Allow empty search
    // if (prefix.trim().length < 2) ...
    
    _accessionDebounce = Timer(const Duration(milliseconds: 300), () {
      _performAccessionSearch(prefix);
    });
  }

  Future<void> _performAccessionSearch(String prefix) async {
    final service = provenanceLookupService;
    if (service == null || isClosed) return;

    final requestId = ++_accessionSearchId;
    final speciesCode = currentSpeciesCode;
    // Allow search even if species is not yet selected (global search)
    // if (speciesCode == null) return;

    emitProvenanceSearch(currentProvenanceSearch.copyWith(
      isSearchingAccession: true,
    ));

    try {
      final results = await service.searchAliases(
        prefix: prefix,
        speciesCode: speciesCode ?? '',
        aliasType: ProvenanceAliasType.accessionNumber,
      );

      if (requestId != _accessionSearchId || isClosed) return;

      emitProvenanceSearch(currentProvenanceSearch.copyWith(
        accessionSuggestions: results,
        isSearchingAccession: false,
      ));
    } catch (e) {
      if (requestId == _accessionSearchId && !isClosed) {
        emitProvenanceSearch(currentProvenanceSearch.copyWith(
          isSearchingAccession: false,
          accessionSuggestions: const [],
        ));
      }
    }
  }

  /// Called when user types in the alias field. Debounces search.
  void onAliasSearchChanged(String prefix) {
    _aliasDebounce?.cancel();

    if (_lastSelectedAlias != null && prefix == _lastSelectedAlias) return;
    _lastSelectedAlias = null;

    final search = currentProvenanceSearch;
    if (search.aliasMatch != null) {
      emitProvenanceSearch(search.copyWith(
        aliasMatch: null,
        aliasSuggestions: const [],
      ));
    }

    _aliasDebounce = Timer(const Duration(milliseconds: 300), () {
      _performAliasSearch(prefix);
    });
  }

  Future<void> _performAliasSearch(String prefix) async {
    final service = provenanceLookupService;
    if (service == null || isClosed) return;

    final requestId = ++_aliasSearchId;
    final speciesCode = currentSpeciesCode;

    emitProvenanceSearch(currentProvenanceSearch.copyWith(
      isSearchingAlias: true,
    ));

    try {
      final results = await service.searchAliases(
        prefix: prefix,
        speciesCode: speciesCode ?? '',
        aliasType: null,
      );

      if (requestId != _aliasSearchId || isClosed) return;

      emitProvenanceSearch(currentProvenanceSearch.copyWith(
        aliasSuggestions: results,
        isSearchingAlias: false,
      ));
    } catch (e) {
      if (requestId == _aliasSearchId && !isClosed) {
        emitProvenanceSearch(currentProvenanceSearch.copyWith(
          isSearchingAlias: false,
          aliasSuggestions: const [],
        ));
      }
    }
  }

  /// Called when user types in the PID field. Debounces search.
  void onProvenanceIdSearchChanged(String prefix) {
    _provenanceIdDebounce?.cancel();

    if (_lastSelectedProvenanceId != null &&
        prefix == _lastSelectedProvenanceId) {
      return;
    }
    _lastSelectedProvenanceId = null;

    final search = currentProvenanceSearch;
    if (search.provenanceIdMatch != null) {
      emitProvenanceSearch(search.copyWith(
        provenanceIdMatch: null,
        provenanceIdSuggestions: const [],
      ));
    }

    _provenanceIdDebounce = Timer(const Duration(milliseconds: 300), () {
      _performProvenanceIdSearch(prefix);
    });
  }

  Future<void> _performProvenanceIdSearch(String prefix) async {
    final service = provenanceLookupService;
    if (service == null || isClosed) return;

    final requestId = ++_provenanceIdSearchId;
    final speciesCode = currentSpeciesCode;

    emitProvenanceSearch(currentProvenanceSearch.copyWith(
      isSearchingProvenanceId: true,
    ));

    try {
      final results = await service.searchProvenanceIds(
        prefix: prefix,
        speciesCode: speciesCode ?? '',
      );

      if (requestId != _provenanceIdSearchId || isClosed) return;

      emitProvenanceSearch(currentProvenanceSearch.copyWith(
        provenanceIdSuggestions: results,
        isSearchingProvenanceId: false,
      ));
    } catch (e) {
      if (requestId == _provenanceIdSearchId && !isClosed) {
        emitProvenanceSearch(currentProvenanceSearch.copyWith(
          isSearchingProvenanceId: false,
          provenanceIdSuggestions: const [],
        ));
      }
    }
  }

  /// Called when user selects a suggestion from the autocomplete dropdown.
  void onProvenanceSuggestionSelected(
    ProvenanceSuggestion suggestion,
    ProvenanceMatchField field,
  ) {
    final search = currentProvenanceSearch;
    final next = search.copyWith(
      clonalIdMatch:
          field == ProvenanceMatchField.clonalId ? suggestion : null,
      accessionMatch:
          field == ProvenanceMatchField.accessionNumber ? suggestion : null,
      aliasMatch: field == ProvenanceMatchField.alias ? suggestion : null,
      provenanceIdMatch:
          field == ProvenanceMatchField.provenanceId ? suggestion : null,
      clonalIdSuggestions:
          field == ProvenanceMatchField.clonalId ? const [] : const [],
      accessionSuggestions:
          field == ProvenanceMatchField.accessionNumber ? const [] : const [],
      aliasSuggestions:
          field == ProvenanceMatchField.alias ? const [] : const [],
      provenanceIdSuggestions:
          field == ProvenanceMatchField.provenanceId ? const [] : const [],
      activeField: field,
    );

    switch (field) {
      case ProvenanceMatchField.clonalId:
        _lastSelectedClonalId = suggestion.aliasValue;
        break;
      case ProvenanceMatchField.accessionNumber:
        _lastSelectedAccessionNumber = suggestion.aliasValue;
        break;
      case ProvenanceMatchField.alias:
        _lastSelectedAlias = suggestion.aliasValue;
        break;
      case ProvenanceMatchField.provenanceId:
        _lastSelectedProvenanceId = suggestion.provenanceId;
        break;
    }

    emitProvenanceSearch(next);
  }

  /// Clear the match for a specific field.
  void onProvenanceMatchCleared(ProvenanceMatchField field) {
    final search = currentProvenanceSearch;
    final shouldClearActive = search.activeField == field;

    switch (field) {
      case ProvenanceMatchField.clonalId:
        _lastSelectedClonalId = null;
        emitProvenanceSearch(
          search.copyWith(
            clonalIdMatch: null,
            activeField: shouldClearActive ? null : search.activeField,
          ),
        );
        break;
      case ProvenanceMatchField.accessionNumber:
        _lastSelectedAccessionNumber = null;
        emitProvenanceSearch(
          search.copyWith(
            accessionMatch: null,
            activeField: shouldClearActive ? null : search.activeField,
          ),
        );
        break;
      case ProvenanceMatchField.alias:
        _lastSelectedAlias = null;
        emitProvenanceSearch(
          search.copyWith(
            aliasMatch: null,
            activeField: shouldClearActive ? null : search.activeField,
          ),
        );
        break;
      case ProvenanceMatchField.provenanceId:
        _lastSelectedProvenanceId = null;
        emitProvenanceSearch(
          search.copyWith(
            provenanceIdMatch: null,
            activeField: shouldClearActive ? null : search.activeField,
          ),
        );
        break;
    }
  }

  /// Clear all provenance search state (e.g., when species changes).
  void onProvenanceSearchReset() {
    _clonalIdDebounce?.cancel();
    _accessionDebounce?.cancel();
    _aliasDebounce?.cancel();
    _provenanceIdDebounce?.cancel();
    _lastSelectedClonalId = null;
    _lastSelectedAccessionNumber = null;
    _lastSelectedAlias = null;
    _lastSelectedProvenanceId = null;
    emitProvenanceSearch(const ProvenanceSearchState());
  }

  /// Cancel debounce timers. Must be called from the host's [close] override.
  void disposeProvenanceSearch() {
    _clonalIdDebounce?.cancel();
    _accessionDebounce?.cancel();
    _aliasDebounce?.cancel();
    _provenanceIdDebounce?.cancel();
  }
}
