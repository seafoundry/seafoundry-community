import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_community/models/inventory/physical_form_config.dart';
import 'package:seafoundry_community/models/inventory/size_spec.dart';
import 'package:seafoundry_community/models/mixins/measurable_mixin.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';
import 'package:seafoundry_community/widgets/common/visual_selector.dart';

class SizeChangeEditor extends StatelessWidget {
  const SizeChangeEditor({
    super.key,
    required this.currentSize,
    required this.onSizeClassChanged,
    this.sizeClassOptions = const [],
    this.sizeBandConfigs = const [],
    this.selectedSizeClass,
    this.history = const [],
    this.validationMessage,
    this.placeholderLabel = 'Size class',
    this.isBusy = false,
    this.showCurrentSize = true,
  });

  final SizeSpec currentSize;
  
  /// Whether to show the read-only current size tile (default true)
  final bool showCurrentSize;

  /// Simple string options for size classes (legacy/fallback)
  final List<String> sizeClassOptions;

  /// Rich size band configs from physical form (preferred)
  final List<SizeBandConfig> sizeBandConfigs;

  final String? selectedSizeClass;
  final ValueChanged<String?> onSizeClassChanged;
  final List<MeasurementSnapshot> history;
  final String? validationMessage;
  final String placeholderLabel;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Prefer rich size band configs over simple string options
    final useSizeBands = sizeBandConfigs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCurrentSize) ...[
          Text('Size', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _CurrentSizeTile(currentSize: currentSize),
          const SizedBox(height: 12),
        ],

        // Size class visual selector
        Text(placeholderLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        if (useSizeBands)
          SizeBandVisualSelector(
            sizeBands: sizeBandConfigs,
            selectedBandId: selectedSizeClass,
            onChanged: isBusy ? null : onSizeClassChanged,
          )
        else
          SizeClassVisualSelector(
            options: sizeClassOptions,
            selectedClass: selectedSizeClass,
            onChanged: isBusy ? null : onSizeClassChanged,
          ),

        if (validationMessage != null) ...[
          const SizedBox(height: 12),
          _ValidationBanner(message: validationMessage!),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Recent measurements', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          _MeasurementHistoryList(history: history),
        ],
      ],
    );
  }

}

class _CurrentSizeTile extends StatelessWidget {
  const _CurrentSizeTile({required this.currentSize});

  final SizeSpec currentSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classLabel = currentSize.sizeClass ?? 'Not set';
    final measurement = currentSize.measuredDimension;
    final unit = currentSize.dimensionUnit?.label ?? '';
    final valueLabel = measurement == null
        ? '-'
        : '${measurement.toString()} $unit'.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.straighten, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(classLabel, style: theme.textTheme.titleMedium),
                Text(valueLabel, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _MeasurementHistoryList extends StatelessWidget {
  const _MeasurementHistoryList({required this.history});

  final List<MeasurementSnapshot> history;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.yMMMd();
    return Column(
      children: history
          .take(5)
          .map(
            (snapshot) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timeline, size: 18),
              title: Text(
                '${snapshot.measurement.value.toString()} ${snapshot.measurement.unit.label}',
              ),
              subtitle: Text(
                formatter.format(snapshot.recordedAt ?? DateTime.now()),
              ),
            ),
          )
          .toList(growable: false),
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
          Icon(Icons.error, color: theme.colorScheme.error),
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
