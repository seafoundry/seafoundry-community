import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';

/// Predefined reasons users can provide when advancing an organism to the next
/// life stage. Keeping the list centralized makes it easier to map to enums or
/// analytics later without hunting through multiple dialogs.
enum LifeStageTransitionReason {
  graduation('Graduation'),
  environmentalTrigger('Environmental trigger'),
  manualAdjustment('Manual adjustment'),
  other('Other');

  const LifeStageTransitionReason(this.label);

  final String label;
}

/// Structured inputs for editing life stage transitions. The surrounding bloc
/// or parent widget owns the validation logic (LifeStageTransitionService,
/// OrganismConstraintsService) and simply feeds the derived state into this
/// presentational widget.
class LifeStageTransitionEditor extends StatelessWidget {
  const LifeStageTransitionEditor({
    super.key,
    required this.currentStage,
    required this.allowedStages,
    required this.onStageChanged,
    this.selectedStage,
    this.selectedReason,
    this.onReasonChanged,
    this.minimumInterval,
    this.lastTransitionAt,
    this.validationMessage,
    this.helperText,
    this.isBusy = false,
  });

  final LifeStageSpec currentStage;
  final List<LifeStage> allowedStages;
  final LifeStage? selectedStage;
  final ValueChanged<LifeStage> onStageChanged;
  final LifeStageTransitionReason? selectedReason;
  final ValueChanged<LifeStageTransitionReason?>? onReasonChanged;
  final Duration? minimumInterval;
  final DateTime? lastTransitionAt;
  final String? validationMessage;
  final String? helperText;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Life stage', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _LifecycleSummary(currentStage: currentStage),
        const SizedBox(height: 12),
        Text('Next life stage', style: theme.textTheme.bodyMedium),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _LifeStageVisualSelector(
          stages: allowedStages,
          selectedStage: selectedStage,
          currentStage: currentStage.stage,
          onChanged: isBusy ? null : onStageChanged,
        ),
        const SizedBox(height: 16),
        Text('Transition reason', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Required so audit logs capture why the stage changed.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _TransitionReasonVisualSelector(
          reasons: LifeStageTransitionReason.values,
          selectedReason: selectedReason,
          onChanged: isBusy ? null : onReasonChanged,
        ),
        const SizedBox(height: 12),
        _RequirementsBanner(
          minimumInterval: minimumInterval,
          lastTransitionAt: lastTransitionAt,
        ),
        if (validationMessage != null) ...[
          const SizedBox(height: 12),
          _ValidationMessage(message: validationMessage!),
        ],
      ],
    );
  }
}

/// Visual selector for life stages using card-style selection
class _LifeStageVisualSelector extends StatelessWidget {
  const _LifeStageVisualSelector({
    required this.stages,
    required this.selectedStage,
    required this.currentStage,
    required this.onChanged,
  });

  final List<LifeStage> stages;
  final LifeStage? selectedStage;
  final LifeStage currentStage;
  final ValueChanged<LifeStage>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isEnabled = onChanged != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stages.map((stage) {
        final isSelected = selectedStage == stage;
        final isCurrent = currentStage == stage;

        return Material(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : isCurrent
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isEnabled ? () => onChanged!(stage) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : isCurrent
                      ? theme.colorScheme.outline
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stage.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? primaryColor
                          : (isEnabled
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  )),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Current',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Visual selector for transition reasons
class _TransitionReasonVisualSelector extends StatelessWidget {
  const _TransitionReasonVisualSelector({
    required this.reasons,
    required this.selectedReason,
    required this.onChanged,
  });

  final List<LifeStageTransitionReason> reasons;
  final LifeStageTransitionReason? selectedReason;
  final ValueChanged<LifeStageTransitionReason?>? onChanged;

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
              child: Center(
                child: Text(
                  reason.label,
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
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LifecycleSummary extends StatelessWidget {
  const _LifecycleSummary({required this.currentStage});

  final LifeStageSpec currentStage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtype = currentStage.subtype?.trim();
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.flag, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentStage.stage.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (subtype != null && subtype.isNotEmpty)
                    Text(
                      subtype,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              avatar: const Icon(Icons.lock_clock, size: 16),
              label: Text('Current', style: theme.textTheme.labelMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementsBanner extends StatelessWidget {
  const _RequirementsBanner({this.minimumInterval, this.lastTransitionAt});

  final Duration? minimumInterval;
  final DateTime? lastTransitionAt;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (minimumInterval != null) {
      chips.add(
        _InfoChip(
          icon: Icons.schedule,
          label:
              'Wait at least ${minimumInterval!.inDays} days between transitions',
        ),
      );
    }
    if (lastTransitionAt != null) {
      final formatted = DateFormat.yMMMd().format(lastTransitionAt!.toLocal());
      chips.add(
        _InfoChip(icon: Icons.history, label: 'Last transition: $formatted'),
      );
    }
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Requirements',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.primaryContainer.withAlpha(80),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
