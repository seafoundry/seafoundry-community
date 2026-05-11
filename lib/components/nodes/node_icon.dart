import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// Standardized icon widget for graph nodes
class NodeIcon extends StatelessWidget {
  final ModelType modelType;
  final double size;
  final Color? color;

  const NodeIcon({super.key, required this.modelType, this.size = 24.0, this.color});

  /// Create a small node icon (16px)
  const NodeIcon.small({super.key, required this.modelType, this.color}) : size = 16.0;

  /// Create a large node icon (32px)
  const NodeIcon.large({super.key, required this.modelType, this.color}) : size = 32.0;

  @override
  Widget build(BuildContext context) {
    final nodeTheme = Theme.of(context).extension<NodeTheme>();
    if (nodeTheme == null) {
      // Fallback when NodeTheme extension is not available
      return Icon(_fallbackIcon(modelType), size: size, color: color ?? Colors.grey);
    }
    NodeThemeData themeData = nodeTheme.forModelType(modelType);

    return Icon(themeData.icon, size: size, color: color ?? themeData.primaryColor);
  }

  IconData _fallbackIcon(ModelType type) {
    switch (type) {
      case ModelType.organization:
        return Icons.business;
      case ModelType.site:
        return Icons.location_on;
      case ModelType.group:
        return Icons.folder;
      case ModelType.organismRecord:
        return Icons.scatter_plot; // Coral-like icon representing polyp structure
      default:
        return Icons.help_outline;
    }
  }
}

/// Widget to display node with its icon and label
class NodeChip extends StatelessWidget {
  final GraphNodeRecord record;
  final String? label;
  final VoidCallback? onTap;
  final bool selected;

  const NodeChip({super.key, required this.record, this.label, this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodeTheme = Theme.of(context).extension<NodeTheme>();

    // Fallback colors when NodeTheme is not available
    final themeData = nodeTheme?.forModelType(record.modelType);
    final primaryColor = themeData?.primaryColor ?? Colors.grey;

    final displayLabel = label ?? record.name;

    return Material(
      color: selected ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
          decoration: BoxDecoration(
            border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NodeIcon.small(modelType: record.modelType),
              SizedBox(width: Spacing.xs),
              Text(
                displayLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: primaryColor,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
