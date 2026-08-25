import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_community/models/graph/event_type_utils.dart';
import 'package:seafoundry_community/models/graph/graph_factory.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/graph_node_state.dart';
import 'package:seafoundry_community/models/graph/subplot_node.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/utils/stream_factory.dart';

/// GraphNode for Zone - represents a zone within an outplanting site.
///
/// Zones are the first level of subdivision in the site hierarchy:
/// Site -> Zone -> Subplot -> Tag
///
/// Each zone can contain multiple subplots and has its own GPS coordinates
/// and boundary polygon for precise geographic tracking.
class ZoneNode extends GraphNode<Zone> {
  ZoneNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    required super.parent,
  }) : super();

  Zone get zone => currentRecord;

  @override
  Stream<List<GraphNode>> buildDefaultChildrenStream() {
    // Stream child subplots for this zone
    return graphRepository
        .streamSubplotsForZone(zone)
        .doOnError((error, stackTrace) {
          LoggingService.instance.error(
            'Failed to stream subplots for zone ${zone.name} (${zone.urlPath})',
            error,
            stackTrace,
          );
        })
        // Return empty list on error to prevent hanging
        .onErrorReturn(const <Subplot>[])
        .shareReplay(maxSize: 1)
        .map((subplots) {
          // Deduplicate subplots by ID to prevent duplicate nodes
          final uniqueSubplots = <String, Subplot>{};
          for (final subplot in subplots) {
            uniqueSubplots.putIfAbsent(subplot.id, () => subplot);
          }
          final dedupedSubplots = uniqueSubplots.values.toList();

          if (state is ZoneLoadedState) {
            return synchronizeGraphNodes<Subplot>(
              dedupedSubplots,
              (state as ZoneLoadedState).subplotNodes,
              graphRepository,
              parent: this,
              onNodeRemoved: (subplotNode) => subplotNode.close(),
            );
          }
          return dedupedSubplots
              .map(
                (subplot) => SubplotNode(
                  graphRepository: graphRepository,
                  recordRepository: recordRepository,
                  initialRecord: subplot,
                  parent: this,
                ),
              )
              .toList();
        })
        // Emit empty list on error to prevent the node from hanging indefinitely.
        // Must be AFTER .map() to emit correct type (List<GraphNode<Subplot>>).
        .onErrorReturn(<GraphNode<Subplot>>[])
        // Ensure immediate emission for CombineLatestStream - prevents timeout
        // when Firestore is slow or data hasn't loaded yet.
        .startWith(<GraphNode<Subplot>>[])
        .toBroadcastIfNeeded(StreamType.children);
  }

  @override
  ZoneLoadedState loadedStateFromData(List<dynamic> data) => ZoneLoadedState(
    record: data[DataIndex.record.index],
    children: data[DataIndex.children.index],
    events: data[DataIndex.events.index],
    creator: data[DataIndex.creator.index],
  );
}

class ZoneLoadedState extends GraphLoadedState<Zone> {
  const ZoneLoadedState({
    required super.record,
    required super.children,
    required super.events,
    super.creator,
  });

  Zone get zone => record;

  List<SubplotNode> get subplotNodes =>
      children.whereType<SubplotNode>().toList(growable: false);

  @override
  List<EventType> get eventTypes => GraphNodeEventTypes.fromEvents(events);

  @override
  ZoneLoadedState copyWith({
    Zone? record,
    List<GraphNode>? children,
    List<Event>? events,
    User? creator,
  }) => ZoneLoadedState(
    record: record ?? this.record,
    children: children ?? this.children,
    events: events ?? this.events,
    creator: creator ?? this.creator,
  );
}
