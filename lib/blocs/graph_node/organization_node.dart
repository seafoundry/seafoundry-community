import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/blocs/graph_node/event_type_utils.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_factory.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';
import 'package:seafoundry_app/services/species_registry.dart';

class OrganizationNode extends GraphNode<Organization> {
  OrganizationNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
  }) : super();

  Organization get organization => initialRecord;

  @override
  Stream<List<GraphNode>> buildDefaultChildrenStream() => graphRepository
      .streamSites()
      .doOnError((error, stackTrace) {
        LoggingService.instance.error(
          'Failed to stream sites for organization ${organization.name}',
          error,
          stackTrace,
        );
      })
      // Return empty list on error to prevent hanging
      .onErrorReturn(const <Site>[])
      .shareReplay(maxSize: 1)
      .map((sites) {
        // Deduplicate sites by ID to prevent duplicate nodes
        final uniqueSites = <String, Site>{};
        for (final site in sites) {
          uniqueSites.putIfAbsent(site.id, () => site);
        }
        final dedupedSites = uniqueSites.values.toList();

        if (state is OrganizationLoadedState) {
          return synchronizeGraphNodes<Site>(
            dedupedSites,
            (state as OrganizationLoadedState).siteNodes,
            graphRepository,
            parent: this,
            onNodeRemoved: (siteNode) => siteNode.close(),
          );
        }
        return dedupedSites
            .map(
              (site) => SiteNode(
                graphRepository: graphRepository,
                recordRepository: recordRepository,
                initialRecord: site,
                parent: this,
              ),
            )
            .toList();
      })
      // Emit empty list on error to prevent the node from hanging indefinitely.
      // Must be AFTER .map() to emit correct type (List<GraphNode<Site>>, not List<Site>).
      .onErrorReturn(<GraphNode<Site>>[])
      // Ensure immediate emission for CombineLatestStream - prevents timeout
      // when Firestore is slow or data hasn't loaded yet.
      .startWith(<GraphNode<Site>>[])
      .toBroadcastIfNeeded(StreamType.children);

  // Use default buildEventsStream() from GraphNode which calls
  // streamEventsForUrlPath(currentUrlPath). This returns ALL descendant events
  // (sites, groups, organisms) since isDescendantOfPath filters by urlPath prefix.
  // No custom override needed - the complex aggregation was causing timing issues.

  @override
  OrganizationLoadedState loadedStateFromData(List<dynamic> data) =>
      OrganizationLoadedState(
        record: data[DataIndex.record.index],
        children: data[DataIndex.children.index],
        events: data[DataIndex.events.index],
        creator: data[DataIndex.creator.index],
      );
}

class OrganizationLoadedState extends GraphLoadedState<Organization> {
  const OrganizationLoadedState({
    required super.record,
    required super.children,
    required super.events,
    super.creator,
  });
  Organization get organization => record;
  List<SiteNode> get siteNodes {
    final seen = <String>{};
    return children
        .whereType<SiteNode>()
        .where((node) => seen.add(node.id))
        .toList();
  }

  List<Species> get species => organization.speciesIds
      .map((id) => SpeciesRegistry.globalById(id))
      .whereType<Species>()
      .toList();

  List<SiteType> get siteTypes => organization.activities
      .map((id) => SiteType.builtins[id])
      .whereType<SiteType>()
      .toList();

  @override
  List<EventType> get eventTypes => GraphNodeEventTypes.fromEvents(events);

  @override
  OrganizationLoadedState copyWith({
    Organization? record,
    List<GraphNode>? children,
    List<Event>? events,
    User? creator,
  }) => OrganizationLoadedState(
    record: record ?? this.record,
    children: children ?? this.children,
    events: events ?? this.events,
    creator: creator ?? this.creator,
  );
}
