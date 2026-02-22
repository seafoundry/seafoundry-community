// @tier: community
/// Centralized responsive breakpoint constants for adaptive layouts.
///
/// These breakpoints define width thresholds for different device classes
/// and layout decisions across the app, ensuring consistent responsive behavior.
class Breakpoints {
  Breakpoints._(); // Private constructor to prevent instantiation

  /// Mobile to tablet breakpoint (600px)
  ///
  /// Screens narrower than this are considered mobile devices.
  /// Used for switching between single-column and multi-column layouts.
  static const double mobile = 600.0;

  /// Tablet to desktop breakpoint (1100px)
  ///
  /// Screens wider than this are considered desktop displays.
  /// Used for enabling maximum column counts and expanded layouts.
  static const double desktop = 1100.0;

  /// Chart layout switch breakpoint (800px)
  ///
  /// Controls when charts switch from stacked (vertical) to side-by-side (horizontal) layouts.
  /// Used in analytics views to optimize chart visibility and comparison.
  static const double chartSwitch = 800.0;

  /// Determines the optimal number of columns for a grid layout based on available width.
  ///
  /// Returns:
  /// - 1 column for width <= [mobile] (600px)
  /// - 2 columns for width > [mobile] and <= [desktop] (600-1100px)
  /// - [maxColumns] for width > [desktop] (>1100px)
  ///
  /// Example:
  /// ```dart
  /// final columns = Breakpoints.columnsFor(
  ///   constraints.maxWidth,
  ///   maxColumns: 4,
  /// );
  /// ```
  static int columnsFor(double width, {int maxColumns = 4}) {
    if (width > desktop) {
      return maxColumns;
    } else if (width > mobile) {
      return 2;
    } else {
      return 1;
    }
  }

  /// Returns true if the given width represents a mobile device.
  static bool isMobile(double width) => width <= mobile;

  /// Returns true if the given width represents a tablet device.
  static bool isTablet(double width) => width > mobile && width <= desktop;

  /// Returns true if the given width represents a desktop display.
  static bool isDesktop(double width) => width > desktop;
}

/// Grid layout spacing constants.
///
/// Provides standardized spacing values for grid-based layouts,
/// complementing the existing [Spacing] class with grid-specific values.
class GridSpacing {
  GridSpacing._(); // Private constructor to prevent instantiation

  /// Standard grid spacing (16px)
  ///
  /// Used for spacing between grid items in analytics views and card grids.
  /// Matches [Spacing.md] for consistency.
  static const double standard = 16.0;

  /// Compact grid spacing (12px)
  ///
  /// Used for denser grid layouts where more items need to fit.
  static const double compact = 12.0;

  /// Relaxed grid spacing (24px)
  ///
  /// Used for more spacious grid layouts with larger cards.
  /// Matches [Spacing.lg] for consistency.
  static const double relaxed = 24.0;
}
