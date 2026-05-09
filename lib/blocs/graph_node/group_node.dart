import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_factory.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';

class GroupNode extends GraphNode<Group> with MovableNode<Group> {
  GroupNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    required super.parent,
  }) : super();

  Group get group => currentRecord;
  GroupType get groupType =>
      group.groupType; // Delegate to Group model's defensive getter

  @override
  Stream<List<GraphNode>> buildDefaultChildrenStream() {
    // Stream child groups - with error handling for robustness
    // Add startWith to ensure immediate emission for CombineLatestStream
    final groupsStream = graphRepository
        .streamGroupsForUrlPath(currentUrlPath)
        .doOnError((error, stackTrace) {
          LoggingService.instance.error(
            'Failed to stream groups for ${initialRecord.urlPath}',
            error,
            stackTrace,
          );
        })
        // Return empty list on error to prevent hanging
        .onErrorReturn(const <Group>[])
        .shareReplay(maxSize: 1)
        .startWith(const <Group>[]);

    // Stream child organisms (multi-organism inventory)
    // Add startWith to ensure immediate emission for CombineLatestStream
    final organismsStream = graphRepository
        .streamOrganismsForUrlPath(currentUrlPath)
        .doOnError((error, stackTrace) {
          LoggingService.instance.error(
            'Failed to stream organisms for ${initialRecord.urlPath}',
            error,
            stackTrace,
          );
        })
        // Return empty list on error to prevent hanging
        .onErrorReturn(const <OrganismRecord>[])
        .shareReplay(maxSize: 1)
        .startWith(const <OrganismRecord>[]);

    // Combine both streams to get all children
    return CombineLatestStream.list([groupsStream, organismsStream])
        .shareReplay(maxSize: 1)
        .map((results) {
          final groups = results[0] as List<Group>;
          final organisms = results[1] as List<OrganismRecord>;

          // Deduplicate groups by ID to prevent duplicate nodes
          final uniqueGroups = <String, Group>{};
          for (final group in groups) {
            uniqueGroups.putIfAbsent(group.id, () => group);
          }
          final dedupedGroups = uniqueGroups.values.toList();

          // Deduplicate organisms by ID to prevent duplicate nodes
          final uniqueOrganisms = <String, OrganismRecord>{};
          for (final organism in organisms) {
            uniqueOrganisms.putIfAbsent(organism.id, () => organism);
          }
          final dedupedOrganisms = uniqueOrganisms.values.toList();

          // Debug logging (only in debug mode to avoid log noise in production)
          if (kDebugMode) {
            LoggingService.instance.graphNodeDebug(
              'GroupNode ${initialRecord.name} (${initialRecord.urlPath}) children: '
              '${dedupedGroups.length} groups, ${dedupedOrganisms.length} organisms',
            );
          }

          final children = <GraphNode>[];

          // Add group children
          if (state is GroupLoadedState) {
            final groupNodes = synchronizeGraphNodes<Group>(
              dedupedGroups,
              (state as GroupLoadedState).groupNodes,
              graphRepository,
              parent: this,
              onNodeRemoved: (groupNode) => groupNode.close(),
            );
            children.addAll(groupNodes);
          } else {
            final groupNodes = dedupedGroups
                .map(
                  (group) => GroupNode(
                    graphRepository: graphRepository,
                    recordRepository: recordRepository,
                    initialRecord: group,
                    parent: this,
                  ),
                )
                .toList();
            children.addAll(groupNodes);
          }

          // Add organism children
          if (state is GroupLoadedState) {
            final organismNodes = synchronizeGraphNodes<OrganismRecord>(
              dedupedOrganisms,
              (state as GroupLoadedState).organismNodes,
              graphRepository,
              parent: this,
              onNodeRemoved: (organismNode) => organismNode.close(),
            );
            children.addAll(organismNodes);
          } else {
            final organismNodes = dedupedOrganisms
                .map(
                  (organism) => OrganismNode(
                    graphRepository: graphRepository,
                    recordRepository: recordRepository,
                    initialRecord: organism,
                    parent: this,
                  ),
                )
                .toList();
            children.addAll(organismNodes);
          }

          return children;
        })
        // Emit empty list on error to prevent the node from hanging indefinitely.
        // Must be AFTER .map() to emit correct type (List<GraphNode>).
        .onErrorReturn(<GraphNode>[])
        // Ensure immediate emission for CombineLatestStream - prevents timeout
        // when Firestore is slow or data hasn't loaded yet.
        .startWith(<GraphNode>[])
        .toBroadcastIfNeeded(StreamType.children);
  }

  @override
  GroupLoadedState loadedStateFromData(List<dynamic> data) => GroupLoadedState(
    record: data[DataIndex.record.index],
    children: data[DataIndex.children.index],
    events: data[DataIndex.events.index],
    creator: data[DataIndex.creator.index],
  );
}

class GroupLoadedState extends GraphLoadedState<Group> {
  const GroupLoadedState({
    required super.record,
    required super.children,
    required super.events,
    super.creator,
  });
  Group get group => record;

  List<GroupNode> get groupNodes =>
      children.whereType<GroupNode>().toList(growable: false);

  List<OrganismNode> get organismNodes =>
      children.whereType<OrganismNode>().toList(growable: false);

  GroupType get groupType =>
      group.groupType; // Delegate to Group model's defensive getter

  @override
  List<EventType> get eventTypes => [EventType.moveIn, EventType.moveOut];

  @override
  GroupLoadedState copyWith({
    Group? record,
    List<GraphNode>? children,
    List<Event>? events,
    User? creator,
  }) => GroupLoadedState(
    record: record ?? this.record,
    children: children ?? this.children,
    events: events ?? this.events,
    creator: creator ?? this.creator,
  );
}
