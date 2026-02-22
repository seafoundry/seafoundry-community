// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/breakpoints.dart';

/// A responsive grid layout widget for displaying insight cards in analytics views.
///
/// Automatically adjusts the number of columns based on available width using
/// centralized [Breakpoints] constants:
/// - 1 column when width <= [Breakpoints.mobile]
/// - 2 columns when width > [Breakpoints.mobile] and <= [Breakpoints.desktop]
/// - [maxColumns] columns when width > [Breakpoints.desktop]
///
/// Each child widget is wrapped in a SizedBox with equal width, accounting for
/// spacing between columns. This ensures a clean, aligned grid layout regardless
/// of screen size.
///
/// Example usage:
/// ```dart
/// ResponsiveInsightGrid(
///   children: [
///     InsightCard(title: 'Total', value: '100'),
///     InsightCard(title: 'Active', value: '75'),
///     InsightCard(title: 'Pending', value: '25'),
///   ],
/// )
/// ```
class ResponsiveInsightGrid extends StatelessWidget {
  /// Creates a responsive grid layout for insight cards.
  ///
  /// The [children] parameter is required and contains the widgets to display
  /// in the grid. Each child will be sized equally based on the available width
  /// and number of columns.
  const ResponsiveInsightGrid({
    required this.children,
    this.spacing = 16.0,
    this.maxColumns = 4,
    super.key,
  });

  /// The list of widgets to display in the grid.
  final List<Widget> children;

  /// The spacing between grid items (horizontal and vertical).
  ///
  /// Defaults to 16.0 pixels.
  final double spacing;

  /// The maximum number of columns to display on wide screens.
  ///
  /// Defaults to 4 columns. The actual number of columns displayed may be
  /// less depending on the available width.
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Use centralized breakpoints for column calculation
        final columns = Breakpoints.columnsFor(width, maxColumns: maxColumns);

        // Calculate card width accounting for spacing between columns
        final totalSpacing = spacing * (columns - 1);
        final cardWidth = (width - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: cardWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
