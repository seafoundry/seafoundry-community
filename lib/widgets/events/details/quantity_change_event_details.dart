// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/quantity_change_event.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/population_gain_reason.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'base_event_details.dart';

/// Widget for displaying quantity change event details.
class QuantityChangeEventDetails extends BaseEventDetails {
  QuantityChangeEventDetails({super.key, required QuantityChangeEvent event})
      : super(
          event: event,
          icon: event.newMeasurement.value > event.oldMeasurement.value
              ? Icons.trending_up_outlined
              : Icons.trending_down_outlined,
          title: event.newMeasurement.value > event.oldMeasurement.value
              ? 'Population Gain'
              : 'Population Loss',
        );

  QuantityChangeEvent get quantityEvent => event as QuantityChangeEvent;

  @override
  EventColors getDefaultColors() =>
      EventColors.fromBaseColor(AppColors.measurementEventColor);

  @override
  Widget buildEventContent(BuildContext context) {
    final metadata = quantityEvent.metadata ?? const <String, dynamic>{};
    final isGain = quantityEvent.newMeasurement.value >
        quantityEvent.oldMeasurement.value;
    final reasonLabel = _resolveReasonLabel(metadata, isGain);
    final mortalityLabel = _resolveMortalityLabel(metadata);
    final comment = _resolveComment(metadata);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventDetailRow(
          label: isGain ? 'Population Gain' : 'Population Loss',
          value: _formatMeasurementChange(
            quantityEvent.oldMeasurement,
            quantityEvent.newMeasurement,
          ),
          icon: isGain
              ? Icons.trending_up_outlined
              : Icons.trending_down_outlined,
        ),
        if (quantityEvent.delta != 0) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Delta',
            value:
                '${_formatDelta(quantityEvent.delta)} ${quantityEvent.newMeasurement.unit.symbol}',
            icon: Icons.swap_vert,
          ),
        ],
        if (quantityEvent.hasCompoundChanges) ...[
          if (quantityEvent.oldCount != null || quantityEvent.newCount != null)
            _buildCompoundRow(
              label: 'Count',
              oldValue: quantityEvent.oldCount?.toDouble(),
              newValue: quantityEvent.newCount?.toDouble(),
              deltaValue: quantityEvent.countDelta?.toDouble(),
              unit: '',
              icon: Icons.numbers,
            ),
          if (quantityEvent.oldVolumeCm3 != null ||
              quantityEvent.newVolumeCm3 != null)
            _buildCompoundRow(
              label: 'Volume',
              oldValue: quantityEvent.oldVolumeCm3,
              newValue: quantityEvent.newVolumeCm3,
              deltaValue: quantityEvent.volumeDelta,
              unit: 'cm³',
              icon: Icons.square_foot,
            ),
          if (quantityEvent.oldTissueAreaCm2 != null ||
              quantityEvent.newTissueAreaCm2 != null)
            _buildCompoundRow(
              label: 'Tissue Area',
              oldValue: quantityEvent.oldTissueAreaCm2,
              newValue: quantityEvent.newTissueAreaCm2,
              deltaValue: quantityEvent.tissueAreaDelta,
              unit: 'cm²',
              icon: Icons.crop_square,
            ),
        ],
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
        if (comment != null && comment.trim().isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          UIText.caption('Comment:', color: AppColors.textSecondary),
          SizedBox(height: Spacing.xs),
          UIText.bodyMedium(comment.trim()),
        ],
      ],
    );
  }

  Widget _buildCompoundRow({
    required String label,
    required double? oldValue,
    required double? newValue,
    required double? deltaValue,
    required String unit,
    required IconData icon,
  }) {
    final oldText = oldValue == null ? '-' : _formatValue(oldValue);
    final newText = newValue == null ? '-' : _formatValue(newValue);
    final deltaText = deltaValue == null ? '' : _formatDelta(deltaValue);
    final unitSuffix = unit.isEmpty ? '' : ' $unit';
    final deltaSuffix = deltaText.isEmpty ? '' : ' ($deltaText$unitSuffix)';

    return Padding(
      padding: EdgeInsets.only(top: Spacing.xs),
      child: EventDetailRow(
        label: label,
        value: '$oldText$unitSuffix → $newText$unitSuffix$deltaSuffix',
        icon: icon,
      ),
    );
  }

  String _formatMeasurementChange(
    PopulationMeasurement oldMeasurement,
    PopulationMeasurement newMeasurement,
  ) {
    final oldValue = _formatValue(oldMeasurement.value);
    final newValue = _formatValue(newMeasurement.value);
    return '$oldValue ${oldMeasurement.unit.symbol} → '
        '$newValue ${newMeasurement.unit.symbol}';
  }

  String _formatValue(double value) {
    final rounded = value.roundToDouble();
    if (value == rounded) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatDelta(num value) {
    final sign = value > 0 ? '+' : '';
    final formatted =
        value is int ? value.toString() : _formatValue(value.toDouble());
    return '$sign$formatted';
  }

  String? _resolveReasonLabel(
    Map<String, dynamic> metadata,
    bool isGain,
  ) {
    final gainReasonId = metadata['gainReasonId']?.toString();
    final lossReasonId = metadata['lossReasonId']?.toString();
    final quantityReasonId = metadata['quantityReason']?.toString();

    if (isGain) {
      if (gainReasonId != null && gainReasonId.trim().isNotEmpty) {
        final reason = PopulationGainReason.builtins[gainReasonId];
        return reason?.name ?? _formatToken(gainReasonId);
      }
    } else {
      if (lossReasonId != null && lossReasonId.trim().isNotEmpty) {
        final reason = PopulationLossReason.builtins[lossReasonId];
        return reason?.name ?? _formatToken(lossReasonId);
      }
    }

    if (quantityReasonId != null && quantityReasonId.trim().isNotEmpty) {
      return _formatToken(quantityReasonId);
    }
    return null;
  }

  String? _resolveMortalityLabel(Map<String, dynamic> metadata) {
    final mortalityId = metadata['mortalityReasonId']?.toString();
    if (mortalityId == null || mortalityId.trim().isEmpty) {
      return null;
    }
    final builtIn = MortalityReason.builtins[mortalityId];
    return builtIn?.name ?? _formatToken(mortalityId);
  }

  String? _resolveComment(Map<String, dynamic> metadata) {
    final comment = metadata['comment']?.toString();
    if (comment != null && comment.trim().isNotEmpty) {
      return comment;
    }
    final quantityComment = metadata['quantityComment']?.toString();
    if (quantityComment != null && quantityComment.trim().isNotEmpty) {
      return quantityComment;
    }
    return null;
  }

  String _formatToken(String value) {
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
