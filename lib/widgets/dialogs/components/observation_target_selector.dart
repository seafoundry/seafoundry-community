// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Controller that manages selection state and resolves target nodes for
/// descendant propagation. All selection widgets share this controller so the
/// dialog has a single source of truth.
class ObservationTargetController {
  ObservationTargetController({required this.rootNode});

  final GraphNode rootNode;
  final Set<GraphNode<Group>> _selectedGroups = {};
  final Set<GraphNode<OrganismRecord>> _selectedOrganisms = {};
  bool get hasSelections =>
      _selectedGroups.isNotEmpty || _selectedOrganisms.isNotEmpty;

  /// Selects or deselects a group node (its descendants are included when the
  /// selection is resolved).
  void toggleGroup(GraphNode<Group> group, bool selected) {
    if (selected) {
      _selectedGroups.add(group);
    } else {
      _selectedGroups.remove(group);
    }
  }

  bool isGroupSelected(GraphNode<Group> group) =>
      _selectedGroups.contains(group);

  bool isOrganismSelected(GraphNode<OrganismRecord> organism) =>
      _selectedOrganisms.contains(organism);

  /// Selects or deselects an individual organism within the visible tree.
  void toggleOrganism(GraphNode<OrganismRecord> organism, bool selected) {
    if (selected) {
      _selectedOrganisms.add(organism);
    } else {
      _selectedOrganisms.remove(organism);
    }
  }

  /// Seeds the controller with the existing targets when editing an event.
  void seedSelection(Iterable<GraphNode> nodes) {
    for (final node in nodes) {
      if (node is GraphNode<Group>) {
        _selectedGroups.add(node);
      } else if (node is GraphNode<OrganismRecord>) {
        _selectedOrganisms.add(node);
      }
    }
  }

  List<GraphNode<Group>> get selectedGroups =>
      List<GraphNode<Group>>.unmodifiable(_selectedGroups);

  List<GraphNode<OrganismRecord>> get selectedOrganisms =>
      List<GraphNode<OrganismRecord>>.unmodifiable(_selectedOrganisms);

  /// Selects all provided groups and organisms.
  void selectAll({
    required Iterable<GraphNode<Group>> groups,
    required Iterable<GraphNode<OrganismRecord>> organisms,
  }) {
    _selectedGroups.addAll(groups);
    _selectedOrganisms.addAll(organisms);
  }

  /// Resolves the current selection to concrete graph nodes (ensuring each is
  /// loaded) so the dialog can persist IDs safely. The returned list always
  /// includes [rootNode] so callers can associate the selection with the
  /// structure that launched the dialog.
  Future<List<GraphNode>> resolveTargetNodes() async {
    final results = <GraphNode>{};
    final visitedIds = <String>{};
    await ensureNodeLoaded(rootNode);
    results.add(rootNode);

    for (final group in _selectedGroups) {
      await _collectGroupAndDescendants(group, results, visitedIds);
    }

    for (final organism in _selectedOrganisms) {
      await ensureNodeLoaded(organism);
      results.add(organism);
    }

    return _sortResolvedNodes(results);
  }

  /// Recursively collects a group and any nested groups/corals.
  Future<void> _collectGroupAndDescendants(
    GraphNode<Group> group,
    Set<GraphNode> accumulator,
    Set<String> visitedIds,
  ) async {
    if (!visitedIds.add(group.id)) {
      return;
    }

    await ensureNodeLoaded(group);
    accumulator.add(group);

    final state = group.state;
    if (state is! GroupLoadedState) {
      return;
    }

    final children = await group.getChildren();
    for (final child in children) {
      if (child is GraphNode<Group>) {
        await _collectGroupAndDescendants(child, accumulator, visitedIds);
      } else if (child is GraphNode<OrganismRecord>) {
        await ensureNodeLoaded(child);
        accumulator.add(child);
      }
    }
  }

