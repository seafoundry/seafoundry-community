// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/removal_cubit_mixin.dart';
import 'package:seafoundry_app/cubits/organism_removal/organism_removal_state.dart';
import 'package:seafoundry_app/models/models.dart';

/// Cubit for managing organism (generic holding) removal dialog state
///
/// Handles removal operations for any OrganismRecord type across all
/// organism kinds (coral, kelp, oyster, seagrass, etc). This is the
/// generic version that works with the multi-organism taxonomy system.
class OrganismRemovalCubit extends Cubit<OrganismRemovalState>
    with RemovalCubitMixin<OrganismRemovalState> {
  OrganismRemovalCubit({required String initialQuantity, MeasurementUnit? unit})
    : super(OrganismRemovalState(quantity: initialQuantity, unit: unit));

  /// Update quantity
  void quantityChanged(String quantity) {
    emit(state.copyWith(quantity: quantity, clearError: true));
  }

  @override
  bool validate() {
    if (state.selectedReason == null) {
      setError('Please select a removal reason');
      return false;
    }

    final qty = double.tryParse(state.quantity);
    if (qty == null || qty <= 0) {
      setError('Please enter a valid quantity');
      return false;
    }

    return true;
  }

  /// Get the parsed quantity value
  double? get parsedQuantity => double.tryParse(state.quantity);
}
