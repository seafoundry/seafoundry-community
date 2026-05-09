import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/graph_node/site_summary_blueprint.dart';
import 'package:seafoundry_app/widgets/graph_node/site_summary_models.dart';
import 'package:seafoundry_app/widgets/navigation/summary_statistics.dart';

/// Site-specific summary metrics displayed as metric cards.
///
/// Displays inventory metrics based on the site blueprint.
class SiteSummaryCards extends StatefulWidget {
  const SiteSummaryCards({super.key, required this.siteNode});

  final SiteNode siteNode;

  @override
  State<SiteSummaryCards> createState() =>
      _SiteSummaryCardsState();
}

class _SiteSummaryCardsState
    extends State<SiteSummaryCards> {
  // Cache the stream to prevent creating new stream references on every rebuild.
  // CRITICAL: Accessing node.stream in build() can cause infinite rebuilds
  // if GraphNode creates new stream wrappers each time.
  late final Stream<GraphNodeState<Site>> _siteStream;

  @override
  void initState() {
    super.initState();
    _siteStream = widget.siteNode.stream;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GraphNodeState<Site>>(
      stream: _siteStream, // CACHED STREAM - no infinite loop!
      initialData: widget.siteNode.state,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final state = snapshot.data;
        if (state is! SiteLoadedState) {
          return const SizedBox.shrink();
        }

        final capabilities = SiteCapabilities.resolve(state.site.siteType);
        final blueprint = buildSiteSummaryBlueprint(
          state: state,
          capabilities: capabilities,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              blueprint.heading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: Spacing.xs),
            _SupportedOrganismsChips(site: state.site),
            SizedBox(height: Spacing.sm),
            if (blueprint.showOrganismStatistics) ...[
              SummaryStatistics(node: widget.siteNode),
              if (blueprint.metricGroups.isNotEmpty)
                SizedBox(height: Spacing.sm),
            ],
            ...blueprint.metricGroups.map(
              (group) => _buildMetricGroupCard(context, group),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.3,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildMetricGroupCard(
    BuildContext context,
    SiteSummaryMetricGroup group,
  ) {
    final theme = Theme.of(context);
    final isOutplantActivity = group.title.toLowerCase() == 'outplant activity';

    return _buildSectionCard(
      context,
      margin: EdgeInsets.only(bottom: Spacing.sm),
      child: Padding(
        padding: EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: theme.textTheme.titleMedium),
            SizedBox(height: Spacing.sm),
            if (isOutplantActivity)
              _OutplantActivityMetricsGrid(metrics: group.metrics)
            else
              ...group.metrics.map(
                (metric) => Padding(
                  padding: EdgeInsets.only(bottom: Spacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric.label, style: theme.textTheme.bodyMedium),
                      Text(metric.value, style: theme.textTheme.titleSmall),
                      if (metric.helper != null)
                        Text(metric.helper!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SupportedOrganismsChips extends StatelessWidget {
  const _SupportedOrganismsChips({required this.site});

  final Site site;

  @override
  Widget build(BuildContext context) {
    // Community tier: only show coral organisms
    final organisms = site.supportedOrganismKinds
        .where((kind) => kind == OrganismKind.coral)
        .toList();
    if (organisms.isEmpty) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Supported organisms', style: textTheme.bodySmall),
        SizedBox(height: Spacing.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: organisms.map((kind) {
            return Chip(
              label: Text(kind.metadata.displayName),
              avatar: const Icon(Icons.scatter_plot, size: 16),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _OutplantActivityMetricsGrid extends StatelessWidget {
  const _OutplantActivityMetricsGrid({required this.metrics});

  final List<SiteSummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final isWide = maxWidth >= 600;
        final tileWidth = isWide ? (maxWidth - Spacing.sm) / 2 : maxWidth;

        return Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: metrics.map((metric) {
            final icon = _iconForOutplantMetric(metric.label);
            final color = _colorForOutplantMetric(
              Theme.of(context),
              metric.label,
            );
            return SizedBox(
              width: tileWidth,
              child: _OutplantMetricTile(
                metric: metric,
                icon: icon,
                accentColor: color,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _OutplantMetricTile extends StatelessWidget {
  const _OutplantMetricTile({
    required this.metric,
    required this.icon,
    required this.accentColor,
  });

  final SiteSummaryMetric metric;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helper = metric.helper?.trim();
    final helperLines = (helper == null || helper.isEmpty)
        ? const <String>[]
        : helper
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList(growable: false);
    final helperBaseColor =
        theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface;
    final helperColor = helperBaseColor.withValues(alpha: 0.7);

    return Container(
      padding: EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Spacing.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(Spacing.xs),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  metric.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.xs),
          Text(
            metric.value,
            style:
                theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ) ??
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
          ),
          for (final line in helperLines) ...[
            SizedBox(height: Spacing.xs),
            Text(
              line,
              style: theme.textTheme.bodySmall?.copyWith(color: helperColor),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _iconForOutplantMetric(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('outplant event')) {
    return Icons.outbound;
  }
  if (normalized.contains('monitoring')) {
    return Icons.visibility_outlined;
  }
  if (normalized.contains('surviving')) {
    return Icons.eco_outlined;
  }
  if (normalized.contains('species')) {
    return Icons.science_outlined;
  }
  if (normalized.contains('volume')) {
    return Icons.water_drop_outlined;
  }
  if (normalized.contains('corals outplanted')) {
    return Icons.scatter_plot;
  }
  return Icons.analytics_outlined;
}

Color _colorForOutplantMetric(ThemeData theme, String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('outplant event')) {
    return AppColors.primary;
  }
  if (normalized.contains('monitoring')) {
    return AppColors.secondary;
  }
  if (normalized.contains('surviving')) {
    return AppColors.success;
  }
  if (normalized.contains('species')) {
    return AppColors.secondaryDark;
  }
  if (normalized.contains('volume')) {
    return AppColors.warning;
  }
  if (normalized.contains('corals outplanted')) {
    return AppColors.primaryDark;
  }
  return theme.colorScheme.primary;
}
