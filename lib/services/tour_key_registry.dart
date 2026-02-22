// @tier: community
import 'package:flutter/material.dart';

/// Centralized registry of GlobalKeys for tour targeting
///
/// This registry provides static GlobalKeys that are attached to critical UI elements
/// in the application. These keys allow the tour system to identify and spotlight
/// specific widgets during the first-time login tour.
///
/// Usage:
/// 1. Attach keys to widgets in their build methods:
///    ```dart
///    IconButton(key: TourKeyRegistry.drawerButton, ...)
///    ```
///
/// 2. Reference keys in tour steps:
///    ```dart
///    TourStep(
///      id: 'drawer',
///      targetKey: TourKeyRegistry.drawerButton,
///      ...
///    )
///    ```
///
/// Note: Keys must be attached before the tour runs, or the spotlight will fail
/// to find the target element.
class TourKeyRegistry {
  // Prevent instantiation
  TourKeyRegistry._();

  /// Key for the navigation breadcrumbs widget
  ///
  /// Location: GraphScaffold app bar
  /// Tour Step: "Where You Are" - Shows user how to navigate using breadcrumbs
  static final GlobalKey navigationBreadcrumbs = GlobalKey(debugLabel: 'tour_navigation_breadcrumbs');

  /// Key for the drawer menu button
  ///
  /// Location: GraphScaffold app bar leading widget
  /// Tour Step: "Main Menu" - Shows user how to access main navigation
  static final GlobalKey drawerButton = GlobalKey(debugLabel: 'tour_drawer_button');

  /// Key for the active graph node info card (tank, group, or organism)
  ///
  /// Location: Node screen info card
  /// Tour Step: Highlights current context before showing actions
  static final GlobalKey graphNodeInfoCard = GlobalKey(debugLabel: 'tour_graph_node_info_card');

  /// Key for the floating action button (FAB)
  ///
  /// Location: GraphScaffold FAB
  /// Tour Step: Context-specific actions demonstration
  static final GlobalKey floatingActionButton = GlobalKey(debugLabel: 'tour_fab');

  /// Key for the bottom action bar
  ///
  /// Location: GraphScaffold bottom navigation
  /// Tour Step: "Quick Actions" - Shows user common tasks and action buttons
  static final GlobalKey bottomActionBar = GlobalKey(debugLabel: 'tour_bottom_action_bar');
}
