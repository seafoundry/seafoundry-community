// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/base_removal_state.dart';
import 'package:seafoundry_app/models/models.dart';

/// State for OrganismRemovalDialog (generic holdings removal)
///
/// Follows the same pattern as CoralRemovalState but handles generic
/// OrganismRecord entities across all organism types (coral, kelp, oyster, etc).
class OrganismRemovalState extends Equatable implements BaseRemovalState {
  @override
  final PopulationLossReason? selectedReason;
  final String quantity;
  @override
  final String comment;
  @override
  final bool isSubmitting;
  @override
  final String? error;
  final MeasurementUnit? unit; // Track the unit for display

  const OrganismRemovalState({
    this.selectedReason,
    this.quantity = '',
    this.comment = '',
    this.isSubmitting = false,
    this.error,
    this.unit,
  });

  @override
  OrganismRemovalState copyWith({
    PopulationLossReason? selectedReason,
    String? quantity,
    String? comment,
    bool? isSubmitting,
    String? error,
    MeasurementUnit? unit,
    bool clearError = false,
  }) {
    return OrganismRemovalState(
      selectedReason: selectedReason ?? this.selectedReason,
      quantity: quantity ?? this.quantity,
      comment: comment ?? this.comment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      unit: unit ?? this.unit,
    );
  }

  @override
  OrganismRemovalState clearError() {
    return copyWith(clearError: true);
  }

  /// Check if the form is valid for submission
  bool get isValid =>
      selectedReason != null &&
      quantity.isNotEmpty &&
      double.tryParse(quantity) != null &&
      double.parse(quantity) > 0;

  /// Parsed numeric quantity (null when invalid)
  double? get parsedQuantity => double.tryParse(quantity);

  /// Get the unit display string
  String get unitDisplay => unit?.symbol ?? '';

  @override
  List<Object?> get props => [selectedReason, quantity, comment, isSubmitting, error, unit];
}
