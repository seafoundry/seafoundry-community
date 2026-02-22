// @tier: community
import 'dart:async';

import 'package:flutter/foundation.dart' show protected;
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/blocs/graph_node/event_type_utils.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_factory.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/extensions.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';

class SiteNode extends GraphNode<Site> {
  SiteNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    required super.parent,
  }) : super();

  Site get site => currentRecord;

  /// Returns true if this site is an outplanting site.
  bool get isOutplantingSite => site.siteTypeId == SiteType.outplanting.id;

  /// Override to include outplant events for outplanting sites.
  ///
  /// Outplant events are stored with URL paths at their source (nursery)
  /// location, but reference the destination outplant site via `siteId`.
  /// For outplanting sites, we need to combine both:
  /// 1. Events with URL paths that are descendants of this site (default behavior)
  /// 2. Outplant events that have `siteId` matching this site
  @override
  @protected
  Stream<List<Event>> buildEventsStream() {
    final defaultStream = super.buildEventsStream();

    // Only combine streams for outplanting sites
    if (!isOutplantingSite) {
      return defaultStream;
    }

    LoggingService.instance.trace(
      'SiteNode.buildEventsStream: Building combined stream for outplanting site ${site.name} (${site.id})',
    );

    // Stream outplant events that target this site
    final outplantEventsStream = graphRepository.eventRepository
        // Use an unbounded query here so recent outplants don't get dropped by
        // unordered limits when a site has many outplant events.
        .streamOutplantEvents(siteId: site.id, limit: 0)
        .startWith(const <OutplantEvent>[])
        .toBroadcastIfNeeded(StreamType.events);

    // Combine both streams and deduplicate by event ID
    return Rx.combineLatest2<List<Event>, List<OutplantEvent>, List<Event>>(
      defaultStream,
      outplantEventsStream,
      (urlPathEvents, outplantEvents) {
        // Merge and deduplicate by ID
        final eventMap = <String, Event>{};
        for (final event in urlPathEvents) {
          eventMap[event.id] = event;
        }
        for (final event in outplantEvents) {
          eventMap[event.id] = event;
        }
        final merged = eventMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        LoggingService.instance.trace(
          'SiteNode.buildEventsStream: Merged ${urlPathEvents.length} URL-path events + '
          '${outplantEvents.length} outplant events = ${merged.length} total for ${site.name}',
        );
        return merged;
      },
    ).toBroadcastIfNeeded(StreamType.events);
  }

  @override
  Stream<List<GraphNode>> buildDefaultChildrenStream() {
    // Stream child groups - with error handling for robustness
    final groupsStream = graphRepository
        .streamGroupsForSite(site, shallow: true)
        .doOnError((error, stackTrace) {
          LoggingService.instance.error(
            'Failed to stream groups for site ${site.name} (${site.urlPath})',
            error,
            stackTrace,
          );
        })
        // Return empty list on error to prevent hanging
        .onErrorReturn(const <Group>[])
        .shareReplay(maxSize: 1)
        .startWith(const <Group>[]);

    // Stream child organisms (e.g., outplanted corals directly under site)
    // Use shallow: true to only get direct children, not organisms in nested groups
    final organismsStream = graphRepository
        .streamOrganismsForUrlPath(currentUrlPath)
        .doOnError((error, stackTrace) {
          LoggingService.instance.error(
            'Failed to stream organisms for site ${site.name} (${site.urlPath})',
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

          // Filter organisms to only include direct children (one level below site)
          // This is necessary because streamOrganismsForUrlPath returns all descendants
          final directOrganisms = organisms
              .where((org) => org.urlPath.isChildOfPath(currentUrlPath))
              .toList();

          // Deduplicate groups by ID to prevent duplicate nodes
          final uniqueGroups = <String, Group>{};
          for (final group in groups) {
            uniqueGroups.putIfAbsent(group.id, () => group);
          }
          final dedupedGroups = uniqueGroups.values.toList();

          // Deduplicate organisms by ID to prevent duplicate nodes
          final uniqueOrganisms = <String, OrganismRecord>{};
          for (final organism in directOrganisms) {
            uniqueOrganisms.putIfAbsent(organism.id, () => organism);
          }
          final dedupedOrganisms = uniqueOrganisms.values.toList();

          final children = <GraphNode>[];

          // Add group children
          if (state is SiteLoadedState) {
            final groupNodes = synchronizeGraphNodes<Group>(
              dedupedGroups,
              (state as SiteLoadedState).groupNodes,
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

          // Add organism children (direct children only)
          if (state is SiteLoadedState) {
            final organismNodes = synchronizeGraphNodes<OrganismRecord>(
              dedupedOrganisms,
              (state as SiteLoadedState).organismNodes,
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
  SiteLoadedState loadedStateFromData(List<dynamic> data) => SiteLoadedState(
    record: data[DataIndex.record.index],
    children: data[DataIndex.children.index],
    events: data[DataIndex.events.index],
    creator: data[DataIndex.creator.index],
  );
}

class SiteLoadedState extends GraphLoadedState<Site> {
  const SiteLoadedState({
    required super.record,
    required super.children,
    required super.events,
    super.creator,
  });
  Site get site => record;

  List<GroupNode> get groupNodes =>
      children.whereType<GroupNode>().toList(growable: false);

  List<OrganismNode> get organismNodes =>
      children.whereType<OrganismNode>().toList(growable: false);

  @override
  List<EventType> get eventTypes => GraphNodeEventTypes.fromEvents(events);

  @override
  SiteLoadedState copyWith({
    Site? record,
    List<GraphNode>? children,
    List<Event>? events,
    User? creator,
  }) => SiteLoadedState(
    record: record ?? this.record,
    children: children ?? this.children,
    events: events ?? this.events,
    creator: creator ?? this.creator,
  );
}
