// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/mortality_event.dart';
import 'package:seafoundry_app/models/events/outplant_mortality_event.dart';
import 'package:seafoundry_app/models/events/population_gain_event.dart';
import 'package:seafoundry_app/models/events/population_loss_event.dart';
import 'package:seafoundry_app/models/types/population_gain_reason.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'base_event_details.dart';

/// Widget for displaying population gain/loss details.
class PopulationChangeEventDetails extends BaseEventDetails {
  const PopulationChangeEventDetails({
    super.key,
    required super.event,
  }) : super(
          icon: event is PopulationGainEvent
              ? Icons.trending_up_outlined
              : Icons.trending_down_outlined,
          title: event is PopulationGainEvent
              ? 'Population Gain'
              : 'Population Loss',
        );

  bool get isGain => event is PopulationGainEvent;

  int get oldPopulation => isGain
      ? (event as PopulationGainEvent).oldPopulation
      : (event as PopulationLossEvent).oldPopulation;

  int get newPopulation => isGain
      ? (event as PopulationGainEvent).newPopulation
      : (event as PopulationLossEvent).newPopulation;

  int get delta => newPopulation - oldPopulation;

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(
        isGain ? AppColors.success : AppColors.error,
      );

  @override
  Widget buildEventContent(BuildContext context) {
    final reasonLabel = _resolveReasonLabel();
    final mortalityLabel = _resolveMortalityLabel();
    final diseaseType = _resolveDiseaseType();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventDetailRow(
          label: isGain ? 'Population Gain' : 'Population Loss',
          value: '$oldPopulation → $newPopulation',
          icon: isGain ? Icons.trending_up_outlined : Icons.trending_down_outlined,
        ),
        SizedBox(height: Spacing.xs),
        EventDetailRow(
          label: 'Delta',
          value: _formatDelta(delta),
          icon: Icons.swap_vert,
        ),
        SizedBox(height: Spacing.sm),
        EventDetailRow(
          label: 'Reason',
          value: reasonLabel ?? 'Not provided',
          icon: Icons.flag_outlined,
        ),
        if (mortalityLabel != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Mortality Cause',
            value: mortalityLabel,
            icon: Icons.warning_amber_outlined,
          ),
        ],
        if (diseaseType != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Disease Type',
            value: diseaseType,
            icon: Icons.coronavirus_outlined,
          ),
        ],
        if (_eventComment != null && _eventComment!.trim().isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          UIText.caption('Comment:', color: AppColors.textSecondary),
          SizedBox(height: Spacing.xs),
          UIText.bodyMedium(_eventComment!.trim()),
        ],
      ],
    );
  }

  String? get _eventComment {
    if (event is PopulationGainEvent) {
      return (event as PopulationGainEvent).comment;
    }
    return (event as PopulationLossEvent).comment;
  }

  String _formatDelta(int delta) {
    final sign = delta > 0 ? '+' : '';
    return '$sign$delta';
  }

  String? _resolveReasonLabel() {
    if (isGain) {
      final gainEvent = event as PopulationGainEvent;
      final reason = PopulationGainReason.builtins[gainEvent.gainReasonId];
      return reason?.name ?? _formatToken(gainEvent.gainReasonId);
    }

    final lossEvent = event as PopulationLossEvent;
    if (lossEvent is OutplantMortalityEvent) {
      final reason = OutplantLossReason.builtins[lossEvent.outplantLossReasonId];
      return reason?.name ?? _formatToken(lossEvent.outplantLossReasonId);
    }
    final reason = PopulationLossReason.builtins[lossEvent.lossReasonId];
    return reason?.name ?? _formatToken(lossEvent.lossReasonId);
  }

  String? _resolveMortalityLabel() {
    if (event is! MortalityEvent) {
      return null;
    }
    final mortalityEvent = event as MortalityEvent;
    final reason = MortalityReason.builtins[mortalityEvent.mortalityReasonId];
    return reason?.name ?? _formatToken(mortalityEvent.mortalityReasonId);
  }

  String? _resolveDiseaseType() {
    String? diseaseTypeId;
    if (event is MortalityEvent) {
      diseaseTypeId = (event as MortalityEvent).diseaseTypeId;
    } else if (event is OutplantMortalityEvent) {
      diseaseTypeId = (event as OutplantMortalityEvent).diseaseTypeId;
    }
    if (diseaseTypeId == null || diseaseTypeId.trim().isEmpty) {
      return null;
    }
    return _formatToken(diseaseTypeId);
  }

  String _formatToken(String value) {
    if (value.trim().isEmpty) return '';
    return value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
