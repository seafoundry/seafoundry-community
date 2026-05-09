// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/merge_event.dart';
import 'package:seafoundry_app/models/events/mortality_event.dart';
import 'package:seafoundry_app/models/events/move_event.dart';
import 'package:seafoundry_app/models/events/move_in_event.dart';
import 'package:seafoundry_app/models/events/move_out_event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/events/population_gain_event.dart';
import 'package:seafoundry_app/models/events/population_loss_event.dart';
import 'package:seafoundry_app/models/events/quantity_change_event.dart';
import 'package:seafoundry_app/models/events/split_event.dart';
import 'package:seafoundry_app/models/events/transfer_event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Event display widget.
///
/// Renders events directly without requiring EventCubit.
class EventDisplay extends StatelessWidget {
  const EventDisplay({
    super.key,
    required this.event,
    this.onTap,
  });

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Error boundary for failed events
    try {
      return _buildEventCard(context);
    } catch (e, stackTrace) {
      LoggingService.instance.error('EventDisplay rendering error', e, stackTrace);
      return _buildFallbackCard();
    }
  }

  Widget _buildEventCard(BuildContext context) {
    final eventType = EventType.builtins[event.eventTypeId] ?? EventType.unknown;
    final icon = _getIcon(event, eventType);
    final color = _getColor(event, eventType);
    final title = _getTitle(event, eventType);
    final timeAgo = _formatTimeAgo(event.createdAtDateTime);
    final detail = _getDetailText(event);

    // Standard compact event card
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          radius: 16,
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail != null)
              Text(
                detail,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              timeAgo,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: onTap != null
            ? Icon(Icons.chevron_right, size: 18, color: Colors.grey[400])
            : null,
      ),
    );
  }

  /// Fallback card for events that fail to render
  Widget _buildFallbackCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEEEEEE),
          radius: 16,
          child: Icon(Icons.event_outlined, color: Colors.grey, size: 18),
        ),
        title: Text(
          event.eventTypeId.replaceAll('event_', '').replaceAll('_', ' '),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          'Unable to load details',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  IconData _getIcon(Event event, EventType eventType) {
    // Check specific event types first
    if (event is ObservationEvent) {
      return Icons.visibility_outlined;
    }

    if (event is MoveEvent) {
      return Icons.swap_horiz;
    }

    if (event is OutplantEvent) {
      return Icons.park_outlined;
    }

    // Generic event type icons
    switch (eventType.id) {
      case 'event_create':
        return Icons.add_circle_outline;
      case 'event_update':
        return Icons.edit_outlined;
      case 'event_delete':
        return Icons.delete_outline;
      case 'event_move_in':
        return Icons.arrow_downward;
      case 'event_move_out':
        return Icons.arrow_upward;
      case 'event_observation':
        return Icons.visibility_outlined;
      case 'event_activity':
        return Icons.local_activity_outlined;
      case 'event_population_gain':
        return Icons.add;
      case 'event_population_loss':
        return Icons.remove;
      case 'event_mortality':
        return Icons.warning_amber_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  Color _getColor(Event event, EventType eventType) {
    // Check specific event types first
    if (event is ObservationEvent) {
      return Colors.blue;
    }

    if (event is MoveEvent) {
      return Colors.indigo;
    }

    if (event is OutplantEvent) {
      return Colors.green;
    }

    // Generic event type colors
    switch (eventType.id) {
      case 'event_create':
        return Colors.green;
      case 'event_update':
        return Colors.blue;
      case 'event_delete':
        return Colors.red;
      case 'event_move_in':
      case 'event_move_out':
        return Colors.indigo;
      case 'event_observation':
        return Colors.blue;
      case 'event_activity':
        return Colors.purple;
      case 'event_population_gain':
        return Colors.lightGreen;
      case 'event_population_loss':
        return Colors.orange;
      case 'event_mortality':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTitle(Event event, EventType eventType) {
    if (eventType.name.isNotEmpty) {
      return eventType.name;
    }

    // Fallback for unknown types
    return event.eventTypeId
        .replaceAll('event_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Extract a short detail string from event-specific data
  String? _getDetailText(Event event) {
    if (event is ObservationEvent) {
      final parts = <String>[];
      if (event.isHealthStatusChange) {
        final oldLabel = event.oldHealthStatus ?? '?';
        final newLabel = event.newHealthStatus ?? '?';
        parts.add('$oldLabel \u2192 $newLabel');
      }
      if (event.comment != null && event.comment!.isNotEmpty) {
        parts.add(event.comment!);
      }
      return parts.isEmpty ? null : parts.join(' \u2014 ');
    }

    if (event is OutplantEvent) {
      final qty = event.totalQuantity;
      final allocs = event.allocations.length;
      final name = event.name;
      if (qty > 0) {
        return '$name: $qty coral${qty != 1 ? 's' : ''} ($allocs allocation${allocs != 1 ? 's' : ''})';
      }
      return name;
    }

    if (event is TransferEvent) {
      final parts = <String>[];
      if (event.status != null) parts.add(event.status!);
      if (event.quantity > 0) parts.add('qty: ${event.quantity}');
      if (event.comment != null && event.comment!.isNotEmpty) {
        parts.add(event.comment!);
      }
      return parts.isEmpty ? null : parts.join(' \u2014 ');
    }

    if (event is MortalityEvent) {
      final delta = event.oldPopulation - event.newPopulation;
      return '-$delta (${event.oldPopulation} \u2192 ${event.newPopulation})';
    }

    if (event is PopulationLossEvent) {
      final delta = event.oldPopulation - event.newPopulation;
      return '-$delta (${event.oldPopulation} \u2192 ${event.newPopulation})';
    }

    if (event is PopulationGainEvent) {
      final delta = event.newPopulation - event.oldPopulation;
      return '+$delta (${event.oldPopulation} \u2192 ${event.newPopulation})';
    }

    if (event is QuantityChangeEvent) {
      final delta = event.delta;
      final sign = delta >= 0 ? '+' : '';
      return '$sign${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 1)}';
    }

    if (event is SplitEvent) {
      final qty = event.splitQuantity;
      return 'Split ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} '
          '(${event.sourceQuantityBefore.toStringAsFixed(0)} \u2192 ${event.sourceQuantityAfter.toStringAsFixed(0)})';
    }

    if (event is MergeEvent) {
      return 'Merged ${event.absorbedCount} record${event.absorbedCount != 1 ? 's' : ''}';
    }

    if (event is MoveInEvent) {
      final count = event.movedCoralIds.length;
      final from = _lastPathSegment(event.fromUrlPath);
      return '$count coral${count != 1 ? 's' : ''} from $from';
    }

    if (event is MoveOutEvent) {
      final count = event.movedCoralIds.length;
      final to = _lastPathSegment(event.toUrlPath);
      return '$count coral${count != 1 ? 's' : ''} to $to';
    }

    return null;
  }

  /// Extract the last meaningful segment from a URL path for display
  static String _lastPathSegment(String urlPath) {
    final segments = urlPath.split('/').where((s) => s.isNotEmpty).toList();
    return segments.length >= 2 ? segments.last : urlPath;
  }

  /// Build detail rows for a bottom sheet display of the event
  static List<MapEntry<String, String>> getDetailRows(Event event) {
    final rows = <MapEntry<String, String>>[];
    final eventType = EventType.builtins[event.eventTypeId] ?? EventType.unknown;
    rows.add(MapEntry('Type', eventType.name.isNotEmpty ? eventType.name : event.eventTypeId));
    rows.add(MapEntry('Date', _formatDateTime(event.createdAtDateTime)));

    if (event is ObservationEvent) {
      if (event.isHealthStatusChange) {
        rows.add(MapEntry('Health', '${event.oldHealthStatus ?? '?'} \u2192 ${event.newHealthStatus ?? '?'}'));
      }
      if (event.comment != null && event.comment!.isNotEmpty) {
        rows.add(MapEntry('Comment', event.comment!));
      }
    } else if (event is OutplantEvent) {
      rows.add(MapEntry('Name', event.name));
      rows.add(MapEntry('Total Quantity', '${event.totalQuantity}'));
      rows.add(MapEntry('Allocations', '${event.allocations.length}'));
      if (event.comment != null && event.comment!.isNotEmpty) {
        rows.add(MapEntry('Comment', event.comment!));
      }
      for (final alloc in event.allocations.take(5)) {
        rows.add(MapEntry('  ${alloc.recordName}', 'qty: ${alloc.quantity}'));
      }
      if (event.allocations.length > 5) {
        rows.add(MapEntry('', '...and ${event.allocations.length - 5} more'));
      }
    } else if (event is TransferEvent) {
      if (event.status != null) rows.add(MapEntry('Status', event.status!));
      if (event.quantity > 0) rows.add(MapEntry('Quantity', '${event.quantity}'));
      if (event.genetId != null) rows.add(MapEntry('Genet ID', event.genetId!));
      if (event.comment != null && event.comment!.isNotEmpty) {
        rows.add(MapEntry('Comment', event.comment!));
      }
    } else if (event is MortalityEvent) {
      rows.add(MapEntry('Population', '${event.oldPopulation} \u2192 ${event.newPopulation}'));
      rows.add(MapEntry('Lost', '${event.oldPopulation - event.newPopulation}'));
      rows.add(MapEntry('Reason', event.mortalityReasonId));
    } else if (event is PopulationLossEvent) {
      rows.add(MapEntry('Population', '${event.oldPopulation} \u2192 ${event.newPopulation}'));
      rows.add(MapEntry('Lost', '${event.oldPopulation - event.newPopulation}'));
      if (event.comment != null && event.comment!.isNotEmpty) {
        rows.add(MapEntry('Comment', event.comment!));
      }
    } else if (event is PopulationGainEvent) {
      rows.add(MapEntry('Population', '${event.oldPopulation} \u2192 ${event.newPopulation}'));
      rows.add(MapEntry('Gained', '${event.newPopulation - event.oldPopulation}'));
      if (event.comment != null && event.comment!.isNotEmpty) {
        rows.add(MapEntry('Comment', event.comment!));
      }
    } else if (event is QuantityChangeEvent) {
      final delta = event.delta;
      final sign = delta >= 0 ? '+' : '';
      rows.add(MapEntry('Change', '$sign${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 1)}'));
      if (event.countDelta != null) {
        rows.add(MapEntry('Count', '${event.oldCount} \u2192 ${event.newCount}'));
      }
    } else if (event is SplitEvent) {
      rows.add(MapEntry('Split Quantity', event.splitQuantity.toStringAsFixed(0)));
      rows.add(MapEntry('Source', '${event.sourceQuantityBefore.toStringAsFixed(0)} \u2192 ${event.sourceQuantityAfter.toStringAsFixed(0)}'));
      if (event.comment != null && event.comment!.isNotEmpty) {
        rows.add(MapEntry('Comment', event.comment!));
      }
    } else if (event is MergeEvent) {
      rows.add(MapEntry('Absorbed', '${event.absorbedCount} record${event.absorbedCount != 1 ? 's' : ''}'));
      rows.add(MapEntry('Quantity', '${event.totalQuantityBefore.toStringAsFixed(0)} \u2192 ${event.totalQuantityAfter.toStringAsFixed(0)}'));
      if (event.comment != null && event.comment!.isNotEmpty) {
        rows.add(MapEntry('Comment', event.comment!));
      }
    } else if (event is MoveInEvent) {
      rows.add(MapEntry('From', _lastPathSegment(event.fromUrlPath)));
      rows.add(MapEntry('Corals', '${event.movedCoralIds.length}'));
      if (event.quantity != null) rows.add(MapEntry('Quantity', '${event.quantity}'));
      if (event.reason != null) rows.add(MapEntry('Reason', event.reason!));
    } else if (event is MoveOutEvent) {
      rows.add(MapEntry('To', _lastPathSegment(event.toUrlPath)));
      rows.add(MapEntry('Corals', '${event.movedCoralIds.length}'));
      if (event.quantity != null) rows.add(MapEntry('Quantity', '${event.quantity}'));
      if (event.reason != null) rows.add(MapEntry('Reason', event.reason!));
    }

    rows.add(MapEntry('Path', event.urlPath));

    return rows;
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeAgo(DateTime dateTime) {
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 365) {
        final n = (difference.inDays / 365).floor();
        return '$n ${n == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        final n = (difference.inDays / 30).floor();
        return '$n ${n == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        final n = difference.inDays;
        return '$n ${n == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        final n = difference.inHours;
        return '$n ${n == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        final n = difference.inMinutes;
        return '$n ${n == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error formatting time ago', e, stackTrace);
      return 'Unknown time';
    }
  }
}
