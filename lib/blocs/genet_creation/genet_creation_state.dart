// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';

abstract class GenetCreationState extends Equatable {
  const GenetCreationState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class GenetCreationInitial extends GenetCreationState {}

class _GenetCreationInProgressSentinel {
  const _GenetCreationInProgressSentinel();
}

const _sentinel = _GenetCreationInProgressSentinel();

/// Creating state with form
class GenetCreationInProgress extends GenetCreationState {
  final GenetFormState formState;
  final String? nameValidationError;
  final String? suggestedName;
  final bool isEditing;
  final Genet? originalGenet;
  final ProvenanceSearchState provenanceSearch;
  final bool nameValidationInProgress;
  final String aliasSearchValue;
  final String provenanceIdSearchValue;

  const GenetCreationInProgress({
    required this.formState,
    this.nameValidationError,
    this.suggestedName,
    this.isEditing = false,
    this.originalGenet,
    this.provenanceSearch = const ProvenanceSearchState(),
    this.nameValidationInProgress = false,
    this.aliasSearchValue = '',
    this.provenanceIdSearchValue = '',
  });

  GenetCreationInProgress copyWith({
    GenetFormState? formState,
    Object? nameValidationError = _sentinel,
    Object? suggestedName = _sentinel,
    bool? isEditing,
    Object? originalGenet = _sentinel,
    ProvenanceSearchState? provenanceSearch,
    bool? nameValidationInProgress,
    String? aliasSearchValue,
    String? provenanceIdSearchValue,
  }) {
    return GenetCreationInProgress(
      formState: formState ?? this.formState,
      nameValidationError: nameValidationError == _sentinel
          ? this.nameValidationError
          : nameValidationError as String?,
      suggestedName: suggestedName == _sentinel
          ? this.suggestedName
          : suggestedName as String?,
      isEditing: isEditing ?? this.isEditing,
      originalGenet: originalGenet == _sentinel
          ? this.originalGenet
          : originalGenet as Genet?,
      provenanceSearch: provenanceSearch ?? this.provenanceSearch,
      nameValidationInProgress: nameValidationInProgress ?? this.nameValidationInProgress,
      aliasSearchValue: aliasSearchValue ?? this.aliasSearchValue,
      provenanceIdSearchValue:
          provenanceIdSearchValue ?? this.provenanceIdSearchValue,
    );
  }

  @override
  List<Object?> get props => [
    formState,
    nameValidationError,
    suggestedName,
    isEditing,
    originalGenet,
    provenanceSearch,
    nameValidationInProgress,
    aliasSearchValue,
    provenanceIdSearchValue,
  ];
}

/// Successfully created
class GenetCreationSuccess extends GenetCreationState {
  final Genet genet;

  const GenetCreationSuccess(this.genet);

  @override
  List<Object?> get props => [genet];
}

/// Successfully updated an existing genet
class GenetUpdateSuccess extends GenetCreationState {
  final Genet genet;
  final Map<String, dynamic> changes;

  const GenetUpdateSuccess(this.genet, {this.changes = const {}});

  @override
  List<Object?> get props => [genet, changes];
}

/// Error state
class GenetCreationError extends GenetCreationState {
  final String message;

  const GenetCreationError(this.message);

  @override
  List<Object?> get props => [message];
}
