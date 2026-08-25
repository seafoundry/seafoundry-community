import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/organism_node.dart';
import 'package:seafoundry_community/models/graph/group_node.dart';
import 'package:seafoundry_community/models/graph/organization_node.dart';
import 'package:seafoundry_community/models/graph/site_node.dart';
import 'package:seafoundry_community/models/graph/subplot_node.dart';
import 'package:seafoundry_community/models/graph/zone_node.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';

/// Factory function to create the appropriate GraphNode subclass
/// based on the GraphNodeRecord's ModelType
GraphNode<T> createNodeForRecord<T extends GraphNodeRecord>(
  T record,
  GraphRepository graphRepositoryProvider,
  GraphNode? parent,
) {
  if (record is OrganismRecord) {
    return OrganismNode(
      graphRepository: graphRepositoryProvider,
      recordRepository: graphRepositoryProvider.recordRepository,
      initialRecord: record,
      parent: parent,
    ) as GraphNode<T>;
  }

  switch (T) {
    case const (Organization):
      return OrganizationNode(
        graphRepository: graphRepositoryProvider,
        recordRepository: graphRepositoryProvider.recordRepository,
        initialRecord: record as Organization,
      ) as GraphNode<T>;
    case const (Site):
      return SiteNode(
        graphRepository: graphRepositoryProvider,
        recordRepository: graphRepositoryProvider.recordRepository,
        initialRecord: record as Site,
        parent: parent,
      ) as GraphNode<T>;
    case const (Group):
      return GroupNode(
        graphRepository: graphRepositoryProvider,
        recordRepository: graphRepositoryProvider.recordRepository,
        initialRecord: record as Group,
        parent: parent,
      ) as GraphNode<T>;
    case const (Zone):
      return ZoneNode(
        graphRepository: graphRepositoryProvider,
        recordRepository: graphRepositoryProvider.recordRepository,
        initialRecord: record as Zone,
        parent: parent,
      ) as GraphNode<T>;
    case const (Subplot):
      return SubplotNode(
        graphRepository: graphRepositoryProvider,
        recordRepository: graphRepositoryProvider.recordRepository,
        initialRecord: record as Subplot,
        parent: parent,
      ) as GraphNode<T>;
    default:
      throw ArgumentError('Unsupported ModelType: ${record.modelType}');
  }
}

/// Synchronizes a list of GraphNode objects with a list of GraphNodeRecord objects.
///
/// This function ensures:
/// 1. Existing nodes are reused (not recreated) when records match by ID
/// 2. New nodes are created for records without existing nodes
/// 3. Nodes without matching records are removed (via onNodeRemoved callback)
/// 4. **Duplicate records are deduplicated** - only the first occurrence is used
List<GraphNode<T>> synchronizeGraphNodes<T extends GraphNodeRecord>(
  List<T> records,
  List<GraphNode<T>> existingNodes,
  GraphRepository graphRepositoryProvider, {
  GraphNode? parent,
  Function(GraphNode<T>)? onNodeAdded,
  Function(GraphNode<T>)? onNodeRemoved,
}) {
  final result = <GraphNode<T>>[];

  // Create a map of existing blocs by their record id and model type for efficient lookup
  final existingNodesMap = {for (var node in existingNodes) node.id: node};

  // Track processed IDs to prevent duplicates in the result
  final processedIds = <String>{};

  // Process each record in the desired list
  for (final record in records) {
    // Skip duplicates - only process first occurrence of each ID
    if (processedIds.contains(record.id)) {
      continue;
    }
    processedIds.add(record.id);

    if (existingNodesMap.containsKey(record.id)) {
      final existingNode = existingNodesMap[record.id]!;
      final existingParent = existingNode.parent;
      final hasParentMismatch = !identical(existingParent, parent);
      final parentKeyMatches =
          existingParent != null &&
          parent != null &&
          existingParent.id == parent.id &&
          existingParent.modelType == parent.modelType;
      final parentClosed = existingParent?.isClosed ?? false;
      final shouldRecreate = existingNode.isClosed ||
          parentClosed ||
          (hasParentMismatch && !parentKeyMatches);
      if (shouldRecreate) {
        // Parent is immutable; recreate when a node is reused under a new parent.
        onNodeRemoved?.call(existingNode);
        final newNode =
            createNodeForRecord(record, graphRepositoryProvider, parent);
        onNodeAdded?.call(newNode);
        result.add(newNode);
      } else {
        // Reuse existing bloc
        result.add(existingNode);
      }
      // Remove from map so we know it's been processed
      existingNodesMap.remove(record.id);
    } else {
      final newNode = createNodeForRecord(record, graphRepositoryProvider, parent);
      if (onNodeAdded != null) {
        onNodeAdded(newNode);
      }
      result.add(newNode);
    }
  }

  if (onNodeRemoved != null) {
    for (final unusedNode in existingNodesMap.values) {
      onNodeRemoved(unusedNode);
    }
  }

  return result;
}
