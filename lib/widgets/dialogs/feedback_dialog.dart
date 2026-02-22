// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/feedback_dialog_content.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

class FeedbackDialog extends StatelessWidget {
  const FeedbackDialog({
    super.key,
    required this.supportsSebastian,
    required this.userState,
    this.onOpenSebastian,
  });

  final bool supportsSebastian;
  final CurrentUserLoaded userState;
  final VoidCallback? onOpenSebastian;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onOpenSebastian,
  }) {
    final currentUserState = context.read<CurrentUser>().state;
    if (currentUserState is! CurrentUserLoaded) {
      return Future.value();
    }
    final featureAccess = context.maybeRead<FeatureAccessService>();
    final supportsSebastian = featureAccess?.supportsAiCopilot ?? false;
    return context.showSafeDialog<void>(
      useRootNavigator: false,
      builder: (dialogContext) => FeedbackDialog(
        userState: currentUserState,
        supportsSebastian: supportsSebastian,
        onOpenSebastian: onOpenSebastian,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(
        Icons.feedback_outlined,
        color: theme.colorScheme.primary,
        size: 40,
      ),
      title: const Text('Send Feedback'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: FeedbackDialogContent(
          user: userState.user,
          organization: userState.organization,
          supportsSebastian: supportsSebastian,
          onOpenSebastian: onOpenSebastian,
        ),
      ),
    );
  }
}
