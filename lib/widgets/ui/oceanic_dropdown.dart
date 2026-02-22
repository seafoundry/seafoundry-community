// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';

class OceanicDropdown<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? errorText;
  final Key? fieldKey;

  const OceanicDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.hint,
    this.errorText,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<T>(
          key: fieldKey,
          // Using value for consistency with Flutter's stable API
          // initialValue is for forms with FormField, this uses direct value binding
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontFamily: 'Outfit',
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            errorText: errorText,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
