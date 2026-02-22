// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// Standardized icon widget for events
class EventIcon extends StatelessWidget {
  final Event? event;
  final EventThemeType? eventType;
  final double size;
  final Color? color;

  const EventIcon({
    super.key,
    this.event,
    this.eventType,
    this.size = 24.0,
    this.color,
  });

  /// Create a small event icon (16px)
  const EventIcon.small({super.key, this.event, this.eventType, this.color}) : size = 16.0;

  /// Create a large event icon (32px)
  const EventIcon.large({super.key, this.event, this.eventType, this.color}) : size = 32.0;

  @override
  Widget build(BuildContext context) {
    final eventTheme = Theme.of(context).extension<EventTheme>();
    if (eventTheme == null) {
      // Fallback when EventTheme extension is not available
      return Icon(Icons.event, size: size, color: color ?? Colors.grey);
    }

    EventThemeData themeData;
    if (event != null) {
      themeData = eventTheme.forEvent(event!);
    } else if (eventType != null) {
      themeData = eventTheme.forType(eventType!);
    } else {
      themeData = eventTheme.defaultTheme;
    }

    return Icon(themeData.icon, size: size, color: color ?? themeData.primaryColor);
  }
}

/// Priority badge for events
class EventPriorityBadge extends StatelessWidget {
  final Event? event;
  final EventThemeType? eventType;

  const EventPriorityBadge({super.key, this.event, this.eventType});

  @override
  Widget build(BuildContext context) {
    final eventTheme = Theme.of(context).extension<EventTheme>();
    if (eventTheme == null) {
      return const SizedBox.shrink();
    }

    final themeData = event != null ? eventTheme.forEvent(event!) : eventTheme.forType(eventType!);

    if (themeData.priority <= 0) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    IconData? badgeIcon;

    if (themeData.priority >= 10) {
      badgeColor = AppColors.error;
      badgeIcon = Icons.priority_high;
    } else if (themeData.priority >= 5) {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.warning_amber;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(Spacing.xxs),
      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      child: Icon(badgeIcon, size: 12, color: Colors.white),
    );
  }
}
