// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';

/// Helper utilities for deriving event filter options for graph nodes.
class GraphNodeEventTypes {
  GraphNodeEventTypes._();

  static final List<EventType> _allEventTypes =
      List<EventType>.unmodifiable(EventType.builtins.values);

  /// Returns a stable, deduplicated list of [EventType] instances that should
  /// be exposed by a node. When no events exist we surface the entire catalog
  /// so filters remain available even for empty feeds.
  static List<EventType> fromEvents(List<Event> events) {
    if (events.isEmpty) {
      return _allEventTypes;
    }

    final seenTypeIds = <String>{};
    final resolved = <EventType>[];

    for (final event in events) {
      final resolvedType =
          EventType.builtins[event.eventTypeId] ?? EventType.unknown;
      if (seenTypeIds.add(resolvedType.id)) {
        resolved.add(resolvedType);
      }
    }

    return List<EventType>.unmodifiable(resolved);
  }
}
