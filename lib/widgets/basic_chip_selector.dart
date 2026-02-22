// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/model_interfaces.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class BasicChipSelector<T extends Named> extends StatelessWidget {
  final String label;
  final List<T> options;
  final T? selectedValue;
  final void Function(T?)? onChanged;
  final String? Function(List<T?>)? validator;
  final bool allowMultiple;
  final List<T>? selectedValues;
  final void Function(List<T>)? onMultipleChanged;

  const BasicChipSelector({
    super.key,
    required this.label,
    required this.options,
    this.selectedValue,
    this.onChanged,
    this.validator,
    this.allowMultiple = false,
    this.selectedValues,
    this.onMultipleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Label - centered
        Center(child: UIText.bodyMedium(label, color: UI.textPrimaryColor)),
        UI.dividerSm,
        // Chips - centered
        Center(
          child: Wrap(
            spacing: UI.spacingSm,
            runSpacing: UI.spacingSm,
            alignment: WrapAlignment.center,
            children: options.map((option) {
              final isSelected = allowMultiple ? selectedValues?.contains(option) ?? false : selectedValue == option;

              return FilterChip(
                label: UIText.bodyMedium(option.name),
                selected: isSelected,
                onSelected: (selected) {
                  if (allowMultiple && onMultipleChanged != null) {
                    // Handle multiple selection
                    final currentValues = List<T>.from(selectedValues ?? []);
                    if (selected) {
                      currentValues.add(option);
                    } else {
                      currentValues.remove(option);
                    }
                    onMultipleChanged!(currentValues);
                  } else if (onChanged != null) {
                    // Handle single selection
                    onChanged!(selected ? option : null);
                  }
                },
                selectedColor: UI.primaryColor.withValues(alpha: 0.2),
                checkmarkColor: UI.primaryColor,
                backgroundColor: UI.backgroundColor,
                side: BorderSide(color: isSelected ? UI.primaryColor : UI.dividerColor, width: 1.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.borderRadiusLg)),
              );
            }).toList(),
          ),
        ),
        // Error message if validator fails - centered
        if (validator != null) ...[
          UI.dividerSm,
          Center(
            child: Builder(
              builder: (context) {
                final error = validator!(selectedValues ?? [selectedValue]);
                if (error != null) {
                  return UIText.bodySmall(error, color: UI.errorColor);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ],
    );
  }
}
