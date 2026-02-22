// @tier: community
import 'package:flutter/material.dart';

/// Registry of icons used in reporting features.
///
/// This registry pattern allows icons to be serialized as strings while
/// maintaining proper tree shaking. Only icons explicitly listed here
/// will be included in the build.
class ReportIconRegistry {
  ReportIconRegistry._();

  /// Map of icon names to their IconData.
  /// Add new icons here as needed for reporting features.
  static const Map<String, IconData> _icons = {
    // KPI icons
    'eco': Icons.eco,
    'favorite': Icons.favorite,
    'moving': Icons.moving,
    'fingerprint': Icons.fingerprint,
    'nature': Icons.nature,
    'health_and_safety': Icons.health_and_safety,

    // Template category icons
    'calendar_month': Icons.calendar_month,
    'medical_services': Icons.medical_services,
    'calendar_today': Icons.calendar_today,
    'bar_chart': Icons.bar_chart,
    'dashboard': Icons.dashboard,
    'assessment': Icons.assessment,
    'analytics': Icons.analytics,
    'insights': Icons.insights,
    'timeline': Icons.timeline,
    'pie_chart': Icons.pie_chart,
    'show_chart': Icons.show_chart,
    'table_chart': Icons.table_chart,

    // Trend icons
    'trending_up': Icons.trending_up,
    'trending_down': Icons.trending_down,
    'trending_flat': Icons.trending_flat,

    // General icons
    'water_drop': Icons.water_drop,
    'science': Icons.science,
    'spa': Icons.spa,
    'pets': Icons.pets,
    'waves': Icons.waves,
    'public': Icons.public,
    'location_on': Icons.location_on,
    'groups': Icons.groups,
    'inventory': Icons.inventory,
    'event': Icons.event,
  };

  /// Get an icon by name. Returns null if not found.
  static IconData? get(String? name) {
    if (name == null) return null;
    return _icons[name];
  }

  /// Get an icon by name with a fallback.
  static IconData getOrDefault(String? name, IconData defaultIcon) {
    return get(name) ?? defaultIcon;
  }

  /// Check if an icon name is registered.
  static bool contains(String name) => _icons.containsKey(name);

  /// Get the name for an IconData (reverse lookup).
  /// Returns null if the icon is not in the registry.
  static String? nameFor(IconData icon) {
    for (final entry in _icons.entries) {
      if (entry.value.codePoint == icon.codePoint) {
        return entry.key;
      }
    }
    return null;
  }
}
