// @tier: community
import 'package:flutter/material.dart';

import '../../models/inventory/physical_form_config.dart';
import '../../models/inventory/size_spec.dart';
import '../../models/types/life_stage.dart';
import '../../models/types/organism_kind.dart';
import '../../services/physical_form_registry.dart';
import '../../services/size_mappings_service.dart';
import '../../services/validation/organism_constraints_service.dart';
import 'size_spec_editor.dart';

/// Visual selector for physical forms using card-style selection
class PhysicalFormSelector extends StatelessWidget {
  const PhysicalFormSelector({
    super.key,
    required this.forms,
    required this.selectedFormId,
    required this.onChanged,
  });

  final List<PhysicalFormConfig> forms;
  final String? selectedFormId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    if (forms.isEmpty) {
      return Text(
        'No physical forms available',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: forms.map((form) {
        final isSelected = selectedFormId == form.id;
        return PhysicalFormCard(
          form: form,
          isSelected: isSelected,
          isEnabled: isEnabled,
          onTap: isEnabled ? () => onChanged!(form.id) : null,
        );
      }).toList(),
    );
  }
}

/// Individual physical form card with visual selection state
class PhysicalFormCard extends StatelessWidget {
  const PhysicalFormCard({
    super.key,
    required this.form,
    required this.isSelected,
    required this.isEnabled,
    this.onTap,
  });

  final PhysicalFormConfig form;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 80, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : theme.colorScheme.outline.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFormIcon(form.id),
                size: 24,
                color: isSelected
                    ? primaryColor
                    : (isEnabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 4),
              Text(
                form.displayName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? primaryColor
                      : (isEnabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            )),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFormIcon(String formId) {
    // Map common form IDs to icons
    final id = formId.toLowerCase();
    if (id.contains('plug') || id.contains('frag')) return Icons.push_pin;
    if (id.contains('colony')) return Icons.blur_circular;
    if (id.contains('nubbin')) return Icons.fiber_manual_record;
    if (id.contains('branch')) return Icons.account_tree;
    if (id.contains('plate')) return Icons.crop_square;
    if (id.contains('encrust')) return Icons.layers;
    if (id.contains('massive')) return Icons.circle;
    if (id.contains('table')) return Icons.table_chart;
    if (id.contains('clump')) return Icons.bubble_chart;
    if (id.contains('blade')) return Icons.grass;
    if (id.contains('shoot')) return Icons.eco;
    if (id.contains('spore')) return Icons.scatter_plot;
    if (id.contains('seed')) return Icons.grain;
    if (id.contains('juvenile')) return Icons.child_care;
    if (id.contains('adult')) return Icons.person;
    return Icons.category; // Default icon
  }
}

/// Bundles a physical form ID with its size specification.
class PhysicalFormSelection {
  const PhysicalFormSelection({
    required this.physicalFormId,
    required this.sizeSpec,
  });

  final String physicalFormId;
  final SizeSpec sizeSpec;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicalFormSelection &&
          runtimeType == other.runtimeType &&
          physicalFormId == other.physicalFormId &&
          sizeSpec == other.sizeSpec;

  @override
  int get hashCode => Object.hash(physicalFormId, sizeSpec);
}

/// Widget for selecting a physical form and its size specification.
class PhysicalFormSelectorWidget extends StatefulWidget {
  const PhysicalFormSelectorWidget({
    super.key,
    required this.organismKind,
    required this.lifeStage,
    required this.onChanged,
    this.initialPhysicalFormId,
    this.initialSizeSpec = const SizeSpec(),
    this.constraintsService = const OrganismConstraintsService(),
    this.sizeMappings,
    this.sizeClassOptions,
  });

  final OrganismKind organismKind;
  final LifeStage lifeStage;
  final String? initialPhysicalFormId;
  final SizeSpec initialSizeSpec;
  final OrganismConstraintsService constraintsService;
  final SizeMappingsService? sizeMappings;
  final List<String>? sizeClassOptions;
  final ValueChanged<PhysicalFormSelection> onChanged;

  @override
  State<PhysicalFormSelectorWidget> createState() =>
      _PhysicalFormSelectorWidgetState();
}

class _PhysicalFormSelectorWidgetState
    extends State<PhysicalFormSelectorWidget> {
  List<PhysicalFormConfig> _forms = [];
  String? _selectedFormId;
  SizeSpec _sizeSpec = const SizeSpec();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedFormId = widget.initialPhysicalFormId;
    _sizeSpec = widget.initialSizeSpec;
    _loadForms();
  }

  @override
  void didUpdateWidget(covariant PhysicalFormSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organismKind != widget.organismKind ||
        oldWidget.lifeStage != widget.lifeStage) {
      _loadForms();
    }
  }

  void _loadForms() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final forms = PhysicalFormRegistry.instance.getAvailableForms(
        widget.organismKind,
        widget.lifeStage,
      );
      setState(() {
        _forms = forms;
        _isLoading = false;
        // If current selection is not in available forms, clear it
        if (_selectedFormId != null &&
            !forms.any((f) => f.id == _selectedFormId)) {
          _selectedFormId = forms.isNotEmpty ? forms.first.id : null;
          _notifyChange();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _notifyChange() {
    if (_selectedFormId == null) return;
    widget.onChanged(PhysicalFormSelection(
      physicalFormId: _selectedFormId!,
      sizeSpec: _sizeSpec,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Text(
        'Failed to load physical forms: $_error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Physical form',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        PhysicalFormSelector(
          forms: _forms,
          selectedFormId: _selectedFormId,
          onChanged: (formId) {
            setState(() => _selectedFormId = formId);
            _notifyChange();
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Size specification',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizeSpecEditor(
          initialValue: _sizeSpec,
          sizeMappings: widget.sizeMappings ?? SizeMappingsService.empty(),
          sizeClassOptions:
              widget.sizeClassOptions ?? const ['XS', 'S', 'M', 'L', 'XL'],
          onChanged: (spec) {
            setState(() => _sizeSpec = spec);
            _notifyChange();
          },
        ),
      ],
    );
  }
}
