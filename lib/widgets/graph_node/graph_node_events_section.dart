// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/display/event_display.dart';

/// Shared event history section for graph node screens.
///
/// Displays a collapsible "Recent Activity" list using [EventDisplay] cards.
/// Shows the 10 most recent events by default, with a "Show all" option
/// that caps at 50 events for performance. Hidden entirely when events
/// list is empty (follows [GraphNodeSection] pattern).
class GraphNodeEventsSection extends StatefulWidget {
  const GraphNodeEventsSection({super.key, required this.events});

  final List<Event> events;

  @override
  State<GraphNodeEventsSection> createState() =>
      _GraphNodeEventsSectionState();
}

class _GraphNodeEventsSectionState extends State<GraphNodeEventsSection> {
  static const int _previewCount = 10;
  static const int _maxExpandedCount = 50;

  bool _isExpanded = false;
  bool _showAll = false;

  // Cached sorted events — recomputed only when widget.events changes.
  List<Event> _sortedCache = const [];
  List<Event>? _lastEvents;

  List<Event> _getSortedEvents() {
    if (!identical(_lastEvents, widget.events)) {
      _lastEvents = widget.events;
      final list = List<Event>.of(widget.events);
      list.sort((a, b) {
        final dateA =
            DateTime.tryParse(a.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      _sortedCache = list;
    }
    return _sortedCache;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = _getSortedEvents();
    final hasMultiple = sorted.length > 1;
    final displayCount = _showAll
        ? sorted.length.clamp(0, _maxExpandedCount)
        : sorted.length.clamp(0, _previewCount);
    final displayEvents = sorted.take(displayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row — matches GraphNodeSection styling
        if (hasMultiple)
          InkWell(
            onTap: () => setState(() {
              _isExpanded = !_isExpanded;
              if (!_isExpanded) _showAll = false;
            }),
            borderRadius: BorderRadius.circular(Spacing.sm),
            child: _buildHeader(context),
          )
        else
          _buildHeader(context),
        if (_isExpanded || !hasMultiple) ...[
          ...displayEvents.map(
            (event) => EventDisplay(
              key: ValueKey(event.id),
              event: event,
              onTap: () => _showEventDetail(context, event),
            ),
          ),
          if (!_showAll && sorted.length > _previewCount)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              child: TextButton(
                onPressed: () => setState(() => _showAll = true),
                child: Text('Show all (${sorted.length})'),
              ),
            ),
          if (_showAll && sorted.length > _maxExpandedCount)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              child: Text(
                'Showing $_maxExpandedCount of ${sorted.length} events',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _showEventDetail(BuildContext context, Event event) {
    final eventType = EventType.builtins[event.eventTypeId] ?? EventType.unknown;
    final rows = EventDisplay.getDetailRows(event);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Drag handle
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          eventType.name.isNotEmpty
                              ? eventType.name
                              : event.eventTypeId,
                          style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Detail rows
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.sm,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (context2, index2) => SizedBox(height: Spacing.sm),
                    itemBuilder: (context2, index) {
                      final row = rows[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (row.key.isNotEmpty)
                            SizedBox(
                              width: 120,
                              child: Text(
                                row.key,
                                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              row.value,
                              style: Theme.of(sheetContext).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Recent Activity (${widget.events.length})',
              style: titleStyle,
            ),
          ),
          if (widget.events.length > 1)
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.white.withValues(alpha: 0.9),
            ),
        ],
      ),
    );
  }
}
