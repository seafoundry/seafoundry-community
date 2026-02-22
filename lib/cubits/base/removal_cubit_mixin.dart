// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/base_removal_state.dart';
import 'package:seafoundry_app/models/models.dart';

/// Mixin providing common removal cubit functionality.
///
/// This mixin provides the standard methods shared across all removal cubits:
/// - [reasonChanged] - Update the selected removal reason
/// - [commentChanged] - Update the comment
/// - [setSubmitting] - Set the submitting state
/// - [setError] - Set an error message
/// - [clearError] - Clear the error message
///
/// Subclasses should implement [validate] with type-specific validation logic.
///
/// ## Example Usage
/// ```dart
/// class GenetRemovalCubit extends Cubit<GenetRemovalState>
///     with RemovalCubitMixin<GenetRemovalState> {
///   GenetRemovalCubit() : super(const GenetRemovalState());
///
///   @override
///   bool validate() {
///     if (state.selectedReason == null) {
///       setError('Please select a removal reason');
///       return false;
///     }
///     return true;
///   }
/// }
/// ```
mixin RemovalCubitMixin<T extends BaseRemovalState> on Cubit<T> {
  /// Update selected reason.
  void reasonChanged(PopulationLossReason? reason) {
    emit(state.copyWith(selectedReason: reason, clearError: true) as T);
  }

  /// Update comment.
  void commentChanged(String comment) {
    emit(state.copyWith(comment: comment) as T);
  }

  /// Set submitting state.
  void setSubmitting(bool submitting) {
    emit(state.copyWith(isSubmitting: submitting) as T);
  }

  /// Set error message.
  void setError(String error) {
    emit(state.copyWith(error: error, isSubmitting: false) as T);
  }

  /// Clear error message.
  void clearError() {
    emit(state.clearError() as T);
  }

  /// Validate the current state.
  ///
  /// Subclasses should override this to implement type-specific validation.
  /// Call [setError] if validation fails.
  bool validate();
}
