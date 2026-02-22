// @tier: community
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/provenance_base.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Visual graph of provenance relationships (sexual crosses, clonal lines,
/// graduations). Uses taxonomy provenance data + metadata parent lists.
class ProvenanceVisualizationWidget extends StatefulWidget {
  const ProvenanceVisualizationWidget({
    super.key,
    required this.organismKind,
    required this.taxonomyService,
    this.speciesId,
    this.focusProvenanceId,
    this.provenanceLoader,
    this.onNodeSelected,
  });

  final OrganismKind organismKind;
  final TaxonomyService taxonomyService;
  final String? speciesId;
  final String? focusProvenanceId;
  final Future<List<ProvenanceBase>> Function()? provenanceLoader;
  final ValueChanged<ProvenanceBase>? onNodeSelected;

  @override
  State<ProvenanceVisualizationWidget> createState() =>
      _ProvenanceVisualizationWidgetState();
}

class _ProvenanceVisualizationWidgetState
    extends State<ProvenanceVisualizationWidget> {
  bool _loading = true;
  String? _error;
  List<_GraphNode> _nodes = const [];
  Map<String, _GraphNode> _lookup = const {};
  bool _focusFound = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProvenanceVisualizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speciesId != oldWidget.speciesId ||
        widget.focusProvenanceId != oldWidget.focusProvenanceId ||
        widget.organismKind != oldWidget.organismKind) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provenanceRecords = await (widget.provenanceLoader?.call() ??
          widget.taxonomyService.listProvenances(
            organismKind: widget.organismKind,
            speciesId: widget.speciesId,
          ));
      if (!mounted) return;
      final result = _buildGraph(provenanceRecords);
      setState(() {
        _nodes = result.nodes;
        _lookup = result.lookup;
        _focusFound = result.focusFound;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  _GraphBuildResult _buildGraph(List<ProvenanceBase> provenances) {
    final filtered = _filterBySpecies(provenances, widget.speciesId);
    final baseIndex = _buildIndex(filtered);
    final focusId = widget.focusProvenanceId?.trim();
    
    // Find the focus node in the graph
    _GraphNode? focusNode;
    if (focusId != null && focusId.isNotEmpty) {
      // Try to find by ID or provenanceID
      focusNode = baseIndex.lookup[focusId];
      // If not found directly, try exact match on display name or other loose match?
      // For now, assume IDs are reliable.
    }

    // Determine the connected component to show
    Set<String> visibleKeys;
    if (focusNode != null) {
      visibleKeys = _collectConnectedKeys(
        focusNode,
        baseIndex.lookup,
        baseIndex.nodesByKey,
      );
    } else {
      // If no focus, or focus not found, show everything? 
      // Or maybe show nothing? Let's show everything for now, or just roots.
      // But for 'view lineage', we usually want a focus. 
      // If the focus was requested but not found, we effectively have an empty lineage for THAT ID.
      // If no focus requested, show all.
      if (focusId != null && focusId.isNotEmpty) {
        visibleKeys = {}; // Requested focus not found
      } else {
        visibleKeys = baseIndex.nodesByKey.keys.toSet();
      }
    }

    final visibleNodes = baseIndex.nodesByKey.values
        .where((node) => visibleKeys.contains(node.key))
        .toList();

    // Assign Depths
    // If we have a focus node, use it as anchor (0).
    // If not, use standard topological sort / root detection.
    if (focusNode != null && visibleKeys.contains(focusNode.key)) {
       _assignRelativeDepths(focusNode, baseIndex.nodesByKey, baseIndex.lookup);
    } else {
      _assignAbsoluteDepths(visibleNodes, baseIndex.nodesByKey, baseIndex.lookup);
    }

    return _GraphBuildResult(
      nodes: visibleNodes..sort((a,b) => (a.relativeDepth ?? 0).compareTo(b.relativeDepth ?? 0)),
      lookup: baseIndex.lookup,
      focusFound: focusNode != null,
    );
  }

  List<ProvenanceBase> _filterBySpecies(
    List<ProvenanceBase> provenances,
    String? speciesId,
  ) {
    final normalized = speciesId?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return provenances;
    }
    return provenances
        .where((record) => record.speciesId.toLowerCase() == normalized)
        .toList(growable: false);
  }

  _GraphIndex _buildIndex(List<ProvenanceBase> provenances) {
    final nodesByKey = <String, _GraphNode>{};
    final lookup = <String, _GraphNode>{};

    for (final record in provenances) {
      final key = record.id;
      final node = _GraphNode(
        key: key,
        provenance: record,
        parents: _parentIds(record),
      );
      nodesByKey[key] = node;
      _registerLookup(lookup, node, key);
      _registerLookup(lookup, node, record.provenanceId);
    }

    // Link children
    for (final node in nodesByKey.values) {
      for (final parentId in node.parents) {
        final parent = lookup[parentId];
        if (parent != null) {
           // We found the parent node. Link it.
           if (!parent.children.contains(node.key)) {
             parent.children.add(node.key);
           }
        }
      }
    }

    return _GraphIndex(nodesByKey: nodesByKey, lookup: lookup);
  }

  void _registerLookup(
    Map<String, _GraphNode> lookup,
    _GraphNode node,
    String? id,
  ) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) return;
    lookup[normalized] = node;
  }

  Set<String> _collectConnectedKeys(
    _GraphNode focusNode,
    Map<String, _GraphNode> lookup,
    Map<String, _GraphNode> nodesByKey,
  ) {
    final visited = <String>{};
    final queue = Queue<_GraphNode>()..add(focusNode);

    // BFS both directions
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!visited.add(current.key)) continue;

      // Up to parents
      for (final parentId in current.parents) {
        final parent = lookup[parentId];
        if (parent != null) {
          queue.add(parent);
        }
      }
      
      // Down to children
      for (final childId in current.children) {
        final child = nodesByKey[childId] ?? lookup[childId];
        if (child != null) {
          queue.add(child);
        }
      }
    }
    return visited;
  }

  void _assignRelativeDepths(
    _GraphNode focusNode, 
    Map<String, _GraphNode> nodesByKey,
     Map<String, _GraphNode> lookup,
  ) {
    // Phase 1: Reset depths
    for (var node in nodesByKey.values) {
      node.relativeDepth = null;
    }
    
    focusNode.relativeDepth = 0;
    
    // Phase 2: BFS Upwards (Parents)
    final upQueue = Queue<_GraphNode>()..add(focusNode);
    final upVisited = <String>{focusNode.key}; // prevent cycles
    
    while(upQueue.isNotEmpty){
      final current = upQueue.removeFirst();
      if(current.relativeDepth == null) continue; // Should not happen 
      
      for(final parentId in current.parents){
         final parent = lookup[parentId];
         if(parent != null && !upVisited.contains(parent.key)){
           parent.relativeDepth = current.relativeDepth! - 1;
           upVisited.add(parent.key);
           upQueue.add(parent);
         }
      }
    }
    
    // Phase 3: BFS Downwards (Children)
    // Note: We might have multiple paths to a child.
    // If we process top-down from the "highest" found ancestors, we get "absolute" depths.
    // But here we want "generation relative to focus".
    // A child is always +1 from its parent.
    // We can start BFS from the focus node downwards.
    
    final downQueue = Queue<_GraphNode>()..add(focusNode);
    final downVisited = <String>{focusNode.key};
    
    while(downQueue.isNotEmpty){
      final current = downQueue.removeFirst();
      if(current.relativeDepth == null) continue;
      
      for(final childKey in current.children){
        final child = nodesByKey[childKey];
        if(child != null && !downVisited.contains(child.key)){
          child.relativeDepth = current.relativeDepth! + 1;
          downVisited.add(child.key);
          downQueue.add(child);
        }
      }
    }
    
    // Any remaining nodes (e.g. siblings' other parents) ?
    // If the graph is connected, they should have been reached via parents/children links if we did full traversal.
    // But the above unidirectional passes might miss "Cousins" if we don't traverse "up then down".
    // A broader generic traversal is better:
    // If node A has depth D, then:
    //   - All parents have D - 1
    //   - All children have D + 1
    // Keep iterating until stable? Or just BFS flood fill with these rules.
    
    // Let's refine: Flood fill style.
    final queue = Queue<_GraphNode>()..add(focusNode);
    final visited = <String>{focusNode.key};
    
    // Re-initialize with just focus
    for (var node in nodesByKey.values) {
      node.relativeDepth = null;
    }
    focusNode.relativeDepth = 0;
    
    while(queue.isNotEmpty){
        final current = queue.removeFirst();
        final currentDepth = current.relativeDepth!;
        
        // Propagate to parents (depth - 1)
        for(final parentId in current.parents){
           final parent = lookup[parentId];
           if(parent != null && !visited.contains(parent.key)){
             parent.relativeDepth = currentDepth - 1;
             visited.add(parent.key);
             queue.add(parent);
           }
        }
        
        // Propagate to children (depth + 1)
        for(final childKey in current.children){
           final child = nodesByKey[childKey];
           if(child != null && !visited.contains(child.key)){
             child.relativeDepth = currentDepth + 1;
             visited.add(child.key);
             queue.add(child);
           }
        }
    }
  }
  
  void _assignAbsoluteDepths(
    List<_GraphNode> nodes,
    Map<String, _GraphNode> nodesByKey,
    Map<String, _GraphNode> lookup
  ) {
    // Fallback for when no focus node is selected
    // Find absolute roots (no parents in set) and assign 0
     for (final node in nodes) {
      node.relativeDepth = 0;
    }
    // ... Simplified, just leaving them at 0 or implementing standard topo-sort if needed.
    // For this specific UI, usually we have a focus. 
  }

  List<String> _parentIds(ProvenanceBase base) {
    final ids = <String>{};
    if (base.parentProvenanceId != null &&
        base.parentProvenanceId!.isNotEmpty) {
      ids.add(base.parentProvenanceId!);
    }
    final metadata = base.metadata;
    void add(dynamic value) {
      if (value is String && value.isNotEmpty) {
        ids.add(value);
      }
    }

    void addList(dynamic list) {
      if (list is Iterable) {
        for (final entry in list) {
          add(entry);
        }
      }
    }

    addList(metadata['parentProvenanceIds']);
    addList(metadata['parentIds']);
    addList(metadata['parentGenetIds']);
    addList(metadata['parentLineageIds']);
    addList(metadata['sireProvenanceIds']);
    addList(metadata['damProvenanceIds']);
    addList(metadata['sourceBatchIds']);
    add(metadata['parentProvenanceId']);
    add(metadata['parentLineageId']);
    add(metadata['parentGenetId']);
    return ids.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Failed to load provenance: $_error'));
    }

    final filtered = _nodes.where((node) {
      if (_search.isEmpty) return true;
      final query = _search.toLowerCase();
      return node.provenance.displayName.toLowerCase().contains(query) ||
          node.provenance.aliasLabels.any(
            (alias) => alias.toLowerCase().contains(query),
          );
    }).toList();
    
    // Group by relative depth
    final grouped = filtered.groupListsBy((node) => node.relativeDepth ?? 0);
    // Sort generations: negative (ancestors) -> positive (descendants)
    final sortedDepths = grouped.keys.toList()..sort();
    
    final focusId = widget.focusProvenanceId?.trim();
    String emptyMessage;
    if (_search.isNotEmpty) {
      emptyMessage = 'No matching provenance records.';
    } else if (!_focusFound && focusId != null && focusId.isNotEmpty) {
      emptyMessage = 'No lineage data available for this record ($focusId).';
    } else {
      emptyMessage = 'No provenance records found.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search relationships...',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UI.borderRadiusMd),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) => setState(() => _search = value.trim()),
        ),
        const SizedBox(height: Spacing.md),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(emptyMessage, style: const TextStyle(color: AppColors.textSecondary)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: sortedDepths.map((depth) {
                      final nodes = grouped[depth]!;
                      
                      String label;
                      Color? labelColor;
                      
                      if (depth == 0) {
                        label = "Subject (Generation 1)";
                        labelColor = AppColors.primary;
                      } else if (depth < 0) {
                        label = "Ancestors (G$depth)"; 
                        // e.g. G-1 (Parents), G-2 (Grandparents)
                        if (depth == -1) label = "Parents";
                        if (depth == -2) label = "Grandparents";
                        labelColor = AppColors.textSecondary;
                      } else {
                        label = "Descendants (G+$depth)";
                         if (depth == 1) label = "Offspring";
                         if (depth == 2) label = "Grandchildren";
                         labelColor = AppColors.textSecondary;
                      }

                      return Column(
                        children: [
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: Row(
                               children: [
                                 Expanded(child: Divider(color: AppColors.divider)),
                                 Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                   child: Text(
                                     label.toUpperCase(),
                                     style: TextStyle(
                                       fontSize: 12,
                                       fontWeight: FontWeight.bold,
                                       letterSpacing: 1.0,
                                       color: labelColor,
                                     ),
                                   ),
                                 ),
                                 Expanded(child: Divider(color: AppColors.divider)),
                               ],
                             ),
                           ),
                           Wrap(
                             spacing: 16,
                             runSpacing: 16,
                             alignment: WrapAlignment.center,
                             children: nodes.map((node) {
                               final isFocus = node.relativeDepth == 0;
                               return _ProvenanceCard(
                                 node: node,
                                 isFocused: isFocus, // Or explicitly matches focusId
                                 lookup: _lookup,
                                 onTap: widget.onNodeSelected,
                               );
                             }).toList(),
                           ),
                           const SizedBox(height: 32),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProvenanceCard extends StatelessWidget {
  const _ProvenanceCard({
    required this.node,
    required this.isFocused,
    required this.lookup,
    this.onTap,
  });

  final _GraphNode node;
  final bool isFocused;
  final Map<String, _GraphNode> lookup;
  final ValueChanged<ProvenanceBase>? onTap;

  @override
  Widget build(BuildContext context) {
    final provenance = node.provenance;
    final parentNames = node.parents
        .map((id) => lookup[id]?.provenance.displayName ?? id)
        .toList();

    return InkWell(
      onTap: onTap != null ? () => onTap!(provenance) : null,
      borderRadius: BorderRadius.circular(UI.borderRadiusLg),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: isFocused ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(UI.borderRadiusLg),
          border: Border.all(
            color: isFocused ? AppColors.primary : AppColors.divider, 
            width: isFocused ? 2 : 1
          ),
          boxShadow: isFocused 
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFocused ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schema, // Lineage icon
                    size: 20,
                    color: isFocused ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provenance.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        provenance.provenanceKind.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (parentNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              
              Text(
                "Via parents:",
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: parentNames.take(3).map((p) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(p, style: const TextStyle(fontSize: 11)),
                  )
                ).toList(),
              )
            ],

            if (provenance.aliasLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: provenance.aliasLabels.take(2).map((a) => 
                   Text("#$a", style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _GraphNode {
  _GraphNode({
    required this.key,
    required this.provenance,
    required this.parents,
  });

  final String key;
  final ProvenanceBase provenance;
  final List<String> parents;
  final List<String> children = [];
  int? relativeDepth; // 0 is focus, -1 is parent, +1 is child, etc.

  bool matches(String id) {
    if (key == id) return true;
     // Add whitespace/case tolerance
    if (key.trim() == id.trim()) return true;
    if (provenance.id == id) return true;
    final provenanceId = provenance.provenanceId?.trim();
    return provenanceId != null && provenanceId.isNotEmpty && provenanceId == id;
  }
}

class _GraphIndex {
  _GraphIndex({required this.nodesByKey, required this.lookup});

  final Map<String, _GraphNode> nodesByKey;
  final Map<String, _GraphNode> lookup;
}

class _GraphBuildResult {
  const _GraphBuildResult({
    required this.nodes,
    required this.lookup,
    required this.focusFound,
  });

  final List<_GraphNode> nodes;
  final Map<String, _GraphNode> lookup;
  final bool focusFound;
}
