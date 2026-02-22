// @tier: community
import 'package:flutter/material.dart';

/// Configuration for action category display
class ActionCategoryConfig {
  const ActionCategoryConfig({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static ActionCategoryConfig inventory() {
    return const ActionCategoryConfig(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      color: Colors.blueGrey,
    );
  }

  static ActionCategoryConfig observations() {
    return const ActionCategoryConfig(
      label: 'Observations',
      icon: Icons.visibility_outlined,
      color: Colors.blueAccent,
    );
  }

  static ActionCategoryConfig husbandry() {
    return const ActionCategoryConfig(
      label: 'Husbandry',
      icon: Icons.favorite_border,
      color: Colors.green,
    );
  }

  static ActionCategoryConfig tasks() {
    return const ActionCategoryConfig(
      label: 'Tasks',
      icon: Icons.checklist_outlined,
      color: Colors.deepPurple,
    );
  }
}

/// Widget for displaying action category sheets
class ActionCategorySheet extends StatelessWidget {
  const ActionCategorySheet({
    super.key,
    required this.config,
    required this.tiles,
  });

  final ActionCategoryConfig config;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(config.icon, color: config.color),
                  const SizedBox(width: 8),
                  Text(
                    config.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (tiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No actions available for this record.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              ...tiles,
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  /// Show as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required ActionCategoryConfig config,
    required List<Widget> Function(
      BuildContext sheetContext,
      BuildContext actionContext,
    )
        tileBuilder,
  }) {
    final actionContext = context;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
        minHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (sheetContext) => ActionCategorySheet(
        config: config,
        tiles: tileBuilder(sheetContext, actionContext),
      ),
    );
  }
}
