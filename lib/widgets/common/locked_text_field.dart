// @tier: community
import 'package:flutter/material.dart';

/// Displays a locked, read-only text field with a lock icon and tooltip.
///
/// Used for inherited or immutable field values in dialogs where the user
/// should see but not edit the value. The field appears enabled (not grayed
/// out) but is not editable.
///
/// Example use cases:
/// - LocalID inherited from parent in spawning events
/// - Species and LocalID in organism split dialogs
/// - Species inherited from source cohort in graduation
class LockedTextField extends StatefulWidget {
  const LockedTextField({
    super.key,
    required this.value,
    required this.labelText,
    required this.tooltipMessage,
    this.prefixIcon,
    this.helperText,
  });

  /// The text value to display. If null or empty, shows a placeholder.
  final String? value;

  /// The label for the text field (e.g., "Local ID", "Species").
  final String labelText;

  /// The tooltip message shown when hovering over the lock icon.
  /// Should explain why the field is locked (e.g., "Inherited from parent").
  final String tooltipMessage;

  /// Optional icon to show before the text.
  final IconData? prefixIcon;

  /// Optional helper text shown below the field.
  final String? helperText;

  @override
  State<LockedTextField> createState() => _LockedTextFieldState();
}

class _LockedTextFieldState extends State<LockedTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final displayValue = widget.value?.trim();
    _controller = TextEditingController(text: displayValue ?? '');
  }

  @override
  void didUpdateWidget(LockedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final displayValue = widget.value?.trim();
      _controller.text = displayValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.value?.trim();
    final hasValue = displayValue != null && displayValue.isNotEmpty;

    return TextField(
      controller: _controller,
      enabled: true,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        border: const OutlineInputBorder(),
        suffixIcon: Tooltip(
          message: widget.tooltipMessage,
          child: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.lock, size: 18),
          ),
        ),
        hintText: hasValue ? null : 'Not set',
      ),
    );
  }
}
