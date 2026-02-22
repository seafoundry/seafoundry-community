// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Tooltip widget for five-axis data fields and other contextual help
///
/// Provides accessible information tooltips optimized for mobile with:
/// - Large touch targets for info icon
/// - Clear visual hierarchy
/// - Support for title, description, and current value display
///
/// Usage:
/// ```dart
/// FieldTooltip(
///   message: 'Taxonomy classifies organisms by species and characteristics',
///   title: 'Taxonomy Axis',
///   child: Text('Species'),
/// )
/// ```
class FieldTooltip extends StatelessWidget {
  /// The widget that triggers the tooltip (typically a label or input field)
  final Widget child;

  /// The tooltip message to display
  final String message;

  /// Optional title for the tooltip (e.g., "Taxonomy Axis")
  final String? title;

  /// Optional current value to display (e.g., "Coral - Acropora cervicornis")
  final String? currentValue;

  /// Icon to show for the info trigger
  final IconData icon;

  /// Whether to show the info icon next to the child
  final bool showIcon;

  /// Icon color
  final Color? iconColor;

  const FieldTooltip({
    super.key,
    required this.child,
    required this.message,
    this.title,
    this.currentValue,
    this.icon = Icons.info_outline,
    this.showIcon = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!showIcon) {
      // Simple tooltip on the child itself
      return Tooltip(
        message: message,
        preferBelow: false,
        textStyle: const TextStyle(
          fontSize: 14.0,
          color: Colors.white,
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.all(12.0),
        child: child,
      );
    }

    // Tooltip with separate info icon
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: child),
        UI.spacingHorizontalSm,
        GestureDetector(
          onTap: () => _showTooltipDialog(context),
          child: SizedBox(
            width: 32.0, // Adequate touch target
            height: 32.0,
            child: Icon(
              icon,
              size: 20.0,
              color: iconColor ?? UI.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Show tooltip in a dialog for better mobile experience
  void _showTooltipDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: title != null ? Text(title!) : null,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16.0),
            ),
            if (currentValue != null) ...[
              UI.dividerMd,
              const Text(
                'Current Value:',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              UI.dividerSm,
              Text(
                currentValue!,
                style: TextStyle(
                  fontSize: 14.0,
                  color: UI.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(88, 48), // Adequate touch target
            ),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}

/// Five-axis specific tooltip that shows which axis is being referenced
///
/// Color-coded by axis type for quick visual recognition
class FiveAxisTooltip extends StatelessWidget {
  /// The axis type
  final FiveAxisType axisType;

  /// The tooltip message
  final String message;

  /// The child widget
  final Widget child;

  /// Optional current value
  final String? currentValue;

  const FiveAxisTooltip({
    super.key,
    required this.axisType,
    required this.message,
    required this.child,
    this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    return FieldTooltip(
      title: '${axisType.displayName} Axis',
      message: message,
      currentValue: currentValue,
      iconColor: axisType.color,
      child: child,
    );
  }
}

/// Represents the five data axes in SeaFoundry
enum FiveAxisType {
  taxonomy,
  provenance,
  location,
  lifeStage,
  physical,
}

extension FiveAxisTypeExtension on FiveAxisType {
  String get displayName {
    switch (this) {
      case FiveAxisType.taxonomy:
        return 'Taxonomy';
      case FiveAxisType.provenance:
        return 'Provenance';
      case FiveAxisType.location:
        return 'Location';
      case FiveAxisType.lifeStage:
        return 'Life Stage';
      case FiveAxisType.physical:
        return 'Physical Form';
    }
  }

  Color get color {
    switch (this) {
      case FiveAxisType.taxonomy:
        return const Color(0xFF4CAF50); // Green
      case FiveAxisType.provenance:
        return const Color(0xFF2196F3); // Blue
      case FiveAxisType.location:
        return const Color(0xFFFF9800); // Orange
      case FiveAxisType.lifeStage:
        return const Color(0xFF9C27B0); // Purple
      case FiveAxisType.physical:
        return const Color(0xFFF44336); // Red
    }
  }

  String get description {
    switch (this) {
      case FiveAxisType.taxonomy:
        return 'What organism type - species, genus, and characteristics';
      case FiveAxisType.provenance:
        return 'Genetic origin - genets, cohorts, and reproductive history';
      case FiveAxisType.location:
        return 'Physical location - site, permit, and compliance metadata';
      case FiveAxisType.lifeStage:
        return 'Development phase - fragment, colony, spawning, etc.';
      case FiveAxisType.physical:
        return 'Physical attributes - size, measurements, and form';
    }
  }
}
