// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/tour_key_registry.dart';

/// Represents a single step in the first-time login tour
class TourStep {
  const TourStep({
    required this.id,
    required this.title,
    required this.description,
    required this.targetKey,
    this.position = TourTooltipPosition.below,
    this.interactive = false,
    this.action,
    this.showExample = false,
  });

  /// Unique identifier for this tour step
  final String id;

  /// Title shown in tooltip
  final String title;

  /// Description shown in tooltip
  final String description;

  /// GlobalKey of the widget to highlight
  final GlobalKey? targetKey;

  /// Position of tooltip relative to target
  final TourTooltipPosition position;

  /// Whether user can interact with the target during this step
  final bool interactive;

  /// Optional action to perform when step is shown
  final VoidCallback? action;

  /// Whether to show an example or demo
  final bool showExample;
}

/// Position of tooltip relative to target element
enum TourTooltipPosition {
  above,
  below,
  left,
  right,
  center,
}

/// Critical infrastructure tour steps that all users must see
class CriticalInfrastructureTour {
  static List<TourStep> getStandardSteps() => [
    // Step 1: Welcome & Current Location
    TourStep(
      id: 'welcome_coral',
      title: 'Welcome to SeaFoundry! 🪸',
      description: 'This screen shows your organism\'s current location and status. '
          'Let\'s take a quick tour of the key features.',
      targetKey: null,
      position: TourTooltipPosition.center,
    ),

    // Step 2: Navigation Breadcrumbs
    TourStep(
      id: 'navigation_breadcrumbs',
      title: 'Navigation Breadcrumbs',
      description: 'The breadcrumbs show exactly where you are:\n\n'
          'Organization → Site → Tank → Coral\n\n'
          'Tap any level to navigate up the hierarchy.',
      targetKey: TourKeyRegistry.navigationBreadcrumbs,
      position: TourTooltipPosition.below,
    ),

    // Step 3: Current Graph Node
    TourStep(
      id: 'current_node',
      title: 'Current View',
      description: 'This card shows the item you\'re viewing and its status.\n\n'
          'All actions and information on this screen are scoped to this specific record.',
      targetKey: TourKeyRegistry.graphNodeInfoCard,
      position: TourTooltipPosition.above,
    ),

    // Step 4: Action Buttons
    TourStep(
      id: 'action_buttons',
      title: 'Quick Actions',
      description: 'The bottom action bar provides context-aware actions:\n\n'
          '• Add more organisms\n'
          '• Record health observations\n'
          '• Fragment or transfer corals\n'
          '• Log treatments and tasks\n\n'
          'Actions change based on what you\'re viewing.',
      targetKey: TourKeyRegistry.bottomActionBar,
      position: TourTooltipPosition.above,
    ),

    // Step 5: Drawer Menu
    TourStep(
      id: 'drawer_menu',
      title: 'Main Menu',
      description: 'Tap the menu icon to access:\n\n'
          '• Inventory holdings\n'
          '• Genetic library\n'
          '• Event feeds\n'
          '• Outplanting map\n'
          '• Analytics & reporting\n'
          '• Settings',
      targetKey: TourKeyRegistry.drawerButton,
      position: TourTooltipPosition.right,
    ),

    // Step 6: Getting Started
    TourStep(
      id: 'getting_started',
      title: 'You\'re Ready!',
      description: 'Start by exploring your organization structure or adding more corals.\n\n'
          'Tips:\n'
          '• Use the search bar to find records quickly\n'
          '• Tap the info icon (ℹ️) on any field for help\n'
          '• The tour can be restarted from Settings\n\n'
          'Happy tracking! 🐠',
      targetKey: null,
      position: TourTooltipPosition.center,
    ),
  ];
}
