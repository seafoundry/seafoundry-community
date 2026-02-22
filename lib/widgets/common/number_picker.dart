// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Visual number picker optimized for wet-finger operation
///
/// Provides a grid of preset values plus custom input option
/// Large touch targets (80x80dp minimum) suitable for field use
///
/// Usage:
/// ```dart
/// NumberPicker(
///   label: 'Fragment Count',
///   helperText: 'Number of fragments to create',
///   selected: 5,
///   onChanged: (value) => print('Selected: $value'),
///   presets: [1, 5, 10, 25, 50, 100],
/// )
/// ```
class NumberPicker extends StatefulWidget {
  /// Label for the number picker
  final String label;

  /// Helper text displayed below the picker
  final String? helperText;

  /// Currently selected value
  final int? selected;

  /// Callback when value changes
  final ValueChanged<int>? onChanged;

  /// Preset values to display in grid
  final List<int> presets;

  /// Minimum allowed value
  final int? minValue;

  /// Maximum allowed value
  final int? maxValue;

  /// Number of columns for preset grid
  final int columns;

  /// Whether to show the custom input option
  final bool showCustom;

  const NumberPicker({
    super.key,
    required this.label,
    this.helperText,
    this.selected,
    this.onChanged,
    this.presets = const [1, 5, 10, 25, 50, 100],
    this.minValue,
    this.maxValue,
    this.columns = 3,
    this.showCustom = true,
  });

  @override
  State<NumberPicker> createState() => _NumberPickerState();
}

class _NumberPickerState extends State<NumberPicker> {
  late int? _selectedValue;
  bool _showCustomInput = false;
  late final TextEditingController _customController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selected;
    _customController = TextEditingController(
      text: _isCustomValue(_selectedValue) ? _selectedValue.toString() : '',
    );
    // If selected value is not in presets, show custom input
    if (_selectedValue != null && _isCustomValue(_selectedValue)) {
      _showCustomInput = true;
    }
  }

  @override
  void didUpdateWidget(NumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != _selectedValue) {
      setState(() {
        _selectedValue = widget.selected;
        if (_selectedValue != null && _isCustomValue(_selectedValue)) {
          _customController.text = _selectedValue.toString();
          _showCustomInput = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool _isCustomValue(int? value) {
    if (value == null) return false;
    return !widget.presets.contains(value);
  }

  void _selectPreset(int value) {
    // Provide haptic feedback for better tactile response
    HapticFeedback.selectionClick();

    setState(() {
      _selectedValue = value;
      _showCustomInput = false;
    });
    widget.onChanged?.call(value);
  }

  void _selectCustom() {
    // Provide haptic feedback for better tactile response
    HapticFeedback.selectionClick();

    setState(() {
      _showCustomInput = true;
    });
  }

  void _handleCustomInput(String text) {
    if (text.isEmpty) {
      setState(() {
        _validationError = null;
        _selectedValue = null;
      });
      return;
    }

    final value = int.tryParse(text);
    if (value == null) {
      setState(() {
        _validationError = 'Please enter a valid number';
      });
      return;
    }

    // Validate against min/max
    if (widget.minValue != null && value < widget.minValue!) {
      setState(() {
        _validationError = 'Value must be at least ${widget.minValue}';
      });
      return;
    }
    if (widget.maxValue != null && value > widget.maxValue!) {
      setState(() {
        _validationError = 'Value must be at most ${widget.maxValue}';
      });
      return;
    }

    setState(() {
      _selectedValue = value;
      _validationError = null;
    });
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4.0),
          Text(
            widget.helperText!,
            style: TextStyle(
              fontSize: 14.0,
              color: UI.textSecondaryColor,
            ),
          ),
        ],
        const SizedBox(height: 12.0),
        // Preset grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.columns,
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
            childAspectRatio: 1.0,
          ),
          itemCount: widget.presets.length + (widget.showCustom ? 1 : 0),
          itemBuilder: (context, index) {
            if (widget.showCustom && index == widget.presets.length) {
              // Custom button
              return _buildCustomButton();
            }
            final value = widget.presets[index];
            final isSelected = _selectedValue == value && !_showCustomInput;
            return _buildPresetButton(value, isSelected);
          },
        ),
        // Custom input field (shown when custom is selected)
        if (_showCustomInput) ...[
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _customController,
            decoration: InputDecoration(
              labelText: 'Custom Value',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              errorText: _validationError,
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showCustomInput = false;
                    _customController.clear();
                    _validationError = null;
                  });
                },
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: _handleCustomInput,
            autofocus: true,
          ),
        ],
      ],
    );
  }

  Widget _buildPresetButton(int value, bool isSelected) {
    return InkWell(
      onTap: () => _selectPreset(value),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80.0, minWidth: 80.0),
        decoration: BoxDecoration(
          color: isSelected
              ? UI.primaryColor.withValues(alpha: 0.1)
              : UI.surfaceColor,
          border: Border.all(
            color: isSelected ? UI.primaryColor : UI.dividerColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? UI.primaryColor : UI.textPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomButton() {
    final isSelected = _showCustomInput;
    return InkWell(
      onTap: _selectCustom,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80.0, minWidth: 80.0),
        decoration: BoxDecoration(
          color: isSelected
              ? UI.primaryColor.withValues(alpha: 0.1)
              : UI.surfaceColor,
          border: Border.all(
            color: isSelected ? UI.primaryColor : UI.dividerColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit,
                size: 28.0,
                color: isSelected ? UI.primaryColor : UI.textSecondaryColor,
              ),
              const SizedBox(height: 4.0),
              Text(
                'Custom',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? UI.primaryColor : UI.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
