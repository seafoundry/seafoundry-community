import 'package:flutter/material.dart';

import '../../models/inventory/size_spec.dart';
import '../../services/size_mappings_service.dart';
import 'visual_selector.dart';

/// Simple editor for SizeSpec (size class only).
class SizeSpecEditor extends StatefulWidget {
  const SizeSpecEditor({
    super.key,
    required this.onChanged,
    this.initialValue = const SizeSpec(),
    this.sizeMappings,
    this.sizeClassOptions = const ['XS', 'S', 'M', 'L', 'XL'],
  });

  final SizeSpec initialValue;
  final SizeMappingsService? sizeMappings;
  final ValueChanged<SizeSpec> onChanged;
  final List<String> sizeClassOptions;

  @override
  State<SizeSpecEditor> createState() => _SizeSpecEditorState();
}

class _SizeSpecEditorState extends State<SizeSpecEditor> {
  late String? _sizeClass;

  @override
  void initState() {
    super.initState();
    _sizeClass = widget.initialValue.sizeClass;
  }

  void _notifyChange() {
    widget.onChanged(SizeSpec(
      sizeClass: _sizeClass,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Size Class', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SizeClassVisualSelector(
          options: widget.sizeClassOptions,
          selectedClass: _sizeClass,
          onChanged: (value) {
            setState(() => _sizeClass = value);
            _notifyChange();
          },
        ),
      ],
    );
  }
}
