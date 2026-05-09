import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/graph/graph_node_streams.dart';
import 'package:seafoundry_app/models/graph/graph_node_events.dart';
import 'package:seafoundry_app/models/graph/graph_node_state.dart';
import 'package:seafoundry_app/models/graph/group_node.dart';
import 'package:seafoundry_app/models/graph/organism_node.dart';
import 'package:seafoundry_app/models/graph/site_node.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/cubits/record_display_preferences/record_display_preferences_cubit.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/graph_node_safe_wrapper.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import '../../widgets/common/organism_reference_links.dart';
import '../../widgets/common/species_reference_photo.dart';
import '../../widgets/graph_node/organism_summary_helpers.dart';
import '../../widgets/optimized/optimized_network_image.dart';

abstract class GraphNodeChildCard<T extends GraphNode> extends StatelessWidget {
  const GraphNodeChildCard({super.key, required this.node});

  static GraphNodeChildCard fromNode(GraphNode node) {
    switch (node.modelType) {
      case ModelType.site:
        return GraphNodeSiteCard(node: node as SiteNode);
      case ModelType.group:
        return GraphNodeGroupCard(node: node as GroupNode);
      case ModelType.organismRecord:
        return GraphNodeOrganismCard(node: node as OrganismNode);
      default:
        throw StateError('Invalid model type: ${node.modelType}');
    }
  }

  final T node;

  String get subtitle;

