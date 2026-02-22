// @tier: community
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/mixins/measurable_mixin.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/widgets/common/visual_selector.dart';

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
    this.volumeCm3,
    this.onVolumeCm3Changed,
    this.tissueAreaCm2,
    this.onTissueAreaCm2Changed,
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
  
  // Optional extra metrics
  final double? volumeCm3;
  final ValueChanged<double?>? onVolumeCm3Changed;
  final double? tissueAreaCm2;
  final ValueChanged<double?>? onTissueAreaCm2Changed;

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

        // Secondary metrics if enabled by size band
        if (useSizeBands) ...[
          Builder(
            builder: (context) {
              final activeBand = sizeBandConfigs
                  .where((b) => b.id == selectedSizeClass)
                  .firstOrNull;

              if (activeBand == null) return const SizedBox.shrink();

              final showVolume = activeBand.enableVolume;
              final showTissue = activeBand.enableTissueArea;

              if (!showVolume && !showTissue) return const SizedBox.shrink();

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (showVolume)
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('vol-${activeBand.id}'),
                            initialValue: volumeCm3?.toString() ?? '',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: activeBand.volumeLabel ??
                                  'Volume (cm³)',
                              helperText: () {
                                final defaultVolume = activeBand.defaultVolumeCm3 ??
                                    (activeBand.volumeMm3 / 1000.0);
                                return 'Default: ${_formatMetric(defaultVolume)} cm³';
                              }(),
                            ),
                            onChanged: (text) =>
                                onVolumeCm3Changed?.call(double.tryParse(text)),
                          ),
                        ),
                      if (showVolume && showTissue) const SizedBox(width: 12),
                      if (showTissue)
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('tissue-${activeBand.id}'),
                            initialValue: tissueAreaCm2?.toString() ?? '',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: activeBand.tissueAreaLabel ??
                                  'Tissue Area (cm²)',
                              helperText: activeBand.defaultTissueAreaCm2 !=
                                      null
                                  ? 'Default: ${_formatMetric(activeBand.defaultTissueAreaCm2!)} cm²'
                                  : null,
                            ),
                            onChanged: (text) =>
                                onTissueAreaCm2Changed?.call(double.tryParse(text)),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
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

  String _formatMetric(double value) {
    return value.round().toString();
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
