import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/transfer/transfer_manual_register_state.dart';
import 'package:seafoundry_app/mixins/provenance_search_mixin.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

class TransferManualRegisterCubit extends Cubit<TransferManualRegisterState>
    with ProvenanceSearchMixin<TransferManualRegisterState> {
  TransferManualRegisterCubit({
    required ProvenanceLookupService? provenanceLookupService,
    String? speciesId,
  }) : _provenanceLookupService = provenanceLookupService,
       super(TransferManualRegisterState(speciesId: speciesId));

  final ProvenanceLookupService? _provenanceLookupService;

  @override
  ProvenanceLookupService? get provenanceLookupService =>
      _provenanceLookupService;

  @override
  String? get currentSpeciesCode {
    final speciesId = state.speciesId;
    if (speciesId == null) return null;
    return SpeciesRegistry.globalById(speciesId)?.code;
  }

  @override
  ProvenanceSearchState get currentProvenanceSearch => state.provenanceSearch;

  @override
  void emitProvenanceSearch(ProvenanceSearchState search) {
    emit(state.copyWith(provenanceSearch: search));
  }

  void setSpeciesId(String? speciesId) {
    emit(state.copyWith(speciesId: speciesId));
    onProvenanceSearchReset();
  }

  void clonalIdChanged(String value) {
    emit(state.copyWith(clonalId: value.isEmpty ? null : value));
    onClonalIdSearchChanged(value);
  }

  void accessionNumberChanged(String value) {
    emit(state.copyWith(accessionNumber: value.isEmpty ? null : value));
    onAccessionSearchChanged(value);
  }

  void aliasIdChanged(String value) {
    emit(state.copyWith(aliasId: value.isEmpty ? null : value));
    onAliasSearchChanged(value);
  }

  void provenanceIdChanged(String value) {
    emit(state.copyWith(provenanceId: value.isEmpty ? null : value));
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
            ? ClonalIdDisplayService.resolveForSuggestion(suggestion)
            : state.clonalId,
        accessionNumber: field == ProvenanceMatchField.accessionNumber
            ? suggestion.aliasValue
            : state.accessionNumber,
        aliasId: field == ProvenanceMatchField.alias
            ? suggestion.aliasValue
            : state.aliasId,
        provenanceId: suggestion.provenanceId,
      ),
    );
  }

  void clearProvenanceSelection() {
    onProvenanceSearchReset();
    emit(
      state.copyWith(
        clonalId: null,
        accessionNumber: null,
        aliasId: null,
        provenanceId: null,
      ),
    );
  }

  void setActiveProvenanceField(ProvenanceMatchField field) {
    emitProvenanceSearch(currentProvenanceSearch.copyWith(activeField: field));
  }

  @override
  Future<void> close() {
    disposeProvenanceSearch();
    return super.close();
  }
}
