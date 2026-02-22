// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Base widget for event detail cards with common styling and container functionality
abstract class BaseEventDetails extends StatelessWidget {
  final Event event;
  final Color? backgroundColor;
  final Color? borderColor;
  final IconData? icon;
  final Color? iconColor;
  final String? title;

  const BaseEventDetails({
    super.key,
    required this.event,
    this.backgroundColor,
    this.borderColor,
    this.icon,
    this.iconColor,
    this.title,
  });

  /// Override this method to provide the content for the event details
  Widget buildEventContent(BuildContext context);

  /// Override this method to provide the default colors for the event type
  EventColors getDefaultColors();

  @override
  Widget build(BuildContext context) {
    final colors = getDefaultColors();
    final effectiveBackgroundColor = backgroundColor ?? colors.backgroundColor;
    final effectiveBorderColor = borderColor ?? colors.borderColor;
    final effectiveIconColor = iconColor ?? colors.iconColor;

    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null || title != null) ...[
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: effectiveIconColor), SizedBox(width: Spacing.sm)],
                if (title != null) UIText.bodySmall(title!, color: AppColors.textSecondary),
              ],
            ),
            SizedBox(height: Spacing.sm),
          ],
          buildEventContent(context),
        ],
      ),
    );
  }
}

/// Event color scheme for consistent theming
class EventColors {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;

  const EventColors({required this.backgroundColor, required this.borderColor, required this.iconColor});

  factory EventColors.fromBaseColor(Color baseColor) {
    return EventColors(
      backgroundColor: baseColor.withValues(alpha: 0.05),
      borderColor: baseColor.withValues(alpha: 0.2),
      iconColor: baseColor,
    );
  }
}

/// Simple event details widget for basic events that only show an ID or simple info
class SimpleEventDetails extends BaseEventDetails {
  const SimpleEventDetails({
    super.key,
    required super.event,
    super.backgroundColor,
    super.borderColor,
    super.icon,
    super.iconColor,
    super.title,
  });

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(Colors.grey);

  @override
  Widget buildEventContent(BuildContext context) {
    return UIText.caption('Event ID: ${event.id}', color: AppColors.textSecondary);
  }
}

/// Helper widget for displaying key-value pairs in event details
class EventDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const EventDetailRow({super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: AppColors.textSecondary), SizedBox(width: Spacing.sm)],
        UIText.caption('$label: ', color: AppColors.textSecondary),
        Expanded(child: UIText.bodyMedium(value)),
      ],
    );
  }
}

/// Helper widget for displaying lists in event details
class EventDetailList extends StatelessWidget {
  final String label;
  final List<String> items;
  final IconData? icon;

  const EventDetailList({super.key, required this.label, required this.items, this.icon});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: AppColors.textSecondary), SizedBox(width: Spacing.sm)],
            UIText.caption('$label:', color: AppColors.textSecondary),
          ],
        ),
        SizedBox(height: Spacing.xs),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(left: Spacing.md),
            child: UIText.bodyMedium('• $item'),
          ),
        ),
      ],
    );
  }
}
