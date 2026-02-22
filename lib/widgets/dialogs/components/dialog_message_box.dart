// @tier: community
import 'package:flutter/material.dart';

/// Lightweight banner for dialog surfaces to standardize informational,
/// warning, and error messaging across management dialogs.
class DialogMessageBox extends StatelessWidget {
  const DialogMessageBox({
    super.key,
    required this.child,
    this.tone = DialogMessageTone.info,
    this.icon,
    this.padding = const EdgeInsets.all(12),
  });

  factory DialogMessageBox.error(String message) {
    return DialogMessageBox(
      tone: DialogMessageTone.error,
      child: Text(message),
    );
  }

  factory DialogMessageBox.info(String message) {
    return DialogMessageBox(
      tone: DialogMessageTone.info,
      child: Text(message),
    );
  }

  factory DialogMessageBox.warning(String message) {
    return DialogMessageBox(
      tone: DialogMessageTone.warning,
      child: Text(message),
    );
  }

  factory DialogMessageBox.success(String message) {
    return DialogMessageBox(
      tone: DialogMessageTone.success,
      child: Text(message),
    );
  }

  final Widget child;
  final DialogMessageTone tone;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  ColorScheme _colors(BuildContext context) => Theme.of(context).colorScheme;

  (Color background, Color border, Color foreground) _resolveColors(
    BuildContext context,
  ) {
    final colors = _colors(context);
    switch (tone) {
      case DialogMessageTone.error:
        return (
          colors.error.withValues(alpha: 0.08),
          colors.error.withValues(alpha: 0.35),
          colors.error,
        );
      case DialogMessageTone.warning:
        return (
          Colors.orange.withValues(alpha: 0.08),
          Colors.orange.withValues(alpha: 0.35),
          Colors.orange,
        );
      case DialogMessageTone.success:
        return (
          colors.primary.withValues(alpha: 0.08),
          colors.primary.withValues(alpha: 0.35),
          colors.primary,
        );
      case DialogMessageTone.neutral:
        return (
          colors.surfaceContainerHighest.withValues(alpha: 0.35),
          colors.outline.withValues(alpha: 0.5),
          colors.onSurfaceVariant,
        );
      case DialogMessageTone.info:
        return (
          colors.primary.withValues(alpha: 0.08),
          colors.primary.withValues(alpha: 0.35),
          colors.primary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = _resolveColors(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? tone.icon,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: foreground),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Supported dialog banner tones.
enum DialogMessageTone { info, warning, error, success, neutral }

extension on DialogMessageTone {
  IconData get icon {
    switch (this) {
      case DialogMessageTone.error:
        return Icons.error_outline;
      case DialogMessageTone.warning:
        return Icons.warning_amber_outlined;
      case DialogMessageTone.success:
        return Icons.check_circle_outline;
      case DialogMessageTone.neutral:
        return Icons.info_outline;
      case DialogMessageTone.info:
        return Icons.info_outline;
    }
  }
}
