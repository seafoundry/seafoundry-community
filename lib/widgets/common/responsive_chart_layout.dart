// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/breakpoints.dart';

/// A responsive layout widget that automatically switches between row and column
/// layouts based on available width.
///
/// This widget is commonly used for analytics chart layouts where charts should
/// be displayed side-by-side on wide screens and stacked vertically on narrow
/// screens.
///
/// Example usage:
/// ```dart
/// ResponsiveChartLayout(
///   breakpoint: Breakpoints.chartSwitch,
///   children: [
///     CategoryBarChart(...),
///     DistributionPieChart(...),
///   ],
/// )
/// ```
///
/// On wide screens (> [Breakpoints.chartSwitch] by default), children are
/// displayed in a [Row] with each child wrapped in [Expanded]. On narrow
/// screens, children are displayed in a [Column] without expansion.
class ResponsiveChartLayout extends StatelessWidget {
  /// Creates a responsive chart layout.
  ///
  /// The [children] parameter must not be null and typically contains 2 chart
  /// widgets, though any number of widgets is supported.
  ///
  /// The [breakpoint] determines the width threshold for switching between row
  /// and column layouts. Defaults to [Breakpoints.chartSwitch] (800px).
  ///
  /// The [spacing] determines the gap between children, applied as horizontal
  /// spacing in row layout and vertical spacing in column layout. Defaults to
  /// [GridSpacing.relaxed] (24px).
  const ResponsiveChartLayout({
    super.key,
    required this.children,
    this.breakpoint = Breakpoints.chartSwitch,
    this.spacing = GridSpacing.relaxed,
  });

  /// The chart widgets to display.
  final List<Widget> children;

  /// The width threshold for switching between row and column layouts.
  ///
  /// When the available width is greater than this value, a [Row] layout is
  /// used. Otherwise, a [Column] layout is used.
  final double breakpoint;

  /// The spacing between children in pixels.
  ///
  /// Applied as horizontal spacing in row layout (via [SizedBox.width]) and
  /// vertical spacing in column layout (via [SizedBox.height]).
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > breakpoint;

        if (isWide) {
          // Wide layout: Row with Expanded children
          final rowChildren = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            if (i > 0) {
              rowChildren.add(SizedBox(width: spacing));
            }
            rowChildren.add(Expanded(child: children[i]));
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren,
          );
        } else {
          // Narrow layout: Column without expansion
          final columnChildren = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            if (i > 0) {
              columnChildren.add(SizedBox(height: spacing));
            }
            columnChildren.add(children[i]);
          }

          return Column(children: columnChildren);
        }
      },
    );
  }
}
