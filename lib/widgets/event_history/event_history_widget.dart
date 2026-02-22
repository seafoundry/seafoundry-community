// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/event_history_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/event_history_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Widget for displaying event histories with timeline visualization
class EventHistoryWidget extends StatefulWidget {
  final String recordId;
  final ModelType recordModelType;

  /// Human-readable name shown in the header (e.g. localId for organisms).
  final String? recordDisplayName;

  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? eventTypes;

  const EventHistoryWidget({
    super.key,
    required this.recordId,
    required this.recordModelType,
    this.recordDisplayName,
    this.startDate,
    this.endDate,
    this.eventTypes,
  });

  @override
  State<EventHistoryWidget> createState() => _EventHistoryWidgetState();
}

class _EventHistoryWidgetState extends State<EventHistoryWidget> {
  EventHistory? _eventHistory;
  EventTimeline? _eventTimeline;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEventHistory();
  }

  Future<void> _loadEventHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      EventHistoryService? eventHistoryService =
          context.maybeRead<EventHistoryService>();
      if (eventHistoryService == null) {
        final eventHistoryRepository =
            context.maybeRead<EventHistoryRepository>();
        if (eventHistoryRepository == null) {
          setState(() {
            _error = 'Event history service not available.';
            _isLoading = false;
          });
          return;
        }
        eventHistoryService = EventHistoryService(
          eventHistoryRepository: eventHistoryRepository,
          siteRepository: context.maybeRead<SiteRepository>(),
          groupRepository: context.maybeRead<GroupRepository>(),
          organismRepository: context.maybeRead<OrganismRecordRepository>(),
        );
      }

      // Build event history using the service
      final eventHistory = await eventHistoryService.buildEventHistory(
        recordId: widget.recordId,
        recordModelType: widget.recordModelType,
        startDate: widget.startDate,
        endDate: widget.endDate,
        eventTypes: widget.eventTypes,
      );

      // Build event timeline
      final eventTimeline = await eventHistoryService.buildEventTimeline(
        recordId: widget.recordId,
        recordModelType: widget.recordModelType,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      if (mounted) {
        setState(() {
          _eventHistory = eventHistory;
          _eventTimeline = eventTimeline;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to load event history', e, stackTrace);
      if (mounted) {
        setState(() {
          _error = 'Failed to load event history: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Event History',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadEventHistory,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_eventHistory == null || _eventTimeline == null) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No event history available',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check if we're in a constrained environment (like a bottom sheet)
    // by using LayoutBuilder to adapt to available space
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;

        if (!maxHeight.isFinite) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTimeline(scrollable: true),
              ],
            ),
          );
        }

        if (maxHeight < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight - 140),
                child: _buildTimeline(scrollable: true),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildTimeline(scrollable: false)),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Event History',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.recordDisplayName != null
                  ? '${widget.recordDisplayName} (${widget.recordModelType.name})'
                  : 'Record: ...${widget.recordId.substring(widget.recordId.length > 8 ? widget.recordId.length - 8 : 0)} (${widget.recordModelType.name})',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_eventHistory != null) ...[
              const SizedBox(height: 4),
              Text(
                _eventHistory!.summary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline({required bool scrollable}) {
    if (_eventTimeline!.entries.isEmpty) {
      return _buildEmptyTimeline();
    }

    final timelineEntries = _eventTimeline!.entries
        .asMap()
        .entries
        .map((entry) => _buildTimelineEntry(entry.value, entry.key))
        .toList();

    if (!scrollable) {
      return ListView.builder(
        itemCount: timelineEntries.length,
        itemBuilder: (context, index) => timelineEntries[index],
      );
    }

    return SingleChildScrollView(child: Column(children: timelineEntries));
  }

  Widget _buildEmptyTimeline() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No events found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Events will appear here as they are recorded',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEntry(TimelineEntry entry, int index) {
    final isLast = index == _eventTimeline!.entries.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getEventColor(entry.event),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 16),
        // Event content
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getEventIcon(entry.event),
                        size: 16,
                        color: _getEventColor(entry.event),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getEventTitle(entry.event),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        _formatDate(entry.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (entry.hasSignificantChanges) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.compare_arrows,
                                size: 14,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Changes Detected',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.changeSummary,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getEventColor(Event event) {
    final id = event.eventTypeId;
    if (id.contains('population_gain') || id.contains('propagation')) {
      return Colors.green;
    }
    if (id.contains('population_loss') || id.contains('tissue_loss')) {
      return Colors.red;
    }
    if (id.contains('delete') || id.contains('archive')) return Colors.red;
    if (id.contains('observation') || id.contains('survey')) return Colors.orange;
    if (id.contains('task')) return Colors.blue;
    if (id.contains('husbandry') || id.contains('feeding') ||
        id.contains('cleaning') || id.contains('treatment') ||
        id.contains('water_change') || id.contains('environmental')) {
      return Colors.blue;
    }
    if (id.contains('spawn') || id.contains('cross') ||
        id.contains('settle') || id.contains('reproductive')) {
      return Colors.pink;
    }
    if (id.contains('size') || id.contains('growth')) return Colors.teal;
    if (id.contains('transfer') || id.contains('move')) return Colors.purple;
    if (id.contains('split') || id.contains('merge')) return Colors.indigo;
    if (id.contains('create')) return Colors.green;
    if (id.contains('outplant')) return Colors.cyan;
    if (id.contains('gene_bank') || id.contains('viability') ||
        id.contains('cryopreservation')) {
      return Colors.deepPurple;
    }
    if (id.contains('status') || id.contains('life_stage')) return Colors.amber;
    if (id.contains('training')) return Colors.brown;
    return Colors.blueGrey;
  }

  IconData _getEventIcon(Event event) {
    final id = event.eventTypeId;
    if (id.contains('population_gain')) return Icons.trending_up;
    if (id.contains('population_loss')) return Icons.trending_down;
    if (id.contains('delete') || id.contains('archive')) return Icons.delete;
    if (id.contains('observation') || id.contains('survey')) {
      return Icons.camera_alt_outlined;
    }
    if (id.contains('task')) return Icons.check_circle_outline;
    if (id.contains('feeding')) return Icons.restaurant;
    if (id.contains('cleaning') || id.contains('water_change')) {
      return Icons.cleaning_services;
    }
    if (id.contains('treatment')) return Icons.medical_services;
    if (id.contains('husbandry') || id.contains('environmental')) {
      return Icons.build;
    }
    if (id.contains('spawn') || id.contains('cross') ||
        id.contains('settle') || id.contains('reproductive')) {
      return Icons.science;
    }
    if (id.contains('size') || id.contains('growth')) return Icons.straighten;
    if (id.contains('transfer') || id.contains('move')) return Icons.swap_horiz;
    if (id.contains('split')) return Icons.call_split;
    if (id.contains('merge')) return Icons.call_merge;
    if (id.contains('create')) return Icons.add_circle_outline;
    if (id.contains('outplant')) return Icons.nature;
    if (id.contains('gene_bank') || id.contains('viability') ||
        id.contains('cryopreservation')) {
      return Icons.ac_unit;
    }
    if (id.contains('status') || id.contains('life_stage')) {
      return Icons.swap_vert;
    }
    if (id.contains('training')) return Icons.school;
    return Icons.event;
  }

  String _getEventTitle(Event event) {
    final eventType = EventType.builtins[event.eventTypeId];
    if (eventType != null) return eventType.name;
    // Fallback: humanize the raw ID
    return event.eventTypeId
        .replaceAll('event_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Extension to add summary method to EventHistory
extension EventHistoryExtension on EventHistory {
  String get summary {
    if (totalEvents == 0) return 'No events recorded';

    final parts = <String>[];
    parts.add('$totalEvents total events');

    if (directEvents > 0) {
      parts.add('$directEvents direct');
    }

    if (propagatedEvents > 0) {
      parts.add('$propagatedEvents propagated');
    }

    return parts.join(', ');
  }
}
