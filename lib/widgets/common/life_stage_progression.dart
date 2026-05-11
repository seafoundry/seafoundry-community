import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/mixins/life_stage_progression_mixin.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/validation/validation_result.dart';
import 'package:seafoundry_app/services/life_stage_transition_service.dart';

/// Visualizes the canonical life-stage order for an [OrganismRecord] and shows
/// whether upcoming transitions satisfy validation and timing requirements.
class LifeStageProgressionWidget extends StatelessWidget {
  const LifeStageProgressionWidget({
    super.key,
    required this.record,
    required this.transitionService,
    this.orderedStages = LifeStage.values,
    this.onStageSelected,
    this.showHistory = true,
    this.compact = false,
  });

  final OrganismRecord record;
  final LifeStageTransitionService transitionService;
  final List<LifeStage> orderedStages;
  final ValueChanged<LifeStage>? onStageSelected;
  final bool showHistory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = orderedStages.toList();
    if (!stages.contains(record.lifeStage.stage)) {
      stages.add(record.lifeStage.stage);
    }
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _StageTimeline(
              stages: stages,
              currentStage: record.lifeStage.stage,
              onTap: onStageSelected,
              dense: compact,
            ),
            const SizedBox(height: 16),
            _NextStageRequirements(
              record: record,
              stages: stages,
              transitionService: transitionService,
            ),
            if (showHistory && record.lifeStageHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              _HistoryChips(history: record.lifeStageHistory),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Life-stage progression',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 14 : 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: const Icon(Icons.flag, size: 16),
            label: Text(record.lifeStage.stage.displayName),
          ),
        ),
      ],
    );
  }
}

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({
    required this.stages,
    required this.currentStage,
    this.onTap,
    this.dense = false,
  });

  final List<LifeStage> stages;
  final LifeStage currentStage;
  final ValueChanged<LifeStage>? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final currentIndex = stages.indexOf(currentStage);
    final spacing = dense ? 8.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.start,
          spacing: spacing,
          runSpacing: 12,
          children: [
            for (int i = 0; i < stages.length; i++)
              _StageChip(
                stage: stages[i],
                status: _statusFor(i, currentIndex),
                onTap: onTap,
                dense: dense,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _ProgressBar(progress: (currentIndex + 1) / stages.length),
      ],
    );
  }

  _StageStatus _statusFor(int index, int currentIndex) {
    if (index < currentIndex) return _StageStatus.completed;
    if (index == currentIndex) return _StageStatus.current;
    return _StageStatus.upcoming;
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.stage,
    required this.status,
    this.onTap,
    this.dense = false,
  });

  final LifeStage stage;
  final _StageStatus status;
  final ValueChanged<LifeStage>? onTap;
  final bool dense;

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case _StageStatus.completed:
        return scheme.primary;
      case _StageStatus.current:
        return scheme.tertiary;
      case _StageStatus.upcoming:
        return scheme.outline;
    }
  }

  IconData _icon() {
    switch (status) {
      case _StageStatus.completed:
        return Icons.check_circle;
      case _StageStatus.current:
        return Icons.radio_button_checked;
      case _StageStatus.upcoming:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 6 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.8)),
        color: status == _StageStatus.current
            ? color.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), color: color, size: dense ? 18 : 22),
          const SizedBox(height: 6),
          Text(
            stage.displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: dense ? 12 : 14,
              fontWeight: status == _StageStatus.current
                  ? FontWeight.w600
                  : null,
            ),
          ),
        ],
      ),
    );
    final body = onTap == null
        ? content
        : InkWell(onTap: () => onTap!(stage), child: content);
    return body;
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          backgroundColor: scheme.surfaceContainerHighest,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _NextStageRequirements extends StatelessWidget {
  const _NextStageRequirements({
    required this.record,
    required this.stages,
    required this.transitionService,
  });

  final OrganismRecord record;
  final List<LifeStage> stages;
  final LifeStageTransitionService transitionService;

  @override
  Widget build(BuildContext context) {
    final currentIndex = stages.indexOf(record.lifeStage.stage);
    final candidates = stages
        .skip(currentIndex + 1)
        .take(3)
        .map(
          (stage) => _RequirementEntry(
            stage: stage,
            validation: transitionService.canTransition(
              record: record,
              targetStage: stage,
              minimumInterval: record.customMinimumStageInterval,
            ),
            minimumInterval: record.customMinimumStageInterval,
            measurementSummary:
                '${record.measurement.value.toStringAsFixed(1)} '
                '${record.measurement.unit.symbol}',
          ),
        )
        .toList(growable: false);

    if (candidates.isEmpty) {
      return const _RequirementEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Next transition requirements',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...candidates.map((entry) => _RequirementTile(entry: entry)),
      ],
    );
  }
}

class _RequirementEntry {
  _RequirementEntry({
    required this.stage,
    required this.validation,
    required this.measurementSummary,
    this.minimumInterval,
  });

  final LifeStage stage;
  final ValidationResult validation;
  final String measurementSummary;
  final Duration? minimumInterval;
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({required this.entry});

  final _RequirementEntry entry;

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (entry.validation.isValid) {
      return scheme.tertiary;
    }
    switch (entry.validation.severity) {
      case ValidationSeverity.info:
        return scheme.tertiary;
      case ValidationSeverity.warning:
        return scheme.secondary;
      case ValidationSeverity.error:
        return scheme.error;
    }
  }

  IconData _icon() {
    if (entry.validation.isValid) return Icons.check_circle;
    switch (entry.validation.severity) {
      case ValidationSeverity.info:
        return Icons.info_outline;
      case ValidationSeverity.warning:
        return Icons.warning_amber;
      case ValidationSeverity.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final helper = <String>[];
    if (entry.minimumInterval != null) {
      helper.add(
        'Wait ${entry.minimumInterval!.inDays} days between transitions.',
      );
    }
    helper.add('Current measurement: ${entry.measurementSummary}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon(), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.stage.displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color.darken()),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.validation.isValid
                      ? 'Ready to progress once scheduled.'
                      : entry.validation.message ?? 'Validation required.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  helper.join(' '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementEmptyState extends StatelessWidget {
  const _RequirementEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_circle, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No future life stages are configured for this organism.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryChips extends StatelessWidget {
  const _HistoryChips({required this.history});

  final List<LifeStageTransition> history;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Previous transitions',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: history
              .map((transition) {
                final label = transition.toStage.stage.displayName;
                final occurredAt = transition.occurredAt != null
                    ? formatter.format(transition.occurredAt!.toLocal())
                    : 'Unknown date';
                return Chip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text('$label · $occurredAt'),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

enum _StageStatus { completed, current, upcoming }

extension on Color {
  Color darken([double amount = .2]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
