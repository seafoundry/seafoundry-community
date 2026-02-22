// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/app_colors.dart';

/// Theme data for a specific event type
class EventThemeData {
  final Color primaryColor;
  final Color backgroundColor;
  final IconData icon;
  final int priority;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const EventThemeData({
    required this.primaryColor,
    required this.backgroundColor,
    required this.icon,
    this.priority = 0,
    this.titleStyle,
    this.subtitleStyle,
  });

  EventThemeData copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    IconData? icon,
    int? priority,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) {
    return EventThemeData(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      icon: icon ?? this.icon,
      priority: priority ?? this.priority,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    );
  }

  /// Get a fallback theme for unknown event types
  static EventThemeData fallback() {
    return const EventThemeData(
      primaryColor: AppColors.textSecondary,
      backgroundColor: AppColors.disabled,
      icon: Icons.event,
      priority: 0,
    );
  }
}

/// Theme extension for event styling
class EventTheme extends ThemeExtension<EventTheme> {
  final Map<EventThemeType, EventThemeData> themes;
  final EventThemeData defaultTheme;

  const EventTheme({required this.themes, required this.defaultTheme});

  /// Get theme data for a specific event type
  EventThemeData forType(EventThemeType type) {
    return themes[type] ?? defaultTheme;
  }

  /// Get theme data for an event
  EventThemeData forEvent(Event event) {
    final type = _getEventType(event);
    return forType(type);
  }

  EventThemeType _getEventType(Event event) {
    if (event is CreateEvent) return EventThemeType.create;
    if (event is MortalityEvent) return EventThemeType.mortality;
    if (event is ObservationEvent) return EventThemeType.observation;
    // MeasurementEvent and MaintenanceEvent not yet defined in models
    if (event is MoveInEvent) return EventThemeType.moveIn;
    if (event is MoveOutEvent) return EventThemeType.moveOut;
    if (event is InventoryEvent) return EventThemeType.inventory;
    return EventThemeType.unknown;
  }

  /// Default light theme
  static EventTheme light() {
    return EventTheme(
      themes: {
        EventThemeType.create: const EventThemeData(
          primaryColor: AppColors.createEventColor,
          backgroundColor: AppColors.success,
          icon: Icons.add_circle,
          priority: 1,
        ),
        EventThemeType.mortality: const EventThemeData(
          primaryColor: AppColors.mortalityEventColor,
          backgroundColor: AppColors.error,
          icon: Icons.warning,
          priority: 10,
        ),
        EventThemeType.observation: const EventThemeData(
          primaryColor: AppColors.observationEventColor,
          backgroundColor: AppColors.warning,
          icon: Icons.visibility,
          priority: 5,
        ),
        EventThemeType.measurement: const EventThemeData(
          primaryColor: AppColors.measurementEventColor,
          backgroundColor: AppColors.info,
          icon: Icons.straighten,
          priority: 3,
        ),
        EventThemeType.maintenance: const EventThemeData(
          primaryColor: AppColors.maintenanceEventColor,
          backgroundColor: AppColors.disabled,
          icon: Icons.build,
          priority: 2,
        ),
        EventThemeType.moveIn: const EventThemeData(
          primaryColor: AppColors.moveEventColor,
          backgroundColor: AppColors.secondary,
          icon: Icons.arrow_forward,
          priority: 4,
        ),
        EventThemeType.moveOut: const EventThemeData(
          primaryColor: AppColors.moveEventColor,
          backgroundColor: AppColors.secondary,
          icon: Icons.arrow_back,
          priority: 4,
        ),
        EventThemeType.inventory: const EventThemeData(
          primaryColor: AppColors.inventoryEventColor,
          backgroundColor: AppColors.disabled,
          icon: Icons.inventory,
          priority: 1,
        ),
        EventThemeType.unknown: EventThemeData.fallback(),
      },
      defaultTheme: EventThemeData.fallback(),
    );
  }

  @override
  ThemeExtension<EventTheme> copyWith({Map<EventThemeType, EventThemeData>? themes, EventThemeData? defaultTheme}) {
    return EventTheme(themes: themes ?? this.themes, defaultTheme: defaultTheme ?? this.defaultTheme);
  }

  @override
  ThemeExtension<EventTheme> lerp(covariant ThemeExtension<EventTheme>? other, double t) {
    if (other is! EventTheme) {
      return this;
    }
    return EventTheme(themes: themes, defaultTheme: defaultTheme);
  }
}

/// Event type enumeration for theming
enum EventThemeType { create, mortality, observation, measurement, maintenance, moveIn, moveOut, inventory, unknown }
