// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/theme/theme.dart';

class OceanicTextFormField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffix;
  final String? suffixText;
  final bool obscureText;
  final String? initialValue;
  final bool enabled;

  const OceanicTextFormField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffix,
    this.suffixText,
    this.obscureText = false,
    this.initialValue,
    this.enabled = true,
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
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: minLines,
          obscureText: obscureText,
          enabled: enabled,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffix,
            suffixText: suffixText,
            filled: true,
            fillColor: enabled 
                ? AppColors.background 
                : AppColors.disabled.withValues(alpha: 0.1),
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
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.error,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
