// @tier: community
import 'package:flutter/material.dart';

import 'package:seafoundry_app/widgets/feedback/feedback_fab.dart';

/// A transparent Stack wrapper that overlays a [FeedbackFab] button
/// at the bottom-left corner of the screen, respecting safe area insets.
class FeedbackButtonOverlay extends StatelessWidget {
  const FeedbackButtonOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Stack(
      children: [
        child,
        Positioned(
          left: 12 + padding.left,
          bottom: 12 + padding.bottom,
          child: const FeedbackFab(),
        ),
      ],
    );
  }
}