  /// Ensures a node has emitted its loaded state before we inspect children.
  Future<void> ensureNodeLoaded(GraphNode node) async {
    if (node.isClosed) {
      LoggingService.instance.warning(
        'Attempted to load a closed node at ${node.urlPath}',
      );
      return;
    }
    if (node.state is GraphNodeInitial) {
      node.add(const GraphNodeLoadRequested());
    }
    await node.awaitLoaded();
  }

  List<GraphNode> _sortResolvedNodes(Set<GraphNode> nodes) {
    final list = nodes.toList();
    list.sort((a, b) {
      final aIsRoot = identical(a, rootNode) || a == rootNode;
      final bIsRoot = identical(b, rootNode) || b == rootNode;
      if (aIsRoot && bIsRoot) return 0;
      if (aIsRoot) return -1;
      if (bIsRoot) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Releases any retained selections so GraphNodes aren't held beyond the
  /// dialog lifecycle.
  void clear() {
    _selectedGroups.clear();
    _selectedOrganisms.clear();
  }
}

/// Hierarchical selector used by observation/monitoring dialogs to pick which
/// organisms or structures an event should target. All selection state is kept in
/// the shared [ObservationTargetController] so multiple widgets (summary chips,
/// submit button validations, etc.) can observe the same data.
class ObservationTargetSelector extends StatefulWidget {
  const ObservationTargetSelector({
    super.key,
    required this.controller,
    this.description,
    this.selectAllByDefault = false,
    this.showSelectionActions = true,
    this.onSelectionChanged,
  });

  final ObservationTargetController controller;
  final String? description;
  final bool selectAllByDefault;
  final bool showSelectionActions;
  final ValueChanged<List<GraphNode>>? onSelectionChanged;

  @override
  State<ObservationTargetSelector> createState() =>
      _ObservationTargetSelectorState();
}

class _ObservationTargetSelectorState extends State<ObservationTargetSelector> {
  bool _isLoading = true;
  List<_StructureEntry> _entries = const [];
  List<GraphNode<OrganismRecord>> _rootOrganisms = const [];
  String? _loadError;
  bool _didApplyDefaultSelection = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void didUpdateWidget(covariant ObservationTargetSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _didApplyDefaultSelection = false;
      _loadChildren();
    }
  }

  /// Loads the children under the root node (site or group) so the tree view
  /// can be rendered synchronously once the dialog opens.
  Future<void> _loadChildren() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final node = widget.controller.rootNode;
      await widget.controller.ensureNodeLoaded(node);
      final state = node.state;
      final children = await node.getChildren();

      final entries = <_StructureEntry>[];
      List<GraphNode<OrganismRecord>> rootOrganisms = const [];
      final visitedGroups = <String>{};

      if (state is SiteLoadedState) {
        final groups = _sortedGroups(_groupNodesFrom(children));
        for (final group in groups) {
          entries.add(await _buildEntry(group, visitedGroups));
        }
      } else if (state is GroupLoadedState) {
        rootOrganisms = _sortedOrganisms(_organismNodesFrom(children));
        final groups = _sortedGroups(_groupNodesFrom(children));
        for (final group in groups) {
          entries.add(await _buildEntry(group, visitedGroups));
        }
      } else {
        LoggingService.instance.warning(
          'ObservationTargetSelector expected SiteLoadedState or GroupLoadedState; '
          'received ${state.runtimeType} for ${node.urlPath}.',
        );
      }

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _rootOrganisms = rootOrganisms;
        _isLoading = false;
        _loadError = null;
      });

