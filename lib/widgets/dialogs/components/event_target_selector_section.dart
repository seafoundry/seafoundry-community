// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/widgets/dialogs/components/observation_target_selector.dart';

/// Shared section used by event dialogs to present the observation/target
/// selector. The widget stays thin by delegating state to
/// [ObservationTargetController] and pushing resolved selections back into the
/// [EventFormBloc].
class EventTargetSelectorSection extends StatefulWidget {
  const EventTargetSelectorSection({super.key, required this.bloc});

  final EventFormBloc bloc;

  @override
  State<EventTargetSelectorSection> createState() =>
      _EventTargetSelectorSectionState();
}

class _EventTargetSelectorSectionState
    extends State<EventTargetSelectorSection> {
  ObservationTargetController? _controller;
  GraphNode? _lastRoot;
  bool _selectionSyncScheduled = false;

  @override
  void dispose() {
    _controller?.clear();
    super.dispose();
  }

  void _initController() {
    final root = widget.bloc.targetNode;
    if (root == null) {
      if (_controller != null || _lastRoot != null) {
        _controller?.clear();
        _controller = null;
        _lastRoot = null;
        if (widget.bloc.additionalTargets.isNotEmpty) {
          widget.bloc.add(const EventFormAdditionalTargetsChanged([]));
        }
      }
      return;
    }

    final needsNewController = _controller == null || _lastRoot != root;
    if (needsNewController) {
      _controller?.clear();
      _controller = ObservationTargetController(rootNode: root);
      _lastRoot = root;
      _seedExistingSelections();
      _scheduleSelectionUpdate();
    }
  }

  void _seedExistingSelections() {
    final controller = _controller;
    if (controller == null) return;
    controller.clear();
    if (widget.bloc.additionalTargets.isEmpty) return;
    controller.seedSelection(widget.bloc.additionalTargets);
  }

  void _scheduleSelectionUpdate() {
    if (_selectionSyncScheduled) {
      return;
    }
    _selectionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _selectionSyncScheduled = false;
      final controller = _controller;
      if (controller == null) return;
      final nodes = await controller.resolveTargetNodes();
      if (!mounted) return;
      final extras = nodes
          .where((node) => node != controller.rootNode)
          .toList();
      widget.bloc.add(EventFormAdditionalTargetsChanged(extras));
    });
  }

  void _handleSelectionChanged(List<GraphNode> nodes) {
    final controller = _controller;
    if (controller == null) return;
    final extras = nodes.where((node) => node != controller.rootNode).toList();
    widget.bloc.add(EventFormAdditionalTargetsChanged(extras));
  }

  @override
  Widget build(BuildContext context) {
    _initController();
    final controller = _controller;
    if (controller == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Select a site or structure to target specific sub-structures.',
        ),
      );
    }
    return ObservationTargetSelector(
      controller: controller,
      description: 'Apply to sub-structures',
      selectAllByDefault: widget.bloc.selectAllTargetsByDefault,
      onSelectionChanged: _handleSelectionChanged,
    );
  }
}
