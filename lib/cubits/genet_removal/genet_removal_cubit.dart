// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/removal_cubit_mixin.dart';
import 'package:seafoundry_app/cubits/genet_removal/genet_removal_state.dart';

/// Cubit for managing genet removal dialog state
///
/// Unlike CoralRemovalCubit (quantity-based), this uses an archival pattern.
/// Genets are individual genetic entities, so removal means archiving with
/// a loss reason rather than decrementing quantity.
class GenetRemovalCubit extends Cubit<GenetRemovalState>
    with RemovalCubitMixin<GenetRemovalState> {
  GenetRemovalCubit() : super(const GenetRemovalState());

  @override
  bool validate() {
    if (state.selectedReason == null) {
      setError('Please select a removal reason');
      return false;
    }
    return true;
  }
}