      _applyDefaultSelectionIfNeeded();
      await _notifySelectionChanged();
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load observation targets',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load targets. Tap to retry.';
      });
    }
  }

  void _applyDefaultSelectionIfNeeded() {
    if (!widget.selectAllByDefault ||
        _didApplyDefaultSelection ||
        widget.controller.hasSelections) {
      return;
    }

    final groups = <GraphNode<Group>>{};
    final organisms = <GraphNode<OrganismRecord>>{};

    void collectEntry(_StructureEntry entry) {
      groups.add(entry.group);
      organisms.addAll(entry.organisms);
      for (final child in entry.children) {
        collectEntry(child);
      }
    }

    for (final entry in _entries) {
      collectEntry(entry);
    }
    organisms.addAll(_rootOrganisms);

    if (groups.isEmpty && organisms.isEmpty) {
      _didApplyDefaultSelection = true;
      return;
    }

    setState(() {
      widget.controller.selectAll(groups: groups, organisms: organisms);
      _didApplyDefaultSelection = true;
    });
  }

  void _handleSelectAll() {
    final groups = <GraphNode<Group>>{};
    final organisms = <GraphNode<OrganismRecord>>{};

    void collectEntry(_StructureEntry entry) {
      groups.add(entry.group);
      organisms.addAll(entry.organisms);
      for (final child in entry.children) {
        collectEntry(child);
      }
    }

    for (final entry in _entries) {
      collectEntry(entry);
    }
    organisms.addAll(_rootOrganisms);

    setState(() {
      widget.controller.selectAll(groups: groups, organisms: organisms);
      _didApplyDefaultSelection = true;
    });
    _notifySelectionChanged();
  }

  void _handleClearAll() {
    setState(() {
      widget.controller.clear();
      _didApplyDefaultSelection = true;
    });
    _notifySelectionChanged();
  }

  Future<_StructureEntry> _buildEntry(
    GraphNode<Group> group,
    Set<String> visitedGroups,
  ) async {
    if (!visitedGroups.add(group.id)) {
      LoggingService.instance.warning(
        'ObservationTargetSelector detected a cycle at group ${group.id}',
      );
      return _StructureEntry(
        group: group,
        organisms: const [],
        children: const [],
      );
    }
    await widget.controller.ensureNodeLoaded(group);
    final state = group.state;
    if (state is! GroupLoadedState) {
      return _StructureEntry(
        group: group,
        organisms: const [],
        children: const [],
      );
    }

    final children = await group.getChildren();
    final childEntries = <_StructureEntry>[];
    for (final childGroup in _sortedGroups(_groupNodesFrom(children))) {
      childEntries.add(await _buildEntry(childGroup, visitedGroups));
    }

    return _StructureEntry(
      group: group,
      organisms: _sortedOrganisms(_organismNodesFrom(children)),
      children: childEntries,
    );
  }

  /// Notifies listeners any time the selection state changes. Consumers are
  /// given the resolved targets (minus the root node) so they can surface
  /// chips/labels without re-implementing the traversal logic.
  Future<void> _notifySelectionChanged() async {
    if (widget.onSelectionChanged == null) return;
    final nodes = await widget.controller.resolveTargetNodes();
    if (!mounted) return;
    final extras = nodes
        .where((node) => node != widget.controller.rootNode)
        .toList();
    widget.onSelectionChanged!(extras);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return _buildErrorState();
    }

    if (_entries.isEmpty && _rootOrganisms.isEmpty) {
      return const Text('No sub-structures or organisms available.');
    }

    final widgets = <Widget>[];
    widgets.add(_buildHeader());

    if (_rootOrganisms.isNotEmpty) {
      widgets.addAll(_rootOrganisms.map((organism) => _buildOrganismTile(organism, 0)));
    }

    for (final entry in _entries) {
      widgets.add(_buildGroupEntry(entry, 0));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Builds either a simple checkbox tile or an expansion tile depending on
  /// whether the group has nested structures/organisms.
  Widget _buildGroupEntry(_StructureEntry entry, int depth) {
    final groupName = _nodeName(entry.group);
    final subtitle = _groupSubtitle(entry.group);
    final hasChildren = entry.children.isNotEmpty || entry.organisms.isNotEmpty;
    final checkbox = Checkbox(
      value: widget.controller.isGroupSelected(entry.group),
      onChanged: (value) {
        setState(() {
          widget.controller.toggleGroup(entry.group, value ?? false);
        });
        _notifySelectionChanged();
      },
    );

    if (!hasChildren) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: checkbox,
          title: Text(groupName),
          subtitle: subtitle != null ? Text(subtitle) : null,
          onTap: () {
            final isSelected = widget.controller.isGroupSelected(entry.group);
            setState(() {
              widget.controller.toggleGroup(entry.group, !isSelected);
            });
            _notifySelectionChanged();
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: ExpansionTile(
        key: PageStorageKey(entry.group.id),
        tilePadding: EdgeInsets.zero,
        leading: checkbox,
        title: Text(groupName),
        subtitle: subtitle != null ? Text(subtitle) : null,
        childrenPadding: const EdgeInsets.only(left: 16),
        children: [
          ...entry.organisms.map((organism) => _buildOrganismTile(organism, depth + 1)),
          ...entry.children.map((child) => _buildGroupEntry(child, depth + 1)),
        ],
      ),
    );
  }

  /// Checkbox row for a single organism.
  Widget _buildOrganismTile(GraphNode<OrganismRecord> organism, int depth) {
    final name = _nodeName(organism);
    final subtitle = _organismSubtitle(organism);
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(name),
        subtitle: subtitle != null ? Text(subtitle) : null,
        value: widget.controller.isOrganismSelected(organism),
        onChanged: (value) {
          setState(() {
            widget.controller.toggleOrganism(organism, value ?? false);
          });
          _notifySelectionChanged();
        },
      ),
    );
  }

  String _nodeName(GraphNode node) {
    final currentState = node.state;
    if (currentState is GraphLoadedState) {
      return currentState.record.name;
    }
    return node.initialRecord.name;
  }

  OrganismRecord? _resolveOrganismRecord(GraphNode<OrganismRecord> organism) {
    final state = organism.state;
    if (state is GraphLoadedState<OrganismRecord>) {
      return state.record;
    }
    final record = organism.initialRecord;
    return record;
  }

  String? _organismSubtitle(GraphNode<OrganismRecord> organism) {
    final record = _resolveOrganismRecord(organism);
    if (record != null) {
      return record.speciesId;
    }
    final initial = organism.initialRecord;
    return initial.speciesId;
  }

  Group? _resolveGroupRecord(GraphNode<Group> group) {
    final state = group.state;
    if (state is GraphLoadedState<Group>) {
      return state.record;
    }
    return group.initialRecord;
  }

  String? _groupSubtitle(GraphNode<Group> group) {
    final record = _resolveGroupRecord(group);
    if (record == null) {
      return null;
    }
    final type = GroupType.builtins[record.groupTypeId];
    return type?.name;
  }

  List<GraphNode<Group>> _sortedGroups(Iterable<GraphNode<Group>> groups) {
    final list = groups.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<GraphNode<OrganismRecord>> _sortedOrganisms(Iterable<GraphNode<OrganismRecord>> organisms) {
    final list = organisms.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Iterable<GraphNode<Group>> _groupNodesFrom(Iterable<GraphNode> nodes) =>
      nodes.whereType<GraphNode<Group>>();

  Iterable<GraphNode<OrganismRecord>> _organismNodesFrom(Iterable<GraphNode> nodes) =>
      nodes.whereType<GraphNode<OrganismRecord>>();

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.description ??
                  'Apply this observation to specific sub-structures:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (widget.showSelectionActions) ...[
            TextButton(
              onPressed: _handleSelectAll,
              child: const Text('Select all'),
            ),
            TextButton(
              onPressed: _handleClearAll,
              child: const Text('Clear all'),
            ),
          ],
          IconButton(
            tooltip: 'Reload targets',
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildren,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        Card(
          color: Colors.orange.shade50,
          child: ListTile(
            title: Text(_loadError ?? 'Failed to load targets'),
            trailing: TextButton(
              onPressed: _loadChildren,
              child: const Text('Retry'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lightweight tree node describing a group + its child groups/organisms.
class _StructureEntry {
  const _StructureEntry({
    required this.group,
    required this.organisms,
    required this.children,
  });

  final GraphNode<Group> group;
  final List<GraphNode<OrganismRecord>> organisms;
  final List<_StructureEntry> children;
}
