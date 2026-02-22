// @tier: community
part of 'change_role_cubit.dart';

class ChangeRoleState {
  const ChangeRoleState({
    required this.selectedRoleId,
    this.stepIndex = 0,
  });

  final String selectedRoleId;
  final int stepIndex;

  ChangeRoleState copyWith({
    String? selectedRoleId,
    int? stepIndex,
  }) {
    return ChangeRoleState(
      selectedRoleId: selectedRoleId ?? this.selectedRoleId,
      stepIndex: stepIndex ?? this.stepIndex,
    );
  }
}
