// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';

/// Immutable state for the genet alias editing dialog.
///
/// Manages alias entries, clonal ID, accession number, validation errors,
/// and submission status.
class GenetAliasState extends Equatable {
  const GenetAliasState({
    this.aliases = const [],
    this.clonalId = const GenetClonalId.pure(),
    this.accessionNumber = const GenetAccessionNumber.pure(),
    this.provenanceSearch = const ProvenanceSearchState(),
    this.aliasSearchValue = '',
    this.provenanceIdSearchValue = '',
    this.aliasErrors = const {},
    this.isSubmitting = false,
    this.errorText,
  });

  final List<GenetAliasEntry> aliases;
  final GenetClonalId clonalId;
  final GenetAccessionNumber accessionNumber;
  final ProvenanceSearchState provenanceSearch;
  final String aliasSearchValue;
  final String provenanceIdSearchValue;
  final Map<int, String?> aliasErrors;
  final bool isSubmitting;
  final String? errorText;

  /// Whether the form has any validation errors.
  bool get hasErrors {
    final hasAliasErrors = aliasErrors.values.whereType<String>().isNotEmpty;
    return hasAliasErrors ||
        !clonalId.isValid ||
        !accessionNumber.isValid ||
        provenanceSearch.hasConflict;
  }

  @override
  List<Object?> get props => [
        aliases,
        clonalId,
        accessionNumber,
        provenanceSearch,
        aliasSearchValue,
        provenanceIdSearchValue,
        aliasErrors,
        isSubmitting,
        errorText,
      ];

  GenetAliasState copyWith({
    List<GenetAliasEntry>? aliases,
    GenetClonalId? clonalId,
    GenetAccessionNumber? accessionNumber,
    ProvenanceSearchState? provenanceSearch,
    String? aliasSearchValue,
    String? provenanceIdSearchValue,
    Map<int, String?>? aliasErrors,
    bool? isSubmitting,
    String? errorText,
    bool clearErrorText = false,
  }) {
    return GenetAliasState(
      aliases: aliases ?? this.aliases,
      clonalId: clonalId ?? this.clonalId,
      accessionNumber: accessionNumber ?? this.accessionNumber,
      provenanceSearch: provenanceSearch ?? this.provenanceSearch,
      aliasSearchValue: aliasSearchValue ?? this.aliasSearchValue,
      provenanceIdSearchValue:
          provenanceIdSearchValue ?? this.provenanceIdSearchValue,
      aliasErrors: aliasErrors ?? this.aliasErrors,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorText: clearErrorText ? null : (errorText ?? this.errorText),
    );
  }
}
