// @tier: community
import 'package:flutter/material.dart';

/// Animation duration constants per UI/UX spec
///
/// Standard durations:
/// - Fast: 150ms for micro-interactions
/// - Standard: 250ms for most transitions
/// - Slow: 400ms for major transitions
class AnimationConstants {
  /// Fast animation duration (150ms) - for micro-interactions
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard animation duration (250ms) - for most transitions
  static const Duration standard = Duration(milliseconds: 250);

  /// Slow animation duration (400ms) - for major transitions
  static const Duration slow = Duration(milliseconds: 400);

  /// Very fast animation duration (100ms) - for immediate feedback
  static const Duration veryFast = Duration(milliseconds: 100);

  /// Very slow animation duration (600ms) - for complex transitions
  static const Duration verySlow = Duration(milliseconds: 600);

  /// Standard curve for most animations
  static const Curve standardCurve = Curves.easeInOut;

  /// Fast curve for quick transitions
  static const Curve fastCurve = Curves.easeOut;

  /// Slow curve for smooth transitions
  static const Curve slowCurve = Curves.easeInOutCubic;

  /// Bounce curve for playful animations
  static const Curve bounceCurve = Curves.elasticOut;

  /// Standard animation curve
  static const Cubic standardCubic = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Decelerate curve
  static const Cubic decelerateCubic = Cubic(0.0, 0.0, 0.2, 1.0);

  /// Accelerate curve
  static const Cubic accelerateCubic = Cubic(0.4, 0.0, 1.0, 1.0);
}

/// Touch target size constants per UI/UX spec
class TouchTargetSizes {
  /// Primary action touch target (64dp minimum)
  static const double primary = 64.0;

  /// Secondary action touch target (56dp)
  static const double secondary = 56.0;

  /// Tertiary action touch target (48dp)
  static const double tertiary = 48.0;

  /// Form input touch target (48dp minimum)
  static const double formInput = 48.0;
}

/// Color coding constants for five-axis indicators
class FiveAxisColors {
  /// Taxonomy axis color (Green)
  static const Color taxonomy = Color(0xFF4CAF50);

  /// Provenance axis color (Blue)
  static const Color provenance = Color(0xFF2196F3);

  /// Location axis color (Orange)
  static const Color location = Color(0xFFFF9800);

  /// Life Stage axis color (Purple)
  static const Color lifeStage = Color(0xFF9C27B0);

  /// Physical Form axis color (Red)
  static const Color physical = Color(0xFFF44336);
}

