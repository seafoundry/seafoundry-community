import 'package:flutter/material.dart';

/// Centralized color palette for the app
class AppColors {
  AppColors._();

  // Primary brand colors (Oceanic - Deep Teal)
  static const Color primary = Color(0xFF006064); // Cyan 900
  static const Color primaryDark = Color(0xFF00363A);
  static const Color primaryLight = Color(0xFF4DD0E1); // Cyan 300

  // Secondary colors (Reef - Vibrant Turquoise)
  static const Color secondary = Color(0xFF00ACC1); // Cyan 600
  static const Color secondaryDark = Color(0xFF00838F); // Cyan 800
  static const Color secondaryLight = Color(0xFF80DEEA); // Cyan 200

  // Accent colors
  static const Color accent = Color(0xFFFF7043); // Coral Orange (Unchanged)

  // Semantic colors
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // Node type colors
  static const Color organizationColor = Color(0xFF7E57C2); // Deep Purple
  static const Color siteColor = primary;
  static const Color groupColor = success;
  static const Color coralColor = accent;
  static const Color genetColor = Color(0xFF8D6E63); // Earthy Brown

  // Event type colors
  static const Color createEventColor = success;
  static const Color mortalityEventColor = error;
  static const Color observationEventColor = warning;
  static const Color measurementEventColor = info;
  static const Color maintenanceEventColor = Color(0xFFBDBDBD);
  static const Color moveEventColor = secondary;
  static const Color inventoryEventColor = Color(0xFF78909C);

  // Neutral colors
  static const Color textPrimary = Color(0xFF263238); // Blue Grey 900
  static const Color textSecondary = Color(0xFF546E7A); // Blue Grey 600
  static const Color textHint = Color(0xFF90A4AE); // Blue Grey 300
  static const Color divider = Color(0xFFCFD8DC); // Blue Grey 100
  static const Color background = Color(0xFFF5F7FA); // Very light blue-grey
  static const Color surface = Colors.white;
  static const Color disabled = Color(0xFFECEFF1);
  static const Color shadow = Color(0xFF000000);

  // Status colors
  static const Color healthy = success;
  static const Color stressed = warning;
  static const Color critical = error;
  static const Color unknown = Color(0xFFB0BEC5);

  /// Returns [color] with the provided [opacity] applied using the modern
  /// `withValues` API, maintaining channel precision.
  static Color withOpacity(Color color, double opacity) {
    final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    return color.withValues(alpha: alpha / 255);
  }
}
