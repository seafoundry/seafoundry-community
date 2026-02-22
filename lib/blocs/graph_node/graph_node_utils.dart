// @tier: community
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

Map<GroupType, List<GroupNode>> groupsByType(List<GroupNode> groups) {
  Map<GroupType, List<GroupNode>> map = {};
  for (var group in groups) {
    try {
      final groupType = group.groupType;
      map[groupType] = (map[groupType] ?? [])..add(group);
    } catch (e) {
      // Log the error but continue processing other groups
      if (kDebugMode) {
        LoggingService.instance.graphNodeDebug('Error getting groupType for group ${group.initialRecord.name} '
            '(id: ${group.initialRecord.groupTypeId}): $e');
      }
    }
  }
  for (var groupList in map.values) {
    groupList.sort((a, b) => a.groupType.name.compareTo(b.groupType.name));
  }
  return map;
}

Map<String, List<OrganismNode>> organismsBySpecies(List<OrganismNode> organisms) {
  Map<String, List<OrganismNode>> map = {};
  for (var organism in organisms) {
    final speciesId = organism.organism.speciesId ?? 'unknown';
    map[speciesId] = (map[speciesId] ?? [])..add(organism);
  }

  // Sort each species list by name
  for (var organismList in map.values) {
    organismList.sort((a, b) => a.organism.name.compareTo(b.organism.name));
  }

  // Convert map to use Species display names as keys for better UI
  final result = <String, List<OrganismNode>>{};
  for (var entry in map.entries) {
    final species = SpeciesRegistry.globalById(entry.key);
    final displayName = species?.name ?? entry.key;
    result[displayName] = entry.value;
  }

  return result;
}
