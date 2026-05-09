import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/graph/graph_factory.dart';
import 'package:seafoundry_app/models/graph/graph_node_streams.dart';
import 'package:seafoundry_app/models/graph/graph_node_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';

/// GraphNode for OrganismRecord - universal five-axis inventory model
///
/// Uses a capability-based action system.
class OrganismNode extends GraphNode<OrganismRecord>
    with MovableNode<OrganismRecord> {
  OrganismNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    required super.parent,
  }) : super();

  OrganismRecord get organism => currentRecord;

  @override
  Stream<List<GraphNode>> buildDefaultChildrenStream() => graphRepository
      .streamOrganismsForUrlPath(currentUrlPath)
      .doOnError((error, stackTrace) {
        LoggingService.instance.error(
          'Failed to stream organisms for ${initialRecord.name} (${initialRecord.urlPath})',
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

        if (state is OrganismLoadedState) {
          return synchronizeGraphNodes<OrganismRecord>(
            dedupedOrganisms,
            (state as OrganismLoadedState).organismNodes,
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
      // Must be AFTER .map() to emit correct type (List<OrganismNode>).
      .onErrorReturn(<OrganismNode>[])
      // Ensure immediate emission for CombineLatestStream - prevents timeout
      // when Firestore is slow or data hasn't loaded yet.
      .startWith(<OrganismNode>[])
      .toBroadcastIfNeeded(StreamType.children);

  @override
  OrganismLoadedState loadedStateFromData(List<dynamic> data) =>
      OrganismLoadedState(
        record: data[DataIndex.record.index],
        children: data[DataIndex.children.index],
        events: data[DataIndex.events.index],
        creator: data[DataIndex.creator.index],
      );
}

class OrganismLoadedState extends GraphLoadedState<OrganismRecord> {
  const OrganismLoadedState({
    required super.record,
    required super.children,
    required super.events,
    super.creator,
  });

  OrganismRecord get organism => record;

  List<OrganismNode> get organismNodes =>
      children.whereType<OrganismNode>().toList();

  @override
  List<EventType> get eventTypes => [
    EventType.moveIn,
    EventType.moveOut,
    InventoryEventType.populationLoss,
    EventType.observation,
    // Size tracking events (all organisms)
    InventoryEventType.sizeChange, // Modern size change event type
    if (organism.sizeSpec.hasSize) CoralSizeEventType.growth,
    if (organism.sizeSpec.hasSize) CoralSizeEventType.tissueLoss,
    if (!organism.sizeSpec.hasSize) CoralSizeEventType.sizeAdded,
  ];

  @override
  OrganismLoadedState copyWith({
    OrganismRecord? record,
    List<GraphNode>? children,
    List<Event>? events,
    User? creator,
  }) => OrganismLoadedState(
    record: record ?? this.record,
    children: children ?? this.children,
    events: events ?? this.events,
    creator: creator ?? this.creator,
  );
}
