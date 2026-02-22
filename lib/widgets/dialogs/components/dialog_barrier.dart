// @tier: community
import 'package:flutter/material.dart';

const double kDialogBarrierOpacity = 0.45;

/// Default scrim color for dialogs to prevent click-through on platform views.
Color dialogBarrierColor(BuildContext context) {
  return Theme.of(context)
      .colorScheme
      .scrim
      .withValues(alpha: kDialogBarrierOpacity);
}
