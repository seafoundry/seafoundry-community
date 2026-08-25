import 'package:flutter/material.dart';
import 'package:seafoundry_community/widgets/ui.dart';

/// A dense, flat dropdown widget for spreadsheet filter toolbars.
///
/// Provides a consistent "Data Center" aesthetic across all filter bars
/// with minimal visual noise - no shadows, subtle background, and dense layout.
///
/// Used by: GeneticsFilterBar, InventoryFilterBar, HoldingsFilterBar
class ToolbarDropdown extends StatelessWidget {
  const ToolbarDropdown({
    super.key,
    required this.width,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final String label;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (onChanged == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(UI.borderRadiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            isDense: true,
            isExpanded: true,
            hint: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                fontSize: 13,
              ),
            ),
            icon: Icon(
              Icons.arrow_drop_down,
              color: theme.iconTheme.color?.withValues(alpha: 0.5),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            items: items,
            onChanged: onChanged,
            borderRadius: BorderRadius.circular(UI.borderRadiusMd),
            dropdownColor: theme.colorScheme.surfaceContainer,
          ),
        ),
      ),
    );
  }
}
