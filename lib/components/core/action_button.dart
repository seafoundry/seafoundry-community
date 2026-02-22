// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/components/core/loading_indicator.dart';
import 'package:seafoundry_app/theme/theme.dart';

enum ActionButtonType { primary, secondary, text }

/// Standardized action button with loading state support
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isDestructive;
  final ButtonStyle? style;
  final Size? minimumSize;
  final ActionButtonType _buttonType;

  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.style,
    this.minimumSize,
  }) : _buttonType = ActionButtonType.primary;

  /// Primary action button (filled)
  const ActionButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.minimumSize,
  }) : style = null,
       _buttonType = ActionButtonType.primary;

  /// Secondary action button (outlined)
  const ActionButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.minimumSize,
  }) : style = null,
       _buttonType = ActionButtonType.secondary;

  /// Text action button (no background)
  const ActionButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.minimumSize,
  }) : style = null,
       _buttonType = ActionButtonType.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine foreground color based on button type
    final Color foregroundColor;
    if (isDestructive) {
      foregroundColor = AppColors.error;
    } else {
      switch (_buttonType) {
        case ActionButtonType.text:
        case ActionButtonType.secondary:
          foregroundColor = theme.colorScheme.primary;
        case ActionButtonType.primary:
          foregroundColor = theme.colorScheme.onPrimary;
      }
    }

    Widget child;
    if (isLoading) {
      child = LoadingIndicator.small(color: foregroundColor);
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), SizedBox(width: Spacing.sm)],
          Text(label),
        ],
      );
    }

    // Build button based on type
    switch (_buttonType) {
      case ActionButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: (style ?? TextButton.styleFrom()).copyWith(
            foregroundColor: WidgetStateProperty.all(foregroundColor),
            minimumSize: minimumSize != null ? WidgetStateProperty.all(minimumSize) : null,
          ),
          child: child,
        );

      case ActionButtonType.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: (style ?? OutlinedButton.styleFrom()).copyWith(
            foregroundColor: WidgetStateProperty.all(foregroundColor),
            side: isDestructive ? WidgetStateProperty.all(BorderSide(color: AppColors.error)) : null,
            minimumSize: minimumSize != null ? WidgetStateProperty.all(minimumSize) : null,
          ),
          child: child,
        );

      case ActionButtonType.primary:
        final backgroundColor = isDestructive ? AppColors.error : theme.colorScheme.primary;

        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: (style ?? ElevatedButton.styleFrom()).copyWith(
            backgroundColor: WidgetStateProperty.all(backgroundColor),
            foregroundColor: WidgetStateProperty.all(foregroundColor),
            minimumSize: minimumSize != null ? WidgetStateProperty.all(minimumSize) : null,
          ),
          child: child,
        );
    }
  }
}
