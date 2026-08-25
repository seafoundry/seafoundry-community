import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/inventory/quantity_change.dart';
import 'package:seafoundry_community/models/population_measurement.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';
import 'package:seafoundry_community/models/types/population_loss_reason.dart';

export 'package:seafoundry_community/models/inventory/quantity_change.dart';

class QuantityChangeEditor extends StatelessWidget {
  const QuantityChangeEditor({
    super.key,
    required this.currentMeasurement,
    required this.onKindChanged,
    required this.onReasonChanged,
    required this.onValueChanged,
    this.kind = QuantityChangeKind.gain,
    this.selectedReason,
    this.pendingValue,
    this.mortalityReason,
    this.onMortalityReasonChanged,
    this.comment,
    this.commentHint,
    this.onCommentChanged,
    this.validationMessage,
    this.isBusy = false,
  });

  final PopulationMeasurement currentMeasurement;
  final QuantityChangeKind kind;
  final ValueChanged<QuantityChangeKind> onKindChanged;
  final QuantityChangeReason? selectedReason;
  final ValueChanged<QuantityChangeReason?> onReasonChanged;
  final double? pendingValue;
  final ValueChanged<double?> onValueChanged;
  final PopulationLossReason? mortalityReason;
  final ValueChanged<PopulationLossReason?>? onMortalityReasonChanged;
  final String? comment;
  final String? commentHint;
  final ValueChanged<String>? onCommentChanged;
  final String? validationMessage;
  final bool isBusy;

  bool _showMortalitySelector(BuildContext context) {
    if (kind != QuantityChangeKind.loss) return false;
    if (selectedReason?.id != 'mortality') return false;
    if (onMortalityReasonChanged == null) return false;
    return true;
  }

  /// Returns true if the pending value differs from current measurement.
  bool get _hasQuantityChange {
    final valueChanged =
        pendingValue != null && pendingValue != currentMeasurement.value;
    return valueChanged;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reasonOptions = kind == QuantityChangeKind.gain
        ? QuantityChangeReason.gainReasons
        : QuantityChangeReason.lossReasons;
    final showValidation = _hasQuantityChange && validationMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _CurrentQuantityTile(measurement: currentMeasurement),
        const SizedBox(height: 12),

        // Gain/Loss visual selector
        Text('Change type', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        _QuantityKindVisualSelector(
          selectedKind: kind,
          onChanged: isBusy ? null : onKindChanged,
        ),
        const SizedBox(height: 12),

        // New quantity input
        TextFormField(
          initialValue: pendingValue?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New quantity',
            helperText: 'Must be greater than or equal to zero.',
          ),
          onChanged: isBusy
              ? null
              : (value) {
                  final parsed = double.tryParse(value);
                  onValueChanged(parsed);
                },
        ),
        const SizedBox(height: 12),

        // Reason visual selector
        Text('Reason', style: theme.textTheme.bodyMedium),
        if (showValidation && selectedReason == null) ...[
          const SizedBox(height: 4),
          Text(
            'Required',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _QuantityReasonVisualSelector(
          reasons: reasonOptions,
          selectedReason: selectedReason,
          onChanged: isBusy ? null : onReasonChanged,
        ),

        // Mortality cause selector
        if (_showMortalitySelector(context)) ...[
          const SizedBox(height: 12),
          Text('Mortality cause', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Used for compliance + activity feeds.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _MortalityReasonVisualSelector(
            reasons: PopulationLossReason.mortalityReasonBuiltins.values.toList(growable: false),
            selectedReason: mortalityReason,
            onChanged: isBusy ? null : onMortalityReasonChanged,
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          initialValue: comment,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Comment',
            helperText: 'Optional notes for this change.',
            hintText: commentHint,
          ),
          onChanged: isBusy ? null : onCommentChanged,
        ),
        if (showValidation) ...[
          const SizedBox(height: 12),
          _ValidationBanner(message: validationMessage!),
        ],
      ],
    );
  }
}

/// Visual selector for quantity change kind (Gain/Loss)
class _QuantityKindVisualSelector extends StatelessWidget {
  const _QuantityKindVisualSelector({
    required this.selectedKind,
    required this.onChanged,
  });

  final QuantityChangeKind selectedKind;
  final ValueChanged<QuantityChangeKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isEnabled = onChanged != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: QuantityChangeKind.values.map((kind) {
        final isSelected = selectedKind == kind;
        final isGain = kind == QuantityChangeKind.gain;
        final icon = isGain ? Icons.add_circle_outline : Icons.remove_circle_outline;
        final label = isGain ? 'Gain' : 'Loss';

        return Material(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isEnabled ? () => onChanged!(kind) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 100, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    icon,
                    size: 20,
                    color: isSelected
                        ? primaryColor
                        : (isEnabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? primaryColor
                          : (isEnabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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

/// Visual selector for quantity change reasons
class _QuantityReasonVisualSelector extends StatelessWidget {
  const _QuantityReasonVisualSelector({
    required this.reasons,
    required this.selectedReason,
    required this.onChanged,
  });

  final List<QuantityChangeReason> reasons;
  final QuantityChangeReason? selectedReason;
  final ValueChanged<QuantityChangeReason?>? onChanged;

  IconData _getIconForReason(String id) {
    switch (id) {
      case 'reproduction':
        return Icons.favorite;
      case 'transferIn':
        return Icons.arrow_downward;
      case 'split':
        return Icons.call_split;
      case 'otherGain':
        return Icons.add;
      case 'mortality':
        return Icons.cancel;
      case 'transferOut':
        return Icons.arrow_upward;
      case 'outplant':
        return Icons.forest;
      case 'density':
        return Icons.compress;
      case 'otherLoss':
        return Icons.remove;
      default:
        return Icons.help_outline;
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
                    _getIconForReason(reason.id),
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

/// Visual selector for mortality reasons
class _MortalityReasonVisualSelector extends StatelessWidget {
  const _MortalityReasonVisualSelector({
    required this.reasons,
    required this.selectedReason,
    required this.onChanged,
  });

  final List<PopulationLossReason> reasons;
  final PopulationLossReason? selectedReason;
  final ValueChanged<PopulationLossReason?>? onChanged;

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
              constraints: const BoxConstraints(minWidth: 72, minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  reason.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? primaryColor
                        : (isEnabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CurrentQuantityTile extends StatelessWidget {
  const _CurrentQuantityTile({required this.measurement});

  final PopulationMeasurement measurement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = '${measurement.value} ${measurement.unit.label}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.trim(), style: theme.textTheme.titleMedium),
                Text('Current measurement', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

