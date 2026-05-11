import '../../models/graph/graph_node_streams.dart';
import '../../models/graph/graph_node_state.dart';
import '../../models/graph/organism_node.dart';
import '../../models/inventory/organism_record.dart';
import '../../utils/human_sort.dart';

class OrganismSummary {
  const OrganismSummary({
    required this.recordCount,
    required this.quantityCount,
    required this.organisms,
    required this.isPartial,
  });

  final int recordCount;
  final double quantityCount;
  final List<OrganismRecord> organisms;
  final bool isPartial;

  bool get hasOrganisms => recordCount > 0;
}

class LocalIdSummaryEntry {
  const LocalIdSummaryEntry({
    required this.label,
    required this.recordCount,
    required this.quantityCount,
  });

  final String label;
  final int recordCount;
  final double quantityCount;
}

const String unknownLocalIdLabel = 'No local ID';

OrganismSummary summarizeOrganisms(Iterable<GraphNode> nodes) {
  final organisms = <OrganismRecord>[];
  var isPartial = false;

  void visit(GraphNode node) {
    if (node is OrganismNode) {
      organisms.add(node.organism);
      return;
    }

    final state = node.state;
    if (state is GraphLoadedState) {
      for (final child in state.children) {
        visit(child);
      }
    } else {
      isPartial = true;
    }
  }

  for (final node in nodes) {
    visit(node);
  }

  final quantityCount = organisms.fold<double>(
    0,
    (sum, organism) => sum + organism.measurement.value,
  );

  return OrganismSummary(
    recordCount: organisms.length,
    quantityCount: quantityCount,
    organisms: organisms,
    isPartial: isPartial,
  );
}

List<LocalIdSummaryEntry> buildLocalIdBreakdown(
  List<OrganismRecord> organisms,
) {
  if (organisms.isEmpty) return const [];

  final counts = <String, _LocalIdAccumulator>{};
  for (final organism in organisms) {
    final raw = (organism.localGenetId ?? '').trim();
    final label = raw.isEmpty ? unknownLocalIdLabel : raw;
    counts.putIfAbsent(label, _LocalIdAccumulator.new).add(organism);
  }

  final entries = counts.entries
      .map(
        (entry) => LocalIdSummaryEntry(
          label: entry.key,
          recordCount: entry.value.recordCount,
          quantityCount: entry.value.quantityCount,
        ),
      )
      .toList();

  entries.sort((a, b) {
    if (a.label == unknownLocalIdLabel && b.label != unknownLocalIdLabel) {
      return 1;
    }
    if (b.label == unknownLocalIdLabel && a.label != unknownLocalIdLabel) {
      return -1;
    }
    return compareHumanReadable(a.label, b.label);
  });

  return entries;
}

String formatQuantityCount(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

class _LocalIdAccumulator {
  int recordCount = 0;
  double quantityCount = 0;

  void add(OrganismRecord organism) {
    recordCount += 1;
    quantityCount += organism.measurement.value;
  }
}
