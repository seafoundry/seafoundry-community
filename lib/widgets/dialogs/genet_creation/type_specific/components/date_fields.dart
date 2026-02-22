// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_creation/genet_creation_utils.dart';
import 'package:seafoundry_app/widgets/info_tooltip_icon.dart';
import 'package:seafoundry_app/widgets/ui.dart';

class GenetDatePickerField extends StatelessWidget {
  const GenetDatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.placeholder,
    this.errorText,
    this.firstDate,
    this.lastDate,
    this.tooltip,
  });

  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;
  final String? placeholder;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final displayText = selectedDate == null
        ? (placeholder ?? 'Select $label')
        : formatGenetDate(selectedDate!);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: errorText,
        suffixIcon: tooltip != null ? InfoTooltipIcon(message: tooltip!) : null,
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? now,
            firstDate: firstDate ?? DateTime(now.year - 10),
            lastDate: lastDate ?? DateTime(now.year + 10),
          );
          onDateSelected(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.event),
              UI.spacingHorizontalSm,
              Expanded(child: Text(displayText)),
            ],
          ),
        ),
      ),
    );
  }
}
