// @tier: community
import 'package:flutter/material.dart';

/// Centralized color palette for chart visualizations.
///
/// Keeps hardcoded Material colors out of service-layer code.
/// Both analytics services and UI widgets should reference this palette
/// instead of inlining color lists.
class ChartColorPalette {
  ChartColorPalette._();

  /// Default categorical colors for species distribution and similar charts.
  static const List<Color> categorical = [
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.deepPurple,
    Colors.cyan,
    Colors.amber,
    Colors.orange,
    Colors.pink,
  ];

  /// Returns a color for the given [index], cycling through the palette.
  static Color atIndex(int index) => categorical[index % categorical.length];
}
