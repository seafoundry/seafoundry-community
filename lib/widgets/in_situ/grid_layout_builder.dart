// @tier: community
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/widgets/in_situ/grid_renderer.dart';

@immutable
class InSituStructureSnapshot {
  const InSituStructureSnapshot({required this.group, required this.corals});

  final Group group;
  final List<OrganismRecord> corals;
}

@immutable
class InSituGridLayout {
  const InSituGridLayout({
    required this.rowCount,
    required this.colCount,
    required this.cells,
  });

  final int rowCount;
  final int colCount;
  final Map<InSituGridCoordinate, InSituGridCellSummary> cells;

  bool get isEmpty => cells.values.every((summary) => !summary.hasCorals);
}

InSituGridLayout buildGridLayoutFromSiteState(SiteLoadedState state) {
  final structures = state.groupNodes
      .map(_structureFromNode)
      .whereType<InSituStructureSnapshot>()
      .toList();

  return buildGridLayoutForStructures(site: state.site, structures: structures);
}

@visibleForTesting
InSituGridLayout buildGridLayoutForStructures({
  required Site site,
  required Iterable<InSituStructureSnapshot> structures,
}) {
  final summaries = <InSituGridCoordinate, InSituGridCellSummary>{};
  var maxRow = -1;
  var maxCol = -1;

  for (final snapshot in structures) {
    final rowIndex = snapshot.group.rowIndex;
    final colIndex = snapshot.group.colIndex;
    if (rowIndex == null || colIndex == null) {
      continue;
    }

    maxRow = rowIndex > maxRow ? rowIndex : maxRow;
    maxCol = colIndex > maxCol ? colIndex : maxCol;

    final coordinate = InSituGridCoordinate(
      rowIndex: rowIndex,
      columnIndex: colIndex,
    );

    summaries[coordinate] = InSituGridCellSummary.fromSnapshot(
      coordinate: coordinate,
      structure: snapshot.group,
      corals: snapshot.corals,
    );
  }

  final requestedRows =
      site.rowCount ?? (maxRow >= 0 ? maxRow + 1 : kInSituMinDimension);
  final requestedCols =
      site.colCount ?? (maxCol >= 0 ? maxCol + 1 : kInSituMinDimension);

  final clampedRow = requestedRows
      .clamp(kInSituMinDimension, kInSituMaxRows)
      .toInt();
  final clampedCol = requestedCols
      .clamp(kInSituMinDimension, kInSituMaxColumns)
      .toInt();

  return InSituGridLayout(
    rowCount: clampedRow,
    colCount: clampedCol,
    cells: Map.unmodifiable(summaries),
  );
}

InSituStructureSnapshot? _structureFromNode(GroupNode node) {
  final group = node.state.record;
  if (group.rowIndex == null || group.colIndex == null) {
    return null;
  }

  final groupState = node.state;

  if (groupState is! GroupLoadedState) {
    return InSituStructureSnapshot(group: group, corals: const <OrganismRecord>[]);
  }

  final organisms = groupState.organismNodes
      .whereType<OrganismNode>()
      .map(
        (organismNode) => switch (organismNode.state) {
          GraphLoadedState<OrganismRecord> loadedState => loadedState.record,
          _ => organismNode.initialRecord,
        },
      )
      .toList();

  return InSituStructureSnapshot(group: group, corals: organisms);
}
