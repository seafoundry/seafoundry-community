// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/spreadsheet_column_preferences/spreadsheet_column_preferences_cubit.dart';
import 'package:seafoundry_app/widgets/spreadsheet/column_preferences/spreadsheet_id.dart';

/// Describes a column available for configuration.
class ColumnConfigItem {
  const ColumnConfigItem({required this.key, required this.title});

  /// Unique column key matching the spreadsheet's column identifier.
  final String key;

  /// Human-readable column title.
  final String title;
}

/// Dialog allowing users to reorder and toggle visibility of spreadsheet columns.
///
/// Reads current preferences from [SpreadsheetColumnPreferencesCubit] on init
/// and writes them back atomically via [setPreferences] on Apply.
class ColumnConfigDialog extends StatefulWidget {
  const ColumnConfigDialog({
    super.key,
    required this.spreadsheetId,
    required this.allColumns,
  });

  final SpreadsheetId spreadsheetId;
  final List<ColumnConfigItem> allColumns;

  @override
  State<ColumnConfigDialog> createState() => _ColumnConfigDialogState();
}

class _ColumnConfigDialogState extends State<ColumnConfigDialog> {
  late List<String> _orderedKeys;
  late Set<String> _hiddenKeys;
  late final Map<String, String> _titleMap;

  List<String> get _factoryOrder =>
      widget.allColumns.map((c) => c.key).toList();

  @override
  void initState() {
    super.initState();
    _titleMap = {
      for (final c in widget.allColumns) c.key: c.title,
    };

    final cubit = context.read<SpreadsheetColumnPreferencesCubit>();
    final prefs = cubit.state.forSpreadsheet(widget.spreadsheetId);

    _orderedKeys = prefs.hasCustomOrder
        ? _reconcileOrder(prefs.columnOrder)
        : List.of(_factoryOrder);
    _hiddenKeys = Set.of(prefs.hiddenColumns);
  }

  /// Reconcile stored order with current factory columns.
  ///
  /// Drops stale keys and appends new columns not in the stored order.
  List<String> _reconcileOrder(List<String> storedOrder) {
    final factorySet = _factoryOrder.toSet();
    final reconciled = <String>[
      for (final key in storedOrder)
        if (factorySet.contains(key)) key,
    ];
    final reconciledSet = reconciled.toSet();
    for (final key in _factoryOrder) {
      if (!reconciledSet.contains(key)) reconciled.add(key);
    }
    return reconciled;
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final key = _orderedKeys.removeAt(oldIndex);
      _orderedKeys.insert(newIndex, key);
    });
  }

  void _resetToDefaults() {
    setState(() {
      _orderedKeys = List.of(_factoryOrder);
      _hiddenKeys = {};
    });
  }

  void _apply() {
    context.read<SpreadsheetColumnPreferencesCubit>().setPreferences(
          widget.spreadsheetId,
          _orderedKeys,
          _hiddenKeys,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.view_column_outlined),
          SizedBox(width: 8),
          Text('Configure Columns'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          itemCount: _orderedKeys.length,
          onReorder: _onReorder,
          itemBuilder: (context, index) {
            final key = _orderedKeys[index];
            final title = _titleMap[key] ?? key;
            final isHidden = _hiddenKeys.contains(key);
            final visibleCount =
                _orderedKeys.length - _hiddenKeys.length;
            final isLastVisible = !isHidden && visibleCount <= 1;
            return _ColumnTile(
              key: ValueKey(key),
              title: title,
              index: index,
              isVisible: !isHidden,
              canToggle: !isLastVisible,
              onToggleVisibility: () {
                setState(() {
                  if (isHidden) {
                    _hiddenKeys.remove(key);
                  } else {
                    _hiddenKeys.add(key);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetToDefaults,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ColumnTile extends StatelessWidget {
  const _ColumnTile({
    super.key,
    required this.title,
    required this.index,
    required this.isVisible,
    this.canToggle = true,
    required this.onToggleVisibility,
  });

  final String title;
  final int index;
  final bool isVisible;
  final bool canToggle;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(Icons.drag_handle, color: theme.colorScheme.outline),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isVisible ? null : theme.colorScheme.outline,
            decoration: isVisible ? null : TextDecoration.lineThrough,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: isVisible
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          onPressed: canToggle ? onToggleVisibility : null,
        ),
      ),
    );
  }
}
