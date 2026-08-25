import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:seafoundry_community/models/events/event.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/records/graph_node_record.dart';
import 'package:seafoundry_community/models/user.dart';
import 'package:seafoundry_community/models/graph/group_node.dart';
import 'package:seafoundry_community/models/graph/organism_node.dart';
import 'package:seafoundry_community/models/graph/organization_node.dart';
import 'package:seafoundry_community/models/group.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';
import 'package:seafoundry_community/repositories/inventory/event_repository.dart';
import 'package:seafoundry_community/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_community/repositories/inventory/group_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_community/repositories/inventory/site_repository.dart';
import 'package:seafoundry_community/repositories/record_repository.dart';
import 'package:seafoundry_community/services/snapshot_service.dart';

import 'move_computation_fakes.dart';

/// A fully-wired [GraphRepository] over one in-memory Firestore, plus the
/// repositories the move planner uses. All slug counters live on the same [db].
class MoveGraphHarness {
  MoveGraphHarness({
    required this.db,
    required this.graph,
    required this.events,
    required this.organisms,
    required this.groups,
    required this.records,
  });

  final FakeFirebaseFirestore db;
  final GraphRepository graph;
  final EventRepository events;
  final OrganismRecordRepository organisms;
  final GroupRepository groups;
  final RecordRepository records;
}

MoveGraphHarness buildMoveGraphHarness() {
  final db = FakeFirebaseFirestore();
  final org = buildOrganization();
  final user = buildUser();
  final events = EventRepository(organization: org, user: user, firestore: db);
  final snapshot = SnapshotService(firestore: db);
  final recordRepository = RecordRepository(db: db);
  final organisms = OrganismRecordRepository(
    organization: org,
    user: user,
    firestore: db,
    eventRepository: events,
    enforceAuth: false,
  );
  final sites = SiteRepository(
    organization: org,
    user: user,
    eventRepository: events,
    snapshotService: snapshot,
    firestore: db,
    enforceAuth: false,
  );
  final groups = GroupRepository(
    organization: org,
    user: user,
    eventRepository: events,
    snapshotService: snapshot,
    firestore: db,
    enforceAuth: false,
  );
  final genets = GenetRepository(
    organization: org,
    user: user,
    eventRepository: events,
    snapshotService: snapshot,
    recordRepository: recordRepository,
    firestore: db,
    enforceAuth: false,
  );
  final graph = GraphRepository(
    eventRepository: events,
    siteRepository: sites,
    groupRepository: groups,
    organismRecordRepository: organisms,
    genetRepository: genets,
    recordRepository: recordRepository,
    firestore: db,
    enableCleanupTimer: false,
  );
  return MoveGraphHarness(
    db: db,
    graph: graph,
    events: events,
    organisms: organisms,
    groups: groups,
    records: recordRepository,
  );
}

GraphNodeStreamBundle<T> _emptyBundle<T extends GraphNodeRecord>() =>
    GraphNodeStreamBundle<T>(
      recordStream: Stream<T?>.empty(),
      childrenStream: Stream<List<GraphNode>>.empty(),
      eventsStream: Stream<List<Event>>.empty(),
      shallowEventsStream: Stream<List<Event>>.empty(),
      creatorStream: Stream<User?>.empty(),
    );

/// Seeded nodes short-circuit real loading: [GraphNode.add] returns immediately
/// for `GraphNodeLoadRequested` once the state is no longer `Initial`, and
/// `awaitLoaded()` fast-paths on a loaded state — so no Firestore stream is ever
/// touched by the planner.
class SeededOrganismNode extends OrganismNode {
  SeededOrganismNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    required super.parent,
  });

  @override
  GraphNodeStreamBundle<OrganismRecord> buildStreamBundle() =>
      _emptyBundle<OrganismRecord>();

  void seed({List<GraphNode> children = const [], List<Event> events = const []}) =>
      emit(OrganismLoadedState(
        record: initialRecord,
        children: children,
        events: events,
      ));
}

class SeededGroupNode extends GroupNode {
  SeededGroupNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
    required super.parent,
  });

  @override
  GraphNodeStreamBundle<Group> buildStreamBundle() => _emptyBundle<Group>();

  void seed({List<GraphNode> children = const [], List<Event> events = const []}) =>
      emit(GroupLoadedState(
        record: initialRecord,
        children: children,
        events: events,
      ));
}

class SeededOrganizationNode extends OrganizationNode {
  SeededOrganizationNode({
    required super.graphRepository,
    required super.recordRepository,
    required super.initialRecord,
  });

  @override
  GraphNodeStreamBundle<Organization> buildStreamBundle() =>
      _emptyBundle<Organization>();
}
