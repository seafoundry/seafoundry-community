// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/manage_members/change_role_cubit.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog.dart';

class ChangeRoleDialog extends StatelessWidget {
  const ChangeRoleDialog({
    super.key,
    required this.memberName,
    required this.canAssignAdmin,
    required this.adminLimit,
    required this.canAssignPractitioner,
    required this.practitionerLimit,
  });

  final String memberName;
  final bool canAssignAdmin;
  final int adminLimit;
  final bool canAssignPractitioner;
  final int practitionerLimit;

  static Future<String?> show(
    BuildContext context, {
    required String memberName,
    required String initialRoleId,
    required bool canAssignAdmin,
    required int adminLimit,
    required bool canAssignPractitioner,
    required int practitionerLimit,
  }) {
    return context.showSafeDialog<String>(
      builder: (dialogContext) => BlocProvider(
        create: (_) => ChangeRoleCubit(initialRoleId: initialRoleId),
        child: ChangeRoleDialog(
          memberName: memberName,
          canAssignAdmin: canAssignAdmin,
          adminLimit: adminLimit,
          canAssignPractitioner: canAssignPractitioner,
          practitionerLimit: practitionerLimit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeRoleCubit, ChangeRoleState>(
      builder: (context, state) {
        final selectedRole =
            UserRole.fromId(state.selectedRoleId) ?? UserRole.practitioner;
        final isAdminSelected = selectedRole == UserRole.admin;
        final adminBlocked = isAdminSelected && !canAssignAdmin;

        return AlertDialog(
          title: Text(
            state.stepIndex == 0
                ? 'Change Role for $memberName'
                : 'Confirm Role Change',
          ),
          content: SizedBox(
            width: 460,
            child: state.stepIndex == 0
                ? _RoleSelectionStep(
                    selectedRoleId: state.selectedRoleId,
                    canAssignAdmin: canAssignAdmin,
                    adminLimit: adminLimit,
                    canAssignPractitioner: canAssignPractitioner,
                    practitionerLimit: practitionerLimit,
                  )
                : _RoleConfirmationStep(role: selectedRole),
          ),
          actions: _buildActions(context, state.stepIndex, adminBlocked, selectedRole),
        );
      },
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    int stepIndex,
    bool adminBlocked,
    UserRole selectedRole,
  ) {
    if (stepIndex == 0) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: adminBlocked
              ? null
              : () => context.read<ChangeRoleCubit>().nextStep(),
          child: const Text('Next'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => context.read<ChangeRoleCubit>().previousStep(),
        child: const Text('Back'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, selectedRole.id),
        child: const Text('Confirm'),
      ),
    ];
  }
}

class _RoleSelectionStep extends StatelessWidget {
  const _RoleSelectionStep({
    required this.selectedRoleId,
    required this.canAssignAdmin,
    required this.adminLimit,
    required this.canAssignPractitioner,
    required this.practitionerLimit,
  });

  final String selectedRoleId;
  final bool canAssignAdmin;
  final int adminLimit;
  final bool canAssignPractitioner;
  final int practitionerLimit;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selectedRoleId,
      onChanged: (value) {
        if (value != null) {
          context.read<ChangeRoleCubit>().selectRole(value);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...UserRole.values.map((role) {
            final isAdmin = role == UserRole.admin;
            final isPractitioner = role == UserRole.practitioner;
            final isEnabled = (!isAdmin || canAssignAdmin) &&
                (!isPractitioner || canAssignPractitioner);
            final adminNote = isAdmin && !canAssignAdmin
                ? 'Admin seats are limited to ${_limitLabel(adminLimit)}.'
                : null;
            final practitionerNote = isPractitioner && !canAssignPractitioner
                ? 'Practitioner seats are limited to ${_limitLabel(practitionerLimit)}.'
                : null;

            return RadioListTile<String>(
              title: Text(role.label),
              subtitle: Text(
                adminNote ?? practitionerNote ?? role.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? Colors.grey.shade700 : Colors.grey.shade500,
                ),
              ),
              value: role.id,
              enabled: isEnabled,
            );
          }),
        ],
      ),
    );
  }

  String _limitLabel(int limit) {
    return limit < 0 ? 'Unlimited' : '$limit';
  }
}

class _RoleConfirmationStep extends StatelessWidget {
  const _RoleConfirmationStep({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected role: ${role.label}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          role.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text(
          'Role changes may affect seat billing. Review totals in the Billing Portal.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
