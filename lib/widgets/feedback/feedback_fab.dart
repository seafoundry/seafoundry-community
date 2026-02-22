// @tier: community
import 'package:flutter/material.dart';

import 'package:seafoundry_app/widgets/dialogs/feedback_dialog.dart';

/// A small circular floating action button for sending feedback.
class FeedbackFab extends StatelessWidget {
  const FeedbackFab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // FeatureAccessService is not available at this widget tree level
    // (above MaterialApp.router), so Sebastian support defaults to false.
    // The drawer's feedback button still offers Sebastian for Scale tier users.
    // NOTE: Cannot use Tooltip or InkWell here - no Overlay/Material ancestor
    // above MaterialApp. Use GestureDetector instead.
    return GestureDetector(
      onTap: () => FeedbackDialog.show(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.6),
        ),
        child: Icon(
          Icons.feedback_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