  @override
  Widget build(BuildContext context) {
    return GraphNodeSafeWrapper<T>(
      node: node,
      builder: (context, state) {
        String tagId = 'Unknown';
        Widget? recordNameWidget;
        String subtitleText = 'Unknown';

        try {
          final record = state.record;
          if (record is OrganismRecord) {
            recordNameWidget = OrganismReferenceLinks(
              tagId: record.tagId,
              localGenetId: record.localGenetId,
              urlPath: record.urlPath,
              genetRecordId: record.genetRecordId,
              showUnderline: true,
            );
            tagId = record.tagId.isNotEmpty
                ? record.tagId
                : record.name;
          } else {
            tagId = record.name;
          }
        } catch (e) {
          if (kDebugMode) {
            LoggingService.instance.debug('Error getting record name', e);
          }
        }

        try {
          subtitleText = subtitle;
        } catch (e) {
          if (kDebugMode) {
            LoggingService.instance.debug('Error getting subtitle', e);
          }
        }

        // HitTestBehavior.opaque ensures taps register on entire card bounds,
        // not just child content (e.g., text/icons).
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _navigateTo(context, node),
          child: Container(
            margin: EdgeInsets.only(bottom: Spacing.sm),
            padding: EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.folder, size: 32, color: Colors.grey),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      recordNameWidget ??
                          Text(
                            tagId,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                      SizedBox(height: 4),
                      Text(
                        subtitleText,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
      closedWidget: const SizedBox.shrink(), // Hide the card if node is closed
    );
  }

  void _navigateTo(BuildContext context, GraphNode node) {
    context.read<NavigationCubit>().navigateTo(node);
  }

  Widget buildTrailing(BuildContext context, GraphNodeState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [...childCount(state), const Icon(Icons.chevron_right)],
    );
  }

  List<Widget> childCount(GraphNodeState state) {
    if (state is! GraphLoadedState) {
      return [CircularProgressIndicator.adaptive()];
    }
    if (state.children.isEmpty) {
      return [
        UIText.caption('${state.children.length}'),
        SizedBox(width: Spacing.xs),
        Icon(
          Icons.subdirectory_arrow_right,
          size: 16,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: Spacing.sm),
      ];
    }
    return [UIText.caption('${state.children.length}')];
  }
}

class GraphNodeSiteCard extends GraphNodeChildCard<SiteNode> {
  const GraphNodeSiteCard({super.key, required super.node});

  @override
  String get subtitle {
    try {
      return node.initialRecord.siteType.name;
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.debug(
          'Error getting siteType for ${node.initialRecord.name}',
          e,
        );
      }
      return 'Type: ${node.initialRecord.siteTypeId}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GraphNodeSafeWrapper<SiteNode>(
      node: node,
      builder: (context, state) {
        final refreshStream = _buildSummaryRefreshStream(state);
        String tagId = 'Unknown';
        String subtitleText = 'Unknown';

        try {
          tagId = state.record.name;
        } catch (e) {
          if (kDebugMode) {
            LoggingService.instance.debug('Error getting record name', e);
          }
        }

        try {
          subtitleText = subtitle;
        } catch (e) {
          if (kDebugMode) {
            LoggingService.instance.debug('Error getting subtitle', e);
          }
        }
        return StreamBuilder<void>(
          stream: refreshStream,
          builder: (context, snapshot) {
            final summary = summarizeOrganisms([node]);
            if (summary.isPartial) {
              _requestLoadsForSummary(node);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateTo(context, node),
              child: Container(
                margin: EdgeInsets.only(bottom: Spacing.sm),
                padding: EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, size: 32, color: Colors.grey),
                    SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tagId,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (summary.recordCount > 0) ...[
                      _buildSummaryCountChip(
                        icon: Icons.scatter_plot,
                        count: summary.recordCount.toString(),
                        color: Colors.green,
                      ),
                      SizedBox(width: Spacing.xs),
                    ],
                    if (summary.quantityCount > 0) ...[
                      _buildSummaryCountChip(
                        icon: Icons.numbers,
                        count: formatQuantityCount(summary.quantityCount),
                        color: Colors.purple,
                      ),
                      SizedBox(width: Spacing.xs),
                    ],
                    Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
      closedWidget: const SizedBox.shrink(),
    );
  }
}

class GraphNodeGroupCard extends GraphNodeChildCard<GroupNode> {
  const GraphNodeGroupCard({super.key, required super.node});

  @override
  String get subtitle {
    try {
      return node.initialRecord.groupType.name;
    } catch (e) {
      // Log the error and show a fallback
      if (kDebugMode) {
        LoggingService.instance.debug(
          'Error getting groupType for ${node.initialRecord.name}',
          e,
        );
      }
      return 'Type: ${node.initialRecord.groupTypeId}';
    }
  }

  /// Recursively count all organisms in this group and nested groups
  OrganismSummary _summarizeOrganisms(GraphNode node) {
    return summarizeOrganisms([node]);
  }

  @override
  Widget build(BuildContext context) {
    return GraphNodeSafeWrapper<GroupNode>(
      node: node,
      builder: (context, state) {
        final refreshStream = _buildSummaryRefreshStream(state);
        String tagId = 'Unknown';
        String subtitleText = 'Unknown';

        try {
          tagId = state.record.name;
        } catch (e) {
          if (kDebugMode) {
            LoggingService.instance.debug('Error getting record name', e);
          }
        }

        try {
          subtitleText = subtitle;
        } catch (e) {
          if (kDebugMode) {
            LoggingService.instance.debug('Error getting subtitle', e);
          }
        }

        return StreamBuilder<void>(
          stream: refreshStream,
          builder: (context, snapshot) {
            final summary = _summarizeOrganisms(node);
            if (summary.isPartial) {
              _requestLoadsForSummary(node);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateTo(context, node),
              child: Container(
                margin: EdgeInsets.only(bottom: Spacing.sm),
                padding: EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, size: 32, color: Colors.grey),
                    SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tagId,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Show record and quantity counts
                    if (summary.recordCount > 0) ...[
                      _buildSummaryCountChip(
                        icon: Icons.scatter_plot,
                        count: summary.recordCount.toString(),
                        color: Colors.green,
                      ),
                      SizedBox(width: Spacing.xs),
                    ],
                    if (summary.quantityCount > 0) ...[
                      _buildSummaryCountChip(
                        icon: Icons.numbers,
                        count: formatQuantityCount(summary.quantityCount),
                        color: Colors.purple,
                      ),
                      SizedBox(width: Spacing.xs),
                    ],
                    Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
      closedWidget: const SizedBox.shrink(),
    );
  }
}

class GraphNodeOrganismCard extends GraphNodeChildCard<OrganismNode> {
  const GraphNodeOrganismCard({super.key, required super.node});

  @override
  String get subtitle {
    // Show species display name, not raw speciesId
    return Species.fallback(node.organism.speciesId).name;
  }

  /// Override to show organism's record name (primary) with local ID context.
  /// The organism's `name` getter can be legacy-dependent, so we format
  /// tagId/localGenetId explicitly for display.
  String get displayName {
    final organism = node.organism;
    return formatOrganismReferenceLabel(
      localGenetId: organism.localGenetId,
      tagId: organism.tagId,
      fallback: organism.displayLabel,
    );
  }

  /// Get a short genet identifier from the genetRecordId
  /// Returns null if genetRecordId is redundant with displayName (to avoid duplication)
  String? get _genetLabel {
    final genetRecordId = node.organism.genetRecordId;
    if (genetRecordId == null || genetRecordId.isEmpty) return null;

    // Extract a short label from genet ID (e.g., "demo_genet_acer_001" -> "ACER-001")
    String label;
    final parts = genetRecordId.split('_');
    if (parts.length >= 2) {
      label = parts.sublist(parts.length - 2).join('-').toUpperCase();
    } else {
      label = genetRecordId.length > 10
          ? genetRecordId.substring(genetRecordId.length - 8).toUpperCase()
          : genetRecordId.toUpperCase();
    }

    // Don't show genet chip if it's redundant with the display name
    final display = displayName.toUpperCase();
    if (display.contains(label) || label.contains(display.split('-').first)) {
      return null;
    }

    return label;
  }

  /// Get quantity display string
  String? get _quantityLabel {
    final measurement = node.organism.measurement;
    if (measurement.value <= 1) {
      return null; // Don't show for single individuals
    }
    final value = measurement.value;
    final unit = measurement.unit.symbol;
    // Format as integer if whole number
    final valueStr = value == value.toInt()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$valueStr $unit';
  }

  /// Get life stage display label (null if unknown)
  String? get _lifeStageLabel {
    final stage = node.organism.lifeStage.stage;
    if (stage == LifeStage.unknown) return null;
    return stage.displayName;
  }

  /// Get physical form display label
  String? get _physicalFormLabel => node.organism.physicalFormDisplayName;

  /// Get provenance type display label
  String? get _provenanceLabel => node.organism.provenanceDisplayName;

  /// Get health status from metadata
  HealthStatus get _healthStatus => node.organism.healthStatus;

  /// Get health status display label - shows "Unknown" if not set
  String get _healthStatusLabel {
    final status = _healthStatus;
    return status.displayName;
  }

  /// Get health status color based on status
  Color get _healthStatusColor {
    final status = _healthStatus;
    if (status.isHealthy) return Colors.green;
    if (status.isUnhealthy) return Colors.red;
    if (status == HealthStatus.recovering) return Colors.blue;
    if (status == HealthStatus.bleached) return Colors.orange;
    if (status == HealthStatus.damaged) return Colors.deepOrange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return GraphNodeSafeWrapper<OrganismNode>(
      node: node,
      builder: (context, state) {
        final genetLabel = _genetLabel;
        final quantityLabel = _quantityLabel;
        final lifeStageLabel = _lifeStageLabel;
        final physicalFormLabel = _physicalFormLabel;
        final provenanceLabel = _provenanceLabel;
        final isLockedForTransfer = node.organism.isLockedForTransfer;
        final isPendingOutplant = node.organism.isPendingOutplant;
        final organism = node.organism;
        final genetRecordId = GenetIdResolver.resolve(organism);
        final prefs = context.select(
          (RecordDisplayPreferencesCubit cubit) => cubit.state,
        );
        final displayInfo = resolveRecordDisplayInfo(
          showUuid: prefs.showUuid,
          showIdentifier: prefs.showIdentifier,
          recordId: organism.id,
          tagId: organism.tagId,
          localGenetId: organism.localGenetId,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _navigateTo(context, node),
          child: Container(
            margin: EdgeInsets.only(bottom: Spacing.sm),
            padding: EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrganismThumbnail(context, state),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayInfo.isHidden)
                        Text(
                          displayInfo.tagId,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        )
                      else
                        OrganismReferenceLinks(
                          tagId: displayInfo.tagId,
                          localGenetId: displayInfo.localGenetId,
                          urlPath: organism.urlPath,
                          genetRecordId: genetRecordId,
                          showUnderline: true,
                        ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      // Health status + 5-axis info chips
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          // Health status chip (always shown)
                          _buildHealthChip(
                            _healthStatusLabel,
                            _healthStatusColor,
                          ),
                          if (isLockedForTransfer)
                            _buildInfoChip('Pending transfer', Colors.blue),
                          if (isPendingOutplant)
                            _buildInfoChip('Pending outplant', Colors.amber),
                          if (lifeStageLabel != null)
                            _buildInfoChip(lifeStageLabel, Colors.teal),
                          if (physicalFormLabel != null)
                            _buildInfoChip(physicalFormLabel, Colors.orange),
                          if (provenanceLabel != null)
                            _buildInfoChip(provenanceLabel, Colors.indigo),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: Spacing.xs,
                      runSpacing: Spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        if (genetLabel != null)
                          _buildTrailingChip(
                            icon: Icons.account_tree,
                            label: genetLabel,
                            color: Colors.purple,
                          ),
                        if (quantityLabel != null)
                          _buildTrailingChip(
                            icon: Icons.numbers,
                            label: quantityLabel,
                            color: Colors.blue,
                          ),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      closedWidget: const SizedBox.shrink(),
    );
  }

  @override
  Widget buildTrailing(BuildContext context, GraphNodeState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...childCount(state),
        const Icon(Icons.chevron_right),
      ],
    );
  }

  /// Build a compact info chip with colored background
  Widget _buildInfoChip(String label, MaterialColor color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color.shade700,
        ),
      ),
    );
  }

  /// Build a health status chip with icon
  Widget _buildHealthChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 10, color: color),
          SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganismThumbnail(BuildContext context, GraphNodeState state) {
    const size = 36.0;
    const borderRadius = 8.0;
    final fallback = SpeciesReferencePhoto(
      speciesId: node.organism.speciesId,
      modelType: node.modelType,
      size: size,
      borderRadius: borderRadius,
    );
    final imageUrl = _latestObservationImage(state);
    if (imageUrl != null) {
      final devicePixelRatio =
          MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
      final cacheSize = (size * devicePixelRatio).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: OptimizedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          semanticLabel: 'Organism photo',
          errorWidget: fallback,
        ),
      );
    }

    return fallback;
  }

  String? _latestObservationImage(GraphNodeState state) {
    // Observation image gallery removed - community tier
    return null;
  }
}

Widget _buildSummaryCountChip({
  required IconData icon,
  required String count,
  required MaterialColor color,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.shade200),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.shade700),
        SizedBox(width: 4),
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

void _requestLoadsForSummary(GraphNode node) {
  if (node.isClosed) return;
  if (node is OrganismNode) return;

  if (node.state is GraphNodeInitial) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!node.isClosed) {
        node.add(GraphNodeLoadRequested());
      }
    });
    return;
  }

  if (node.state is GraphLoadedState) {
    final state = node.state as GraphLoadedState;
    for (final child in state.children) {
      _requestLoadsForSummary(child);
    }
  }
}

Stream<void> _buildSummaryRefreshStream(GraphNodeState state) {
  if (state is! GraphLoadedState) {
    return const Stream<void>.empty();
  }
  final refreshNodes = _collectDescendants(state.children);
  if (refreshNodes.isEmpty) {
    return const Stream<void>.empty();
  }
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
