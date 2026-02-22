// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/components/nodes/node_icon.dart';
import 'package:seafoundry_app/cubits/partial_move_selector/partial_move_selector_cubit.dart';
import 'package:seafoundry_app/cubits/partial_move_selector/partial_move_selector_state.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/movement/partial_move_selection.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// Widget for selecting what to move when moving nodes
class PartialMoveSelector extends StatelessWidget {
  const PartialMoveSelector({
    super.key,
    required this.nodeToMove,
    required this.onSelectionChanged,
    this.initialSelection = const PartialMoveSelection(),
  });

  final GraphNode nodeToMove;
  final PartialMoveSelection initialSelection;
  final ValueChanged<PartialMoveSelection> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PartialMoveSelectorCubit(initialSelection: initialSelection),
      child: _PartialMoveSelectorView(
        nodeToMove: nodeToMove,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }
}

/// Internal StatefulWidget for PartialMoveSelector
///
/// **Migration Status**: Remains StatefulWidget (legitimate use case)
///
/// **Why StatefulWidget**:
/// - Manages dynamic map of TextEditingController instances (`_quantityControllers`)
///   that are created/disposed based on coral selections
/// - Requires lifecycle hooks (initState/dispose) for controller management
/// - Uses post-frame callbacks for initial selection emission
/// - StatefulWidget pattern appropriate for managing multiple controllers with
///   dynamic lifecycle (corals can be added/removed from selection)
///
/// **Alternative Considered**: Could migrate to HookWidget if flutter_hooks
/// were available, but current Cubit + StatefulWidget pattern is cleaner for
/// dynamic controller maps
class _PartialMoveSelectorView extends StatefulWidget {
  const _PartialMoveSelectorView({
    required this.nodeToMove,
    required this.onSelectionChanged,
  });

  final GraphNode nodeToMove;
  final ValueChanged<PartialMoveSelection> onSelectionChanged;

  @override
  State<_PartialMoveSelectorView> createState() =>
      _PartialMoveSelectorViewState();
}

class _PartialMoveSelectorViewState extends State<_PartialMoveSelectorView> {
  final Map<String, TextEditingController> _quantityControllers = {};
  final Set<String> _controllerGuards = <String>{};
  bool _initializedDefaults = false;

