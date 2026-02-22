// @tier: community
import 'package:seafoundry_app/models/models.dart';

/// Base interface for removal state classes.
///
/// All removal dialogs (genet, organism, group, site) share these common fields.
/// Implementing this interface allows the [RemovalCubitMixin] to work with any
/// removal state type.
abstract interface class BaseRemovalState {
  /// The selected reason for removal/archival.
  PopulationLossReason? get selectedReason;

  /// Optional comment explaining the removal.
  String get comment;

  /// Whether a submission is in progress.
  bool get isSubmitting;

  /// Error message to display, if any.
  String? get error;

  /// Create a copy with updated fields.
  ///
  /// When [clearError] is true, the error field is cleared.
  BaseRemovalState copyWith({
    PopulationLossReason? selectedReason,
    String? comment,
    bool? isSubmitting,
    String? error,
    bool clearError,
  });

  /// Clear the error message.
  BaseRemovalState clearError();
}
