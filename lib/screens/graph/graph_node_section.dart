import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/graph_node_events.dart';
import 'package:seafoundry_community/models/graph/graph_node_state.dart';
import 'package:seafoundry_community/models/graph/organism_node.dart';
import 'package:seafoundry_community/screens/graph/graph_node_child_card.dart';
import 'package:seafoundry_community/theme/app_colors.dart';
import 'package:seafoundry_community/theme/spacing.dart';
import '../../widgets/graph_node/organism_summary_helpers.dart';

class GraphNodeSection extends StatefulWidget {
  const GraphNodeSection({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded,
    this.showSummaryCounts = false,
    this.showLocalIdBreakdownToggle = false,
    this.showLocalIdBreakdownGlobal = false,
  });

  final String title;
  final List<GraphNode> children;
  final bool? initiallyExpanded;
  final bool showSummaryCounts;
  final bool showLocalIdBreakdownToggle;
  final bool showLocalIdBreakdownGlobal;

  @override
  State<GraphNodeSection> createState() => _GraphNodeSectionState();
}

class _GraphNodeSectionState extends State<GraphNodeSection> {
  late bool _isExpanded;
  bool _showLocalIdBreakdownLocal = false;

  @override
  void initState() {
    super.initState();
    // Default to collapsed if there are multiple items, unless override is provided
    if (widget.initiallyExpanded != null) {
      _isExpanded = widget.initiallyExpanded!;
    } else {
      _isExpanded = widget.children.length <= 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final refreshStream = _buildRefreshStream(widget.children);
    return StreamBuilder<void>(
      stream: refreshStream,
      builder: (context, snapshot) => _buildSection(context),
    );
  }

  Widget _buildSection(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMultiple = widget.children.length > 1;
    final showSummary = widget.showSummaryCounts ||
        widget.showLocalIdBreakdownToggle ||
        widget.showLocalIdBreakdownGlobal;
    if (showSummary) {
      _requestLoadsForSummary(widget.children);
    }
    final summary = showSummary ? summarizeOrganisms(widget.children) : null;
    final showLocalIdBreakdown =
        (widget.showLocalIdBreakdownGlobal || _showLocalIdBreakdownLocal) &&
            summary != null &&
            summary.hasOrganisms;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );
    final showCounts =
        widget.showSummaryCounts && summary != null && summary.hasOrganisms;
    final summaryChips = showCounts && hasMultiple && !_isExpanded
        ? _buildSummaryChips(summary)
        : const <Widget>[];
    final localIdEntries = showLocalIdBreakdown
        ? buildLocalIdBreakdown(summary.organisms)
        : const <LocalIdSummaryEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMultiple)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(Spacing.sm),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title} (${widget.children.length})',
                      style: titleStyle,
                    ),
                  ),
                  if (summaryChips.isNotEmpty) ...[
                    ...summaryChips,
                    SizedBox(width: Spacing.xs),
                  ],
                  if (widget.showLocalIdBreakdownToggle &&
                      summary != null &&
                      summary.hasOrganisms)
                    Tooltip(
                      message: 'Toggle local ID breakdown',
                      child: Switch.adaptive(
                        value: widget.showLocalIdBreakdownGlobal ||
                            _showLocalIdBreakdownLocal,
                        onChanged: widget.showLocalIdBreakdownGlobal
                            ? null
                            : (value) {
                                setState(() {
                                  _showLocalIdBreakdownLocal = value;
                                });
                              },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(
              left: Spacing.md,
              top: Spacing.sm,
              bottom: Spacing.xs,
            ),
            child: Text(
              widget.title,
              style: titleStyle,
            ),
          ),
        if (localIdEntries.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.xs,
              Spacing.md,
              Spacing.xs,
            ),
            child: Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children:
                  localIdEntries.map(_buildLocalIdChip).toList(growable: false),
            ),
          ),
        if (_isExpanded || !hasMultiple)
          ...widget.children.map(GraphNodeChildCard.fromNode),
      ],
    );
  }

  Stream<void> _buildRefreshStream(List<GraphNode> nodes) {
    if (nodes.isEmpty) {
      return const Stream<void>.empty();
    }
    final refreshNodes = _collectDescendants(nodes);
    final streams = refreshNodes
        .map((node) => node.stream.map((_) => null))
        .toList(growable: false);
    if (streams.isEmpty) {
      return const Stream<void>.empty();
    }
    return MergeStream<void>(streams);
  }

  List<GraphNode> _collectDescendants(List<GraphNode> nodes) {
    final result = <GraphNode>[];
    void visit(GraphNode node) {
      if (node.isClosed) return;
      result.add(node);
      final state = node.state;
      if (state is GraphLoadedState) {
        for (final child in state.children) {
          visit(child);
        }
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    return result;
  }

  void _requestLoadsForSummary(List<GraphNode> nodes) {
    for (final node in nodes) {
      if (node.isClosed) continue;
      if (node is OrganismNode) continue;
      if (node.state is GraphNodeInitial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!node.isClosed) {
            node.add(GraphNodeLoadRequested());
          }
        });
      } else if (node.state is GraphLoadedState) {
        final state = node.state as GraphLoadedState;
        _requestLoadsForSummary(state.children);
      }
    }
  }

  List<Widget> _buildSummaryChips(OrganismSummary summary) {
    final chips = <Widget>[];
    if (summary.recordCount > 0) {
      chips.add(
        _buildCountChip(
          icon: Icons.scatter_plot,
          count: summary.recordCount.toString(),
          color: Colors.green,
        ),
      );
      chips.add(SizedBox(width: Spacing.xs));
    }
    if (summary.quantityCount > 0) {
      chips.add(
        _buildCountChip(
          icon: Icons.numbers,
          count: formatQuantityCount(summary.quantityCount),
          color: Colors.purple,
        ),
      );
    }
    return chips;
  }

  Widget _buildLocalIdChip(LocalIdSummaryEntry entry) {
    final label =
        '${entry.label} · ${entry.recordCount} rec · ${formatQuantityCount(entry.quantityCount)} qty';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildCountChip({
    required IconData icon,
    required String count,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