  @override
  void initState() {
    super.initState();
    if (widget.nodeToMove.state is! GraphLoadedState) {
      widget.nodeToMove.add(const GraphNodeLoadRequested());
    }
    // Emit initial selection to keep behaviour consistent with legacy widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selection = context
          .read<PartialMoveSelectorCubit>()
          .state
          .selection;
      widget.onSelectionChanged(selection);
    });
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateSelection(PartialMoveSelection selection) {
    context.read<PartialMoveSelectorCubit>().updateSelection(selection);
    widget.onSelectionChanged(selection);
  }

  void _ensureDefaultSelection(GraphLoadedState state) {
    if (_initializedDefaults) {
      return;
    }
    _initializedDefaults = true;

    if (widget.nodeToMove is OrganismNode && state.record is OrganismRecord) {
      final selection = context
          .read<PartialMoveSelectorCubit>()
          .state
          .selection;
      if (selection.partialQuantities.isEmpty &&
          selection.selectedChildIds.isEmpty) {
        final organism = state.record as OrganismRecord;
        final quantity = organism.measurement.value.round();
        final defaultSelection = PartialMoveSelection(
          moveAll: true,
          partialQuantities: {organism.id: quantity},
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateSelection(defaultSelection);
        });
      }
    }
  }

  void _sanitizeSelection(
    PartialMoveSelection selection,
    Map<String, int> availableQuantities,
  ) {
    final sanitized = selection.clearEmpty(availableQuantities);
    if (sanitized != selection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSelection(sanitized);
      });
    }
  }

  TextEditingController _getController(String key, String value) {
    final controller = _quantityControllers.putIfAbsent(
      key,
      () => TextEditingController(text: value),
    );
    if (controller.text != value && !_controllerGuards.contains(key)) {
      _controllerGuards.add(key);
      controller.value = controller.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      _controllerGuards.remove(key);
    }
    return controller;
  }

  bool _isGuarded(String key) => _controllerGuards.contains(key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GraphNode, GraphNodeState>(
      bloc: widget.nodeToMove,
      builder: (context, nodeState) {
        if (nodeState is! GraphLoadedState) {
          return const Center(child: CircularProgressIndicator());
        }

        _ensureDefaultSelection(nodeState);

        final children = {
          for (final child in nodeState.children) child.id: child,
        }.values.toList();
        final hasChildren = children.isNotEmpty;
        final isOrganismWithQuantity =
            widget.nodeToMove is OrganismNode &&
            nodeState.record is OrganismRecord &&
            (nodeState.record as OrganismRecord).measurement.value.round() > 1;

        return BlocBuilder<PartialMoveSelectorCubit, PartialMoveSelectorState>(
          builder: (context, selectionState) {
            final selection = selectionState.selection;

            final availableQuantities = <String, int>{
              if (widget.nodeToMove is OrganismNode && nodeState.record is OrganismRecord)
                widget.nodeToMove.id: (nodeState.record as OrganismRecord).measurement.value.round(),
              for (final child in children)
                child.id:
                    child is OrganismNode && child.state is GraphLoadedState<OrganismRecord>
                    ? (child.state as GraphLoadedState<OrganismRecord>).record.measurement.value.round()
                    : 1,
            };

            _sanitizeSelection(selection, availableQuantities);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'What to Move',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: NodeIcon(
                        modelType: widget.nodeToMove.modelType,
                        size: 24,
                      ),
                      title: Text(nodeState.record.name),
                      subtitle: Text(_getNodeSubtitle(nodeState)),
                      dense: true,
                    ),
                  ),
                  if (hasChildren || isOrganismWithQuantity) ...[
                    const SizedBox(height: 16),
                    if (hasChildren)
                      CheckboxListTile(
                        value: selection.moveAll,
                        onChanged: (value) {
                          _updateSelection(
                            selection.copyWith(
                              moveAll: value ?? false,
                              selectedChildIds: value == true
                                  ? {}
                                  : nodeState.children.map((c) => c.id).toSet(),
                            ),
                          );
                        },
                        title: const Text('Move entire node'),
                        subtitle: Text(
                          'Move all ${nodeState.children.length} ${_getChildrenLabel(nodeState)}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    if (isOrganismWithQuantity)
                      _buildOrganismQuantitySelector(
                        nodeState.record as OrganismRecord,
                        selection,
                      ),
                    if (hasChildren && !selection.moveAll) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Select items to move:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: children
                                .map(
                                  (child) =>
                                      _buildChildSelector(child, selection),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrganismQuantitySelector(
    OrganismRecord organism,
    PartialMoveSelection selection,
  ) {
    final id = organism.id;
    final quantity = organism.measurement.value.round();
    final textValue =
        selection.partialQuantities[id]?.toString() ??
        quantity.toString();
    final controller = _getController(id, textValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Quantity to move:'),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                suffix: Text('/ $quantity'),
              ),
              onChanged: (value) {
                if (_isGuarded(id)) return;
                // Add guard to prevent _getController from resetting text during editing
                _controllerGuards.add(id);
                final qty = int.tryParse(value) ?? 0;
                if (qty > 0 && qty <= quantity) {
                  // Valid value - remove guard and update selection
                  _controllerGuards.remove(id);
                  final newQuantities = Map<String, int>.from(
                    selection.partialQuantities,
                  );
                  newQuantities[id] = qty;
                  _updateSelection(
                    selection.copyWith(
                      partialQuantities: newQuantities,
                      moveAll: qty == quantity,
                    ),
                  );
                }
                // Invalid/intermediate values: guard stays to prevent text reset
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector(GraphNode child, PartialMoveSelection selection) {
    return BlocBuilder<GraphNode, GraphNodeState>(
      bloc: child,
      builder: (context, childState) {
        final isSelected = selection.selectedChildIds.contains(child.id);
        final childRecord = childState.record;

        Widget? trailing;
        if (child is OrganismNode &&
            childRecord is OrganismRecord &&
            childRecord.measurement.value.round() > 1 &&
            isSelected) {
          final id = child.id;
          final quantity = childRecord.measurement.value.round();
          final textValue =
              selection.partialQuantities[id]?.toString() ??
              quantity.toString();
          final controller = _getController(id, textValue);

          trailing = SizedBox(
            width: 100,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (value) {
                      if (_isGuarded(id)) return;
                      // Add guard to prevent _getController from resetting text during editing
                      _controllerGuards.add(id);
                      final qty = int.tryParse(value) ?? 0;
                      if (qty > 0 && qty <= quantity) {
                        // Valid value - remove guard and update selection
                        _controllerGuards.remove(id);
                        final newQuantities = Map<String, int>.from(
                          selection.partialQuantities,
                        );
                        newQuantities[id] = qty;
                        _updateSelection(
                          selection.copyWith(partialQuantities: newQuantities),
                        );
                      }
                      // Invalid/intermediate values: guard stays to prevent text reset
                    },
                  ),
                ),
                Text(
                  '/$quantity',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return InkWell(
          onTap: () {
            final newSelection = Set<String>.from(selection.selectedChildIds);
            final newQuantities = Map<String, int>.from(
              selection.partialQuantities,
            );

            if (isSelected) {
              newSelection.remove(child.id);
              newQuantities.remove(child.id);
            } else {
              newSelection.add(child.id);
              if (child is OrganismNode && childRecord is OrganismRecord) {
                newQuantities[child.id] = childRecord.measurement.value.round();
              }
            }

            _updateSelection(
              selection.copyWith(
                selectedChildIds: newSelection,
                partialQuantities: newQuantities,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Checkbox(value: isSelected, onChanged: (_) {}),
                const SizedBox(width: 8),
                NodeIcon(modelType: child.modelType, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        childRecord.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        _getChildSubtitle(child, childState),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        );
      },
    );
  }

  String _getNodeSubtitle(GraphLoadedState state) {
    if (widget.nodeToMove is GroupNode) {
      final group = state.record as Group;
      return '${group.groupType.name} • ${state.children.length} items';
    } else if (widget.nodeToMove is OrganismNode) {
      final organism = state.record as OrganismRecord;
      return 'Quantity: ${organism.measurement.value.round()}';
    }
    return state.record.modelType.name;
  }

  String _getChildrenLabel(GraphLoadedState state) {
    if (state.children.every((c) => c is GroupNode)) {
      return 'structures';
    } else if (state.children.every((c) => c is OrganismNode)) {
      return 'organisms';
    }
    return 'items';
  }

  String _getChildSubtitle(GraphNode child, GraphNodeState childState) {
    final record = childState.record;
    if (child is GroupNode && record is Group) {
      return record.groupType.name;
    } else if (child is OrganismNode && record is OrganismRecord) {
      return 'Qty: ${record.measurement.value.round()}';
    }
    return record.modelType.name;
  }
}
