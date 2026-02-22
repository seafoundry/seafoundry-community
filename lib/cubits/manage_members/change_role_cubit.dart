// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';

part 'change_role_state.dart';

class ChangeRoleCubit extends Cubit<ChangeRoleState> {
  ChangeRoleCubit({required String initialRoleId})
      : super(ChangeRoleState(selectedRoleId: initialRoleId));

  void selectRole(String roleId) {
    emit(state.copyWith(selectedRoleId: roleId));
  }

  void nextStep() {
    if (state.stepIndex >= 1) return;
    emit(state.copyWith(stepIndex: state.stepIndex + 1));
  }

  void previousStep() {
    if (state.stepIndex <= 0) return;
    emit(state.copyWith(stepIndex: state.stepIndex - 1));
  }
}
