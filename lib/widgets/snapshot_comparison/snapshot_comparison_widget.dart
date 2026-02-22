// @tier: community
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/event_history_repository.dart';
import 'package:seafoundry_app/services/snapshot_comparison_service.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Snapshot comparison widget that renders field-level diffs between two points in time.
class SnapshotComparisonWidget extends StatefulWidget {
  const SnapshotComparisonWidget({
    super.key,
    required this.recordId,
    required this.recordModelType,
    required this.pointInTime1,
    required this.pointInTime2,
  });

  final String recordId;
  final ModelType recordModelType;
  final DateTime pointInTime1;
  final DateTime pointInTime2;

  @override
  State<SnapshotComparisonWidget> createState() =>
      _SnapshotComparisonWidgetState();
}

class _SnapshotComparisonWidgetState extends State<SnapshotComparisonWidget> {
  late Future<_SnapshotComparisonResult> _comparisonFuture;

  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy – HH:mm');

  @override
  void initState() {
    super.initState();
    _comparisonFuture = _loadComparison();
  }

  @override
  void didUpdateWidget(SnapshotComparisonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId ||
        oldWidget.recordModelType != widget.recordModelType ||
        oldWidget.pointInTime1 != widget.pointInTime1 ||
        oldWidget.pointInTime2 != widget.pointInTime2) {
      _comparisonFuture = _loadComparison();
    }
  }

  Future<_SnapshotComparisonResult> _loadComparison() async {
    final dates = [widget.pointInTime1, widget.pointInTime2]..sort();
    final snapshotService =
        context.maybeRead<SnapshotComparisonService>() ??
            SnapshotComparisonService();
    final eventHistoryRepository =
        context.maybeRead<EventHistoryRepository>();
    if (eventHistoryRepository == null) {
      throw Exception('Event history repository unavailable.');
    }

    final events = await eventHistoryRepository.getEventsForRecord(
      recordId: widget.recordId,
      recordModelType: widget.recordModelType,
      endDate: dates.last,
    );
    final inventoryEvents = events.whereType<InventoryEvent>().toList();

    if (inventoryEvents.isEmpty) {
      throw Exception('No snapshot events available for this record.');
    }

    if (widget.recordModelType == ModelType.genet) {
      final comparison = await snapshotService.compareGeneticSnapshots(
        genetId: widget.recordId,
        pointInTime1: dates.first,
        pointInTime2: dates.last,
        events: inventoryEvents,
      );
      return _SnapshotComparisonResult.fromComparison(comparison);
    }

    if (widget.recordModelType == ModelType.organismRecord) {
      final comparison = await snapshotService.compareInventorySnapshots(
        recordId: widget.recordId,
        recordModelType: widget.recordModelType,
        pointInTime1: dates.first,
        pointInTime2: dates.last,
        events: inventoryEvents,
      );
      return _SnapshotComparisonResult.fromComparison(comparison);
    }

    throw Exception('Snapshot comparison is only available for organisms and genets.');
  }

  @override
  Widget build(BuildContext context) {
    final dates = [widget.pointInTime1, widget.pointInTime2]..sort();
    final duration = dates[1].difference(dates[0]);

    return FutureBuilder<_SnapshotComparisonResult>(
      future: _comparisonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to compare snapshots',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _comparisonFuture = _loadComparison();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return const Center(child: Text('No snapshot data available.'));
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparing ${widget.recordModelType.name} snapshots for ${widget.recordId}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _SnapshotPointCard(label: 'Earlier Snapshot', timestamp: dates[0]),
                const SizedBox(height: 12),
                _SnapshotPointCard(label: 'Later Snapshot', timestamp: dates[1]),
                const SizedBox(height: 16),
                Text(
                  'Elapsed time: ${_formatDuration(duration)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(context, result),
                if (!result.hasChanges) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No field-level changes detected between these snapshots.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  _buildChangeSection(
                    context,
                    title: 'Critical Changes',
                    changes: result.criticalChanges,
                    accent: Colors.red.shade400,
                  ),
                  _buildChangeSection(
                    context,
                    title: 'Significant Changes',
                    changes: result.significantChanges,
                    accent: Colors.orange.shade400,
                  ),
                  _buildChangeSection(
                    context,
                    title: 'Minor Changes',
                    changes: result.minorChanges,
                    accent: Colors.blueGrey.shade400,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, _SnapshotComparisonResult result) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              result.hasChanges ? Icons.analytics_outlined : Icons.check_circle_outline,
              color: result.hasChanges
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeSection(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> changes,
    required Color accent,
  }) {
    if (changes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...changes.entries.map((entry) {
              final change = entry.value as Map<String, dynamic>? ?? {};
              final fromValue = change['from'];
              final toValue = change['to'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatFieldLabel(entry.key),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${_formatValue(fromValue)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'To: ${_formatValue(toValue)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatFieldLabel(String raw) {
    final normalized = raw
        .replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1_$2')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    return formatSnakeCaseToTitleCase(normalized);
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is HealthStatus) return value.displayName;
    if (value is DateTime) return _dateFormat.format(value);
    return value.toString();
  }

  static String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[];
    if (days != 0) parts.add('$days day${days.abs() == 1 ? '' : 's'}');
    if (hours != 0) parts.add('$hours hour${hours.abs() == 1 ? '' : 's'}');
    if (minutes != 0 || parts.isEmpty) {
      parts.add('$minutes minute${minutes.abs() == 1 ? '' : 's'}');
    }
    return parts.join(', ');
  }
}

class _SnapshotComparisonResult {
  const _SnapshotComparisonResult({
    required this.summary,
    required this.criticalChanges,
    required this.significantChanges,
    required this.minorChanges,
    required this.hasChanges,
  });

  final String summary;
  final Map<String, dynamic> criticalChanges;
  final Map<String, dynamic> significantChanges;
  final Map<String, dynamic> minorChanges;
  final bool hasChanges;

  factory _SnapshotComparisonResult.fromComparison(dynamic comparison) {
    if (comparison is InventoryComparison) {
      return _SnapshotComparisonResult(
        summary: comparison.changeSummary,
        criticalChanges: comparison.criticalChanges,
        significantChanges: comparison.significantChanges,
        minorChanges: comparison.minorChanges,
        hasChanges: comparison.hasChanges,
      );
    }
    if (comparison is GeneticComparison) {
      return _SnapshotComparisonResult(
        summary: comparison.changeSummary,
        criticalChanges: comparison.criticalChanges,
        significantChanges: comparison.significantChanges,
        minorChanges: comparison.minorChanges,
        hasChanges: comparison.hasChanges,
      );
    }
    throw ArgumentError('Unsupported comparison type');
  }
}

class _SnapshotPointCard extends StatelessWidget {
  const _SnapshotPointCard({required this.label, required this.timestamp});

  final String label;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              _SnapshotComparisonWidgetState._dateFormat.format(timestamp),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
