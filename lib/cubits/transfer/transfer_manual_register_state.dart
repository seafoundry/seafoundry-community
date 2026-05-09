import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';

class TransferManualRegisterState extends Equatable {
  const TransferManualRegisterState({
    this.speciesId,
    this.clonalId,
    this.accessionNumber,
    this.aliasId,
    this.provenanceId,
    this.provenanceSearch = const ProvenanceSearchState(),
  });

  final String? speciesId;
  final String? clonalId;
  final String? accessionNumber;
  final String? aliasId;
  final String? provenanceId;
  final ProvenanceSearchState provenanceSearch;

  TransferManualRegisterState copyWith({
    Object? speciesId = _undefined,
    Object? clonalId = _undefined,
    Object? accessionNumber = _undefined,
    Object? aliasId = _undefined,
    Object? provenanceId = _undefined,
    ProvenanceSearchState? provenanceSearch,
  }) {
    return TransferManualRegisterState(
      speciesId: speciesId == _undefined ? this.speciesId : speciesId as String?,
      clonalId: clonalId == _undefined ? this.clonalId : clonalId as String?,
      accessionNumber: accessionNumber == _undefined
          ? this.accessionNumber
          : accessionNumber as String?,
      aliasId: aliasId == _undefined ? this.aliasId : aliasId as String?,
      provenanceId: provenanceId == _undefined
          ? this.provenanceId
          : provenanceId as String?,
      provenanceSearch: provenanceSearch ?? this.provenanceSearch,
    );
  }

  @override
  List<Object?> get props => [
    speciesId,
    clonalId,
    accessionNumber,
    aliasId,
    provenanceId,
    provenanceSearch,
  ];
}

const _undefined = Object();
