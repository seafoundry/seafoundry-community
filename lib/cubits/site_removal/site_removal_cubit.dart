// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/removal_cubit_mixin.dart';
import 'package:seafoundry_app/cubits/site_removal/site_removal_state.dart';

/// Cubit for managing site removal dialog state
///
/// Sites are major structures in the location hierarchy. This cubit validates
/// that sites have no child holdings (groups/organisms) before allowing removal.
/// Sites are archived (not deleted) with a loss reason for audit trail.
class SiteRemovalCubit extends Cubit<SiteRemovalState>
    with RemovalCubitMixin<SiteRemovalState> {
  SiteRemovalCubit() : super(const SiteRemovalState());

  /// Set child holdings flag
  void setHasChildHoldings(bool hasChildren) {
    emit(state.copyWith(hasChildHoldings: hasChildren));
  }

  @override
  bool validate() {
    if (state.hasChildHoldings) {
      setError(
        'Cannot archive site with existing groups or organisms. '
        'Please remove all holdings first.',
      );
      return false;
    }

    if (state.selectedReason == null) {
      setError('Please select a removal reason');
      return false;
    }

    return true;
  }
}
