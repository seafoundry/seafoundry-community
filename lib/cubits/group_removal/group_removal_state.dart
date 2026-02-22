// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/base_removal_state.dart';
import 'package:seafoundry_app/models/models.dart';

/// State for GroupRemovalDialog
///
/// Groups are sub-structures within sites. This state tracks removal state
/// and validates that no child organisms exist before allowing archival.
class GroupRemovalState extends Equatable implements BaseRemovalState {
  @override
  final PopulationLossReason? selectedReason;
  @override
  final String comment;
  @override
  final bool isSubmitting;
  @override
  final String? error;
  final bool hasChildHoldings;

  const GroupRemovalState({
    this.selectedReason,
    this.comment = '',
    this.isSubmitting = false,
    this.error,
    this.hasChildHoldings = false,
  });

  @override
  GroupRemovalState copyWith({
    PopulationLossReason? selectedReason,
    String? comment,
    bool? isSubmitting,
    String? error,
    bool? hasChildHoldings,
    bool clearError = false,
  }) {
    return GroupRemovalState(
      selectedReason: selectedReason ?? this.selectedReason,
      comment: comment ?? this.comment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      hasChildHoldings: hasChildHoldings ?? this.hasChildHoldings,
    );
  }

  @override
  GroupRemovalState clearError() {
    return copyWith(clearError: true);
  }

  /// Check if the form is valid for submission
  /// Requires a reason AND no child holdings
  bool get isValid => selectedReason != null && !hasChildHoldings;

  @override
  List<Object?> get props => [
    selectedReason,
    comment,
    isSubmitting,
    error,
    hasChildHoldings,
  ];
}
