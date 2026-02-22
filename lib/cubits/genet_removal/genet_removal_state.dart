// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/base_removal_state.dart';
import 'package:seafoundry_app/models/models.dart';

/// State for GenetRemovalDialog
///
/// Unlike coral removal (which tracks quantity changes), genet removal uses
/// archival pattern. Genets are individual genetic entities, so removal means
/// archiving the record with a loss reason.
class GenetRemovalState extends Equatable implements BaseRemovalState {
  @override
  final PopulationLossReason? selectedReason;
  @override
  final String comment;
  @override
  final bool isSubmitting;
  @override
  final String? error;

  const GenetRemovalState({
    this.selectedReason,
    this.comment = '',
    this.isSubmitting = false,
    this.error,
  });

  @override
  GenetRemovalState copyWith({
    PopulationLossReason? selectedReason,
    String? comment,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return GenetRemovalState(
      selectedReason: selectedReason ?? this.selectedReason,
      comment: comment ?? this.comment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  GenetRemovalState clearError() {
    return copyWith(clearError: true);
  }

  /// Check if the form is valid for submission
  bool get isValid => selectedReason != null;

  @override
  List<Object?> get props => [selectedReason, comment, isSubmitting, error];
}
