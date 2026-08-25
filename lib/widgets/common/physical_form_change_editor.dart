import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/inventory/physical_form_change_reason.dart';
import 'package:seafoundry_community/models/inventory/physical_form_config.dart';
import 'package:seafoundry_community/models/types/life_stage.dart';
import 'package:seafoundry_community/models/types/organism_kind.dart';
import 'package:seafoundry_community/services/physical_form_registry.dart';

export 'package:seafoundry_community/models/inventory/physical_form_change_reason.dart';

class PhysicalFormChangeEditor extends StatefulWidget {
  const PhysicalFormChangeEditor({
    super.key,
    required this.organismKind,
    required this.lifeStage,
    required this.allowedFormIds,
    required this.onFormIdChanged,
    this.currentFormId,
    this.selectedFormId,
    this.selectedReason,
    this.onReasonChanged,
    this.validationMessage,
    this.densityWarning,
    this.isBusy = false,
  });

  final OrganismKind organismKind;
  final LifeStage lifeStage;
  final String? currentFormId;
  final List<String> allowedFormIds;
  final String? selectedFormId;
  final ValueChanged<String?> onFormIdChanged;
  final PhysicalFormChangeReason? selectedReason;
  final ValueChanged<PhysicalFormChangeReason?>? onReasonChanged;
  final String? validationMessage;
  final String? densityWarning;
  final bool isBusy;

  @override
  State<PhysicalFormChangeEditor> createState() =>
      _PhysicalFormChangeEditorState();
}

class _PhysicalFormChangeEditorState extends State<PhysicalFormChangeEditor> {
  List<PhysicalFormConfig> _availableForms = [];
  String? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhysicalForms();
  }

  @override
  void didUpdateWidget(covariant PhysicalFormChangeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organismKind != widget.organismKind ||
        oldWidget.lifeStage != widget.lifeStage) {
      _loadPhysicalForms();
    }
  }

  void _loadPhysicalForms() {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final forms = PhysicalFormRegistry.instance.getAvailableForms(
        widget.organismKind,
        widget.lifeStage,
      );
      setState(() {
        _availableForms = forms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  String _getDisplayName(String formId) {
    final config = _availableForms.cast<PhysicalFormConfig?>().firstWhere(
      (form) => form?.id == formId,
      orElse: () => null,
    );
    return config?.displayName ?? formId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _AlertBanner(
        icon: Icons.error,
        color: theme.colorScheme.error,
        message: 'Failed to load physical forms: $_loadError',
      );
    }

    final allowedFormConfigs = _availableForms
        .where((form) => widget.allowedFormIds.contains(form.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Physical form', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _CurrentPhysicalFormTile(
          currentFormId: widget.currentFormId,
          displayName: widget.currentFormId != null
              ? _getDisplayName(widget.currentFormId!)
              : null,
        ),
        const SizedBox(height: 12),
        Text('New physical form', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        _PhysicalFormVisualSelector(
          forms: allowedFormConfigs,
          selectedFormId: widget.selectedFormId,
          onChanged: widget.isBusy ? null : widget.onFormIdChanged,
        ),
        const SizedBox(height: 4),
        Text(
          'Filtered to combinations allowed for this life stage.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text('Reason', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Required for activity feeds and compliance events.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _PhysicalFormReasonVisualSelector(
          reasons: PhysicalFormChangeReason.values,
          selectedReason: widget.selectedReason,
          onChanged: widget.isBusy ? null : widget.onReasonChanged,
        ),
        if (widget.densityWarning != null &&
            widget.densityWarning!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AlertBanner(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            message: widget.densityWarning!,
          ),
        ],
        if (widget.validationMessage != null) ...[
          const SizedBox(height: 12),
          _AlertBanner(
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            message: widget.validationMessage!,
            dense: false,
          ),
        ],
      ],
    );
  }
}

class _CurrentPhysicalFormTile extends StatelessWidget {
  const _CurrentPhysicalFormTile({this.currentFormId, this.displayName});

  final String? currentFormId;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = displayName ?? currentFormId ?? 'Not specified';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.track_changes, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                Text('Current physical form', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (currentFormId != null)
            Chip(
              label: Text(currentFormId!, style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.icon,
    required this.color,
    required this.message,
    this.dense = true,
  });

  final IconData icon;
  final Color color;
  final String message;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final background = color.withValues(alpha: 0.1);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 8 : 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color.darken()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual selector for physical forms using card-style selection
class _PhysicalFormVisualSelector extends StatelessWidget {
  const _PhysicalFormVisualSelector({
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
        return _PhysicalFormCard(
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
class _PhysicalFormCard extends StatelessWidget {
  const _PhysicalFormCard({
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

/// Visual selector for physical form change reasons
class _PhysicalFormReasonVisualSelector extends StatelessWidget {
  const _PhysicalFormReasonVisualSelector({
    required this.reasons,
    required this.selectedReason,
    required this.onChanged,
  });

  final List<PhysicalFormChangeReason> reasons;
  final PhysicalFormChangeReason? selectedReason;
  final ValueChanged<PhysicalFormChangeReason?>? onChanged;

  IconData _getIconForReason(PhysicalFormChangeReason reason) {
    switch (reason) {
      case PhysicalFormChangeReason.growth:
        return Icons.trending_up;
      case PhysicalFormChangeReason.densityManagement:
        return Icons.compress;
      case PhysicalFormChangeReason.substrateChange:
        return Icons.layers;
      case PhysicalFormChangeReason.other:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isEnabled = onChanged != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: reasons.map((reason) {
        final isSelected = selectedReason == reason;

        return Material(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isEnabled ? () => onChanged!(reason) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIconForReason(reason),
                    size: 18,
                    color: isSelected
                        ? primaryColor
                        : (isEnabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      reason.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? primaryColor
                            : (isEnabled
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

extension on Color {
  Color darken([double amount = .1]) {
    final safeAmount = amount.clamp(0.0, 1.0);
    final f = 1 - safeAmount;
    return Color.fromARGB(
      (a * 255.0).round().clamp(0, 255),
      (r * 255.0 * f).round().clamp(0, 255),
      (g * 255.0 * f).round().clamp(0, 255),
      (b * 255.0 * f).round().clamp(0, 255),
    );
  }
}
