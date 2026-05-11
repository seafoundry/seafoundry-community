import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/in_situ/grid_renderer.dart';

enum InSituGridCellMenuAction { depopulate, markMaintenance, repopulate }

typedef InSituGridCellMenuSelected =
    void Function(
      InSituGridCellMenuAction action,
      InSituGridCellSummary summary,
    );

class InSituGridCellMenu extends StatelessWidget {
  const InSituGridCellMenu({
    super.key,
    required this.summary,
    required this.child,
    this.onSelected,
    this.enabledActions = InSituGridCellMenuAction.values,
  });

  final InSituGridCellSummary summary;
  final Widget child;
  final InSituGridCellMenuSelected? onSelected;
  final List<InSituGridCellMenuAction> enabledActions;

  @override
  Widget build(BuildContext context) {
    if (enabledActions.isEmpty) {
      return child;
    }
    return PopupMenuButton<InSituGridCellMenuAction>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      tooltip: 'Open tree actions',
      onSelected: (action) => onSelected?.call(action, summary),
      itemBuilder: (context) => enabledActions
          .map(
            (action) => PopupMenuItem<InSituGridCellMenuAction>(
              value: action,
              child: _MenuLabel(action: action),
            ),
          )
          .toList(),
      child: child,
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.action});

  final InSituGridCellMenuAction action;

  @override
  Widget build(BuildContext context) {
    final icon = switch (action) {
      InSituGridCellMenuAction.depopulate => Icons.local_florist_outlined,
      InSituGridCellMenuAction.markMaintenance => Icons.build_circle_outlined,
      InSituGridCellMenuAction.repopulate => Icons.replay,
    };
    final label = switch (action) {
      InSituGridCellMenuAction.depopulate => 'Depopulate',
      InSituGridCellMenuAction.markMaintenance => 'Mark Maintenance',
      InSituGridCellMenuAction.repopulate => 'Repopulate',
    };
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
  }
}
