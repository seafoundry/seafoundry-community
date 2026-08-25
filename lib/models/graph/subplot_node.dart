import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_community/models/graph/event_type_utils.dart';
import 'package:seafoundry_community/models/graph/graph_factory.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/graph_node_state.dart';
import 'package:seafoundry_community/models/graph/organism_node.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/utils/stream_factory.dart';

/// GraphNode for Subplot - represents a subplot within a zone at an outplanting site.
///
/// Subplots are the second level of subdivision in the site hierarchy:
/// Site -> Zone -> Subplot -> Tag
///
/// Each subplot can have its own GPS location and serves as the organizational
/// unit for individual tagged organisms. Subplots are useful for tracking
/// organisms in a specific micro-location within a larger zone.
class SubplotNode extends GraphNode<Subplot> {
  SubplotNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    required super.parent,
  }) : super();

  Subplot get subplot => currentRecord;

  @override
  Stream<List<GraphNode>> buildDefaultChildrenStream() {
    // Stream child organisms assigned to this subplot
    // Organisms are filtered by their subplotId field
    return graphRepository
        .streamOrganismsForSubplot(subplot)
        .doOnError((error, stackTrace) {
          LoggingService.instance.error(
            'Failed to stream organisms for subplot ${subplot.name} (${subplot.urlPath})',
            error,
            stackTrace,
          );
        })
        // Return empty list on error to prevent hanging
        .onErrorReturn(const <OrganismRecord>[])
        .shareReplay(maxSize: 1)
        .map((organisms) {
          // Deduplicate organisms by ID to prevent duplicate nodes
          final uniqueOrganisms = <String, OrganismRecord>{};
          for (final organism in organisms) {
            uniqueOrganisms.putIfAbsent(organism.id, () => organism);
          }
          final dedupedOrganisms = uniqueOrganisms.values.toList();

          if (state is SubplotLoadedState) {
            return synchronizeGraphNodes<OrganismRecord>(
              dedupedOrganisms,
              (state as SubplotLoadedState).organismNodes,
              graphRepository,
              parent: this,
              onNodeRemoved: (organismNode) => organismNode.close(),
            );
          }
          return dedupedOrganisms
              .map(
                (organism) => OrganismNode(
                  graphRepository: graphRepository,
                  recordRepository: recordRepository,
                  initialRecord: organism,
                  parent: this,
                ),
              )
              .toList();
        })
        // Emit empty list on error to prevent the node from hanging indefinitely.
        // Must be AFTER .map() to emit correct type (List<GraphNode<OrganismRecord>>).
        .onErrorReturn(<GraphNode<OrganismRecord>>[])
        // Ensure immediate emission for CombineLatestStream - prevents timeout
        // when Firestore is slow or data hasn't loaded yet.
        .startWith(<GraphNode<OrganismRecord>>[])
        .toBroadcastIfNeeded(StreamType.children);
  }

  @override
  SubplotLoadedState loadedStateFromData(List<dynamic> data) => SubplotLoadedState(
    record: data[DataIndex.record.index],
    children: data[DataIndex.children.index],
    events: data[DataIndex.events.index],
    creator: data[DataIndex.creator.index],
  );
}

class SubplotLoadedState extends GraphLoadedState<Subplot> {
  const SubplotLoadedState({
    required super.record,
    required super.children,
    required super.events,
    super.creator,
  });

  Subplot get subplot => record;

  List<OrganismNode> get organismNodes =>
      children.whereType<OrganismNode>().toList(growable: false);

  @override
  List<EventType> get eventTypes => GraphNodeEventTypes.fromEvents(events);

  @override
  SubplotLoadedState copyWith({
    Subplot? record,
    List<GraphNode>? children,
    List<Event>? events,
    User? creator,
  }) => SubplotLoadedState(
    record: record ?? this.record,
    children: children ?? this.children,
    events: events ?? this.events,
    creator: creator ?? this.creator,
  );
}
