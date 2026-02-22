// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/genet_alias/genet_alias_state.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/mixins/provenance_search_mixin.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/common/alias_editor.dart';

/// Cubit for managing genet alias editing state.
///
/// Handles alias CRUD operations, clonal ID, accession number, validation,
/// and submission to the provenance repository.
class GenetAliasCubit extends Cubit<GenetAliasState>
    with ProvenanceSearchMixin<GenetAliasState> {
  GenetAliasCubit({
    required ProvenanceRecord record,
    required ProvenanceRepository provenanceRepository,
    required ProvenanceLookupService? provenanceLookupService,
  }) : _record = record,
       _provenanceRepository = provenanceRepository,
       _provenanceLookupService = provenanceLookupService,
       super(_initialState(record));

  final ProvenanceRecord _record;
  final ProvenanceRepository _provenanceRepository;
  final ProvenanceLookupService? _provenanceLookupService;

  @override
  ProvenanceLookupService? get provenanceLookupService =>
      _provenanceLookupService;

  @override
  String? get currentSpeciesCode {
    final speciesId = _record.speciesId.trim();
    if (speciesId.isEmpty) return null;
    return SpeciesRegistry.globalById(speciesId)?.code;
  }

  @override
  ProvenanceSearchState get currentProvenanceSearch => state.provenanceSearch;

  @override
  void emitProvenanceSearch(ProvenanceSearchState search) {
    emit(state.copyWith(provenanceSearch: search));
  }

  static GenetAliasState _initialState(ProvenanceRecord record) {
    final aliases = record.aliasEntries
        .map(GenetAliasEntry.fromOrganismAlias)
        .toList(growable: true);
    final resolvedClonalId =
        ClonalIdDisplayService.resolveForProvenanceRecord(record) ??
        record.clonalId;
    return GenetAliasState(
      aliases: aliases,
      clonalId: GenetClonalId.dirty(resolvedClonalId),
      accessionNumber: GenetAccessionNumber.dirty(record.accessionNumber),
    );
  }

  /// Add a new empty alias entry.
  void addAlias() {
    final updatedAliases = List<GenetAliasEntry>.from(state.aliases)
      ..add(const GenetAliasEntry());
    emit(
      state.copyWith(
        aliases: updatedAliases,
        aliasErrors: const {},
        clearErrorText: true,
      ),
    );
  }

  /// Remove the alias at the specified index.
  void removeAlias(int index) {
    if (index < 0 || index >= state.aliases.length) return;
    final updatedAliases = List<GenetAliasEntry>.from(state.aliases)
      ..removeAt(index);
    emit(
      state.copyWith(
        aliases: updatedAliases,
        aliasErrors: const {},
        clearErrorText: true,
      ),
    );
  }

  /// Update the value of an alias at the specified index.
  void updateAliasValue(int index, String value) {
    if (index < 0 || index >= state.aliases.length) return;
    final updatedAliases = List<GenetAliasEntry>.from(state.aliases);
    updatedAliases[index] = updatedAliases[index].copyWith(value: value);
    emit(
      state.copyWith(
        aliases: updatedAliases,
        aliasErrors: const {},
        clearErrorText: true,
      ),
    );
  }

  /// Update the source system of an alias at the specified index.
  void updateAliasSource(int index, String source) {
    if (index < 0 || index >= state.aliases.length) return;
    final updatedAliases = List<GenetAliasEntry>.from(state.aliases);
    updatedAliases[index] = updatedAliases[index].copyWith(
      sourceSystem: source,
    );
    emit(
      state.copyWith(
        aliases: updatedAliases,
        aliasErrors: const {},
        clearErrorText: true,
      ),
    );
  }

  /// Update the label of an alias at the specified index.
  void updateAliasLabel(int index, String label) {
    if (index < 0 || index >= state.aliases.length) return;
    final updatedAliases = List<GenetAliasEntry>.from(state.aliases);
    updatedAliases[index] = updatedAliases[index].copyWith(label: label);
    emit(
      state.copyWith(
        aliases: updatedAliases,
        aliasErrors: const {},
        clearErrorText: true,
      ),
    );
  }

  /// Update the clonal ID field.
  void updateClonalId(String value) {
    emit(
      state.copyWith(
        clonalId: GenetClonalId.dirty(value),
        clearErrorText: true,
      ),
    );
    onClonalIdSearchChanged(value);
  }

  /// Update the accession number field.
  void updateAccessionNumber(String value) {
    emit(
      state.copyWith(
        accessionNumber: GenetAccessionNumber.dirty(value),
        clearErrorText: true,
      ),
    );
    onAccessionSearchChanged(value);
  }

  void updateAliasSearchValue(String value) {
    emit(state.copyWith(aliasSearchValue: value, clearErrorText: true));
    onAliasSearchChanged(value);
  }

  void updateProvenanceIdSearchValue(String value) {
    emit(state.copyWith(provenanceIdSearchValue: value, clearErrorText: true));
    onProvenanceIdSearchChanged(value);
  }

  void selectProvenanceSuggestion(
    ProvenanceSuggestion suggestion,
    ProvenanceMatchField field,
  ) {
    onProvenanceSuggestionSelected(suggestion, field);
    emit(
      state.copyWith(
        clonalId: field == ProvenanceMatchField.clonalId
            ? GenetClonalId.dirty(
                ClonalIdDisplayService.resolveForSuggestion(suggestion),
              )
            : state.clonalId,
        accessionNumber: field == ProvenanceMatchField.accessionNumber
            ? GenetAccessionNumber.dirty(suggestion.aliasValue)
            : state.accessionNumber,
        aliasSearchValue: field == ProvenanceMatchField.alias
            ? suggestion.aliasValue
            : state.aliasSearchValue,
        provenanceIdSearchValue: suggestion.provenanceId,
        clearErrorText: true,
      ),
    );
  }

  void clearProvenanceSelection() {
    onProvenanceSearchReset();
    emit(
      state.copyWith(
        clonalId: const GenetClonalId.dirty(''),
        accessionNumber: const GenetAccessionNumber.dirty(''),
        aliasSearchValue: '',
        provenanceIdSearchValue: '',
        clearErrorText: true,
      ),
    );
  }

  void setActiveProvenanceField(ProvenanceMatchField field) {
    emitProvenanceSearch(currentProvenanceSearch.copyWith(activeField: field));
  }

  /// Validate the current state and update error messages.
  ///
  /// Returns true if the form is valid.
  bool validate() {
    final errors = buildAliasErrorMap(state.aliases);
    final clonalId = state.clonalId.isPure
        ? GenetClonalId.dirty(state.clonalId.value)
        : state.clonalId;
    final accessionNumber = state.accessionNumber.isPure
        ? GenetAccessionNumber.dirty(state.accessionNumber.value)
        : state.accessionNumber;
    final hasAliasErrors = errors.values.whereType<String>().isNotEmpty;
    final hasIdErrors = !clonalId.isValid || !accessionNumber.isValid;
    final hasConflict = state.provenanceSearch.hasConflict;

    String? errorText;
    if (hasAliasErrors) {
      errorText = 'Fix duplicate or empty aliases to continue.';
    } else if (hasIdErrors) {
      errorText = 'Fix invalid clonal ID or accession number to continue.';
    } else if (hasConflict) {
      errorText =
          state.provenanceSearch.conflictMessage ??
          'Conflicting provenance matches. Clear one field to resolve.';
    }

    emit(
      state.copyWith(
        aliasErrors: errors,
        clonalId: clonalId,
        accessionNumber: accessionNumber,
        errorText: errorText,
        clearErrorText: errorText == null,
      ),
    );

    return !hasAliasErrors && !hasIdErrors && !hasConflict;
  }

  /// Submit the alias changes to the repository.
  ///
  /// Returns the updated [ProvenanceRecord] on success, or null on failure.
  Future<ProvenanceRecord?> submit() async {
    if (!validate()) return null;

    emit(state.copyWith(isSubmitting: true, clearErrorText: true));

    try {
      final updatedAliases = state.aliases
          .map((e) => e.toOrganismAlias())
          .toList();
      final updatedMetadata = Map<String, dynamic>.from(_record.metadata);
      final clonalValue = state.clonalId.value?.trim();
      final accessionValue = state.accessionNumber.value?.trim();

      if (clonalValue == null || clonalValue.isEmpty) {
        updatedMetadata.remove('clonalId');
      } else {
        updatedMetadata['clonalId'] = clonalValue;
      }
      if (accessionValue == null || accessionValue.isEmpty) {
        updatedMetadata.remove('accessionNumber');
      } else {
        updatedMetadata['accessionNumber'] = accessionValue;
      }
      updatedMetadata['aliases'] = updatedAliases
          .map((a) => a.toJson())
          .toList();

      final updatedRecord = _record.copyWith(
        aliasLabels: updatedAliases.map((a) => a.label ?? a.value).toList(),
        metadata: updatedMetadata,
      );
      final persisted = await _provenanceRepository.updateProvenanceRecord(
        updatedRecord,
      );

      if (isClosed) return null;

      emit(state.copyWith(isSubmitting: false));
      return persisted;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to update aliases',
        error,
        stackTrace,
      );
      if (isClosed) return null;
      emit(state.copyWith(errorText: error.toString(), isSubmitting: false));
      return null;
    }
  }

  @override
  Future<void> close() {
    disposeProvenanceSearch();
    return super.close();
  }
}
