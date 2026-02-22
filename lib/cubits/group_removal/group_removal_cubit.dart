// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/removal_cubit_mixin.dart';
import 'package:seafoundry_app/cubits/group_removal/group_removal_state.dart';

/// Cubit for managing group removal dialog state
///
/// Groups are sub-structures within sites. This cubit validates that groups
/// have no child organisms before allowing removal. Groups are archived (not
/// deleted) with a loss reason for audit trail.
class GroupRemovalCubit extends Cubit<GroupRemovalState>
    with RemovalCubitMixin<GroupRemovalState> {
  GroupRemovalCubit() : super(const GroupRemovalState());

  /// Set child holdings flag
  void setHasChildHoldings(bool hasChildren) {
    emit(state.copyWith(hasChildHoldings: hasChildren));
  }

  @override
  bool validate() {
    if (state.hasChildHoldings) {
      setError(
        'Cannot archive group with existing organisms. '
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
