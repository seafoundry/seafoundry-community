import 'package:flutter_test/flutter_test.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/movement/partial_move_selection.dart';

import '../support/move_computation_fakes.dart';
import '../support/move_plan_graph_fakes.dart';

/// Planner-level MOVE ordering tests (spec §6, U13–U16, U18–U19).
///
/// They drive the real `GraphRepository` move planner (`_buildMovePlan`, via the
/// `@visibleForTesting` `debugBuildMovePlan` seam) over seeded graph nodes and
/// assert the DFS slug counts/order. Building the plan mints EVERY slug OUTSIDE
/// any transaction, so a green run proves the "mint before commit" property.
/// If a slug mint is ever moved back inside the commit transaction, the plan's
/// pre-minted slug lists drop entries and these fail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MoveGraphHarness h;

  setUp(() {
    h = buildMoveGraphHarness();
  });

  SeededOrganizationNode orgNode() => SeededOrganizationNode(
        graphRepository: h.graph,
        recordRepository: h.records,
        initialRecord: buildOrganization(),
      );

  SeededGroupNode seededGroup({
    required String id,
    required String slug,
    required GraphNode parent,
    List<GraphNode> children = const [],
  }) {
    final node = SeededGroupNode(
      graphRepository: h.graph,
      recordRepository: h.records,
      initialRecord: buildDestinationGroup(
        id: id,
        slug: slug,
        urlPath: 'organizations/org1/groups/$slug',
        internalPath: 'organizations/org1/groups/$slug',
      ),
      parent: parent,
    )..seed(children: children);
    return node;
  }

  SeededOrganismNode seededOrganism({
    required String id,
    required GraphNode parent,
    double quantity = 10,
    String slug = 'organismRecord-x',
  }) {
    final node = SeededOrganismNode(
      graphRepository: h.graph,
      recordRepository: h.records,
      initialRecord: buildOrganism(
        id: id,
        slug: slug,
        quantity: quantity,
        urlPath: 'organizations/org1/groups/g1/records/$id',
        internalPath: 'organizations/org1/groups/g1/records/$id',
      ),
      parent: parent,
    )..seed();
    return node;
  }

  test('U13 — full-move leaf mints exactly 2 event slugs, no record slug', () async {
    final parent = seededGroup(id: 'g1', slug: 'g1', parent: orgNode());
    final leaf = seededOrganism(id: 'leaf-1', parent: parent);

    final plan = await h.graph.debugBuildMovePlan(leaf, buildDestinationGroup());

    expect(plan.perNodeSlugs, [
      ['event1', 'event2'],
    ]);
    expect(plan.recordIds, ['leaf-1']);
    // U19 — one guard per moved source, carrying its updatedAt.
    expect(plan.guardUpdatedAt, [leaf.initialRecord.updatedAt]);
  });

  test('U14 — partial-split leaf mints 3 slugs: organism first, then 2 events',
      () async {
    final parent = seededGroup(id: 'g1', slug: 'g1', parent: orgNode());
    final leaf = seededOrganism(id: 'leaf-1', parent: parent, quantity: 10);

    final plan = await h.graph.debugBuildMovePlan(
      leaf,
      buildDestinationGroup(),
      partialSelection: const PartialMoveSelection(
        moveAll: false,
        partialQuantities: {'leaf-1': 4},
      ),
    );

    expect(plan.perNodeSlugs, [
      ['organismRecord1', 'event1', 'event2'],
    ]);
    expect(plan.recordIds, ['leaf-1']);
  });

  test('U15 — parent + 2 children (full move) → 6 event slugs in DFS order',
      () async {
    final movingGroup = seededGroup(id: 'g1', slug: 'g1', parent: orgNode());
    final childA = seededOrganism(id: 'child-a', parent: movingGroup);
    final childB = seededOrganism(id: 'child-b', parent: movingGroup);
    movingGroup.seed(children: [childA, childB]);

    final plan = await h.graph.debugBuildMovePlan(
      movingGroup,
      buildDestinationGroup(),
    );

    // Parent before children; child order preserved; each node = 2 event slugs.
    expect(plan.perNodeSlugs, [
      ['event1', 'event2'], // moving group
      ['event3', 'event4'], // child A
      ['event5', 'event6'], // child B
    ]);
    expect(plan.recordIds, ['g1', 'child-a', 'child-b']);
    expect(plan.guardUpdatedAt.length, 3);
  });

  test('U16 — partial move with forChild prunes unselected children', () async {
    final movingGroup = seededGroup(id: 'g1', slug: 'g1', parent: orgNode());
    final childA = seededOrganism(id: 'child-a', parent: movingGroup, quantity: 8);
    final childB = seededOrganism(id: 'child-b', parent: movingGroup, quantity: 8);
    movingGroup.seed(children: [childA, childB]);

    // Move the whole group but only child-a among its children (full qty).
    final plan = await h.graph.debugBuildMovePlan(
      movingGroup,
      buildDestinationGroup(),
      partialSelection: const PartialMoveSelection(
        moveAll: false,
        selectedChildIds: {'child-a'},
        partialQuantities: {'g1': 1, 'child-a': 8},
      ),
    );

    // Group (full — its own qty entry isn't a child split) + child-a only.
    expect(plan.recordIds, ['g1', 'child-a']);
    expect(plan.perNodeSlugs, [
      ['event1', 'event2'],
      ['event3', 'event4'],
    ]);
  });

  test('U18 — planner is deterministic: a second identical plan matches shape',
      () async {
    final parent1 = seededGroup(id: 'g1', slug: 'g1', parent: orgNode());
    final leaf1 = seededOrganism(id: 'leaf-1', parent: parent1);
    final plan1 = await h.graph.debugBuildMovePlan(leaf1, buildDestinationGroup());

    final h2 = buildMoveGraphHarness();
    final parent2 = SeededGroupNode(
      graphRepository: h2.graph,
      recordRepository: h2.records,
      initialRecord: buildDestinationGroup(id: 'g1', slug: 'g1'),
      parent: SeededOrganizationNode(
        graphRepository: h2.graph,
        recordRepository: h2.records,
        initialRecord: buildOrganization(),
      ),
    )..seed();
    final leaf2 = SeededOrganismNode(
      graphRepository: h2.graph,
      recordRepository: h2.records,
      initialRecord: buildOrganism(id: 'leaf-1'),
      parent: parent2,
    )..seed();
    final plan2 =
        await h2.graph.debugBuildMovePlan(leaf2, buildDestinationGroup());

    expect(plan2.perNodeSlugs, plan1.perNodeSlugs);
    expect(plan2.recordIds, plan1.recordIds);
  });
}
