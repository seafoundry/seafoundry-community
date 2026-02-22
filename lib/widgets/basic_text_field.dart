// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/widgets/ui.dart';

class BasicTextField extends StatelessWidget {
  const BasicTextField({
    super.key,
    this.label,
    this.hint,
    this.value,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.textCapitalization,
    this.controller,
    this.autovalidateMode = AutovalidateMode.onUnfocus,
    this.inputFormatter,
    this.maxLines,
  });

  final String? label;
  final String? hint;
  final String? value;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Widget? suffixIcon;
  final TextCapitalization? textCapitalization;
  final TextEditingController? controller;
  final AutovalidateMode autovalidateMode;
  final TextInputFormatter? inputFormatter;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      // key: formKey,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: UI.inputFieldBorder(),
        enabledBorder: UI.inputFieldBorder(),
        focusedBorder: UI.inputFieldFocusedBorder(),
        errorBorder: UI.inputFieldErrorBorder(),
        filled: true,
        fillColor: UI.backgroundColor,
        contentPadding: UI.paddingMd,
        suffixIcon: suffixIcon,
      ),
      initialValue: value,
      maxLines: maxLines,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      obscureText: obscureText,
      validator: validator,
      autovalidateMode: autovalidateMode,
      autocorrect: false,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTapOutside: (event) => FocusScope.of(context).unfocus(),
      inputFormatters: [if (inputFormatter != null) inputFormatter!],
    );
  }
}
