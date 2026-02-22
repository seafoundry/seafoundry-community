// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Centralized organism visual theme constants
///
/// Provides consistent colors, icons, and visual styling for all organism types
/// Based on visual_design_system.md specifications
///
/// Usage:
/// ```dart
/// final color = OrganismVisuals.colors[OrganismKind.coral];
/// final icon = OrganismVisuals.icons[OrganismKind.coral];
/// ```
class OrganismVisuals {
  OrganismVisuals._(); // Private constructor to prevent instantiation

  /// Organism brand colors
  /// Source: docs/ui_ux/visual_design_system.md
  ///
  /// WCAG AA Accessibility Notes:
  /// - Coral, seagrass, crab: Use for large text (18px+) only
  /// - Finfish: Updated to #0288D1 for universal WCAG AA compliance (4.5:1 ratio)
  /// - Kelp, oyster: Safe for all text sizes
  static const Map<OrganismKind, Color> colors = {
    OrganismKind.coral: Color(0xFFFF6F61), // Red (large text only)
    OrganismKind.kelp: Color(0xFF689F38), // Green
    OrganismKind.oyster: Color(0xFF78909C), // Gray
    OrganismKind.seagrass: Color(0xFF66BB6A), // Green (large text only)
    OrganismKind.mangrove: Color(0xFF8D6E63), // Brown
    OrganismKind.finfish: Color(0xFF0288D1), // Blue (WCAG AA compliant 4.5:1)
    OrganismKind.crab: Color(0xFFFF7043), // Orange (large text only)
    OrganismKind.echinoid: Color(0xFF9575CD), // Purple (Urchin)
    OrganismKind.seaCucumber: Color(0xFF00ACC1), // Teal (Generic Marine)
  };

  /// Organism icons for visual selection
  /// Uses Material Icons for consistency
  static const Map<OrganismKind, IconData> icons = {
    OrganismKind.coral: Icons.water, // Coral structure
    OrganismKind.kelp: Icons.grass, // Kelp fronds
    OrganismKind.oyster: Icons.circle, // Oyster shell
    OrganismKind.seagrass: Icons.eco, // Seagrass blades
    OrganismKind.mangrove: Icons.park, // Mangrove tree
    OrganismKind.finfish: Icons.waves, // Fish
    OrganismKind.crab: Icons.pest_control, // Crab/crustacean
    OrganismKind.echinoid: Icons.bubble_chart, // Urchin (matches original)
    OrganismKind.seaCucumber: Icons.straighten, // Cucumber shape
  };

  /// Get color for organism kind, with fallback
  static Color getColor(OrganismKind kind, {Color? fallback}) {
    return colors[kind] ?? fallback ?? Colors.grey;
  }

  /// Get icon for organism kind, with fallback
  static IconData getIcon(OrganismKind kind, {IconData? fallback}) {
    return icons[kind] ?? fallback ?? Icons.category;
  }

  /// Get life stage count display text for organism kind
  static String getLifeStageCountText(OrganismKind kind) {
    final stageCount = kind.metadata.lifeStages.length;
    return '$stageCount life stages';
  }
}

/// Health status visual theme constants
class HealthStatusVisuals {
  HealthStatusVisuals._(); // Private constructor

  /// Health status colors
  /// Semantic colors indicating organism health state
  static const Map<String, Color> colors = {
    'healthy': Color(0xFF4CAF50), // Green - good health
    'recovering': Color(0xFF2196F3), // Blue - improving
    'diseased': Color(0xFFFF9800), // Orange - needs attention
    'stressed': Color(0xFFFF5722), // Deep orange - critical
  };

  /// Health status icons
  static const Map<String, IconData> icons = {
    'healthy': Icons.check_circle, // Healthy checkmark
    'recovering': Icons.healing, // Recovery/healing
    'diseased': Icons.warning, // Warning/caution
    'stressed': Icons.error_outline, // Error/critical (matches original)
  };

  /// Get color for health status, with fallback
  static Color getColor(String status, {Color? fallback}) {
    return colors[status.toLowerCase()] ?? fallback ?? Colors.grey;
  }

  /// Get icon for health status, with fallback
  static IconData getIcon(String status, {IconData? fallback}) {
    return icons[status.toLowerCase()] ?? fallback ?? Icons.help;
  }
}
