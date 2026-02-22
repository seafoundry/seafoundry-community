// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/navigation/community_graph_scaffold.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/screens/graph/graph_node_section.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/graph_node/site_summary_cards.dart';
import 'package:seafoundry_app/widgets/graph_node/site_node_view_adapter.dart';
import 'package:seafoundry_app/widgets/in_situ/in_situ_grid_section.dart';
import 'package:seafoundry_app/widgets/visual/did_you_know_banner.dart';
// GraphNodeEventsList is Pro-only - community uses simplified event display

/// Community version of SiteNodeScreen without monitoring features.
class SiteNodeScreen extends StatefulWidget {
  const SiteNodeScreen({
    super.key,
    required this.loadedNodeState,
    required this.graphNode,
  });

  final SiteLoadedState loadedNodeState;
  final GraphNode graphNode;

  @override
  State<SiteNodeScreen> createState() =>
      _SiteNodeScreenState();
}

class _SiteNodeScreenState extends State<SiteNodeScreen> {
  // Cache the service to prevent creating a new stream on every rebuild.
  // CRITICAL: Creating PublicReadModelsService in build() causes infinite
  // rebuilds on web because each new instance creates a new Firestore stream,
  // which emits initial data, triggering a rebuild, creating another stream...
  late final PublicReadModelsService _brandService;
  late final Stream<BrandProfile?> _brandProfileStream;

  static PublicReadModelsService? _tryReadService(BuildContext context) {
    try {
      return context.read<PublicReadModelsService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _brandService = _tryReadService(context) ?? PublicReadModelsService();
    _brandProfileStream = _brandService.streamBrandProfile(
      widget.loadedNodeState.site.organizationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adapter = SiteNodeViewAdapter(state: widget.loadedNodeState);

    return StreamBuilder<BrandProfile?>(
      stream: _brandProfileStream,
      builder: (context, snapshot) {
        final brand = snapshot.data;
        final theme = brand != null
            ? BrandTheme.fromProfile(brand)
            : const BrandTheme(accentColor: Color(0xFF00BCD4));

        return BrandThemeProvider(
          theme: theme,
          child: CommunitySimpleGraphScreenScaffold(
            body: _SiteNodeBody(
              loadedNodeState: widget.loadedNodeState,
              graphNode: widget.graphNode,
              adapter: adapter,
            ),
          ),
        );
      },
    );
  }
}

class _SiteNodeBody extends StatelessWidget {
  const _SiteNodeBody({
    required this.loadedNodeState,
    required this.graphNode,
    required this.adapter,
  });

  final SiteLoadedState loadedNodeState;
  final GraphNode graphNode;
  final SiteNodeViewAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final sections = adapter.buildChildSections();
    final siteNode = graphNode as SiteNode;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Monitoring button removed - Pro feature
              // Breadcrumbs moved to AppBar
              // CommunityNavigationBreadcrumbs(
              //   showLogo: false,
              //   nodes: graphNode.lineage,
              // ),
              DidYouKnowBanner(
                nodeType: _resolveNodeType(adapter.capabilities.siteType),
                dismissKey: 'dyk-site-${loadedNodeState.site.id}',
              ),
              SizedBox(height: Spacing.sm),
              SizedBox(height: Spacing.sm),
              SiteSummaryCards(
                siteNode: graphNode as SiteNode,
              ),
              SizedBox(height: Spacing.md),
              if (adapter.capabilities.siteType == SiteType.nurseryInSitu) ...[
                InSituGridSection(state: loadedNodeState, siteNode: siteNode),
                SizedBox(height: Spacing.md),
              ],
              // SiteNodeInfo removed - Pro feature
              if (sections.isNotEmpty) ...[
                Text(
                  adapter.capabilities.childSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: Spacing.xs),
                ...sections.map(
                  (section) => Padding(
                    padding: EdgeInsets.only(bottom: Spacing.sm),
                    child: GraphNodeSection(
                      title: section.title,
                      children: section.nodes,
                      showSummaryCounts: true,
                    ),
                  ),
                ),
              ],
              // Events list removed - Pro feature (GraphNodeEventsList)
            ],
          ),
        );
  }

  String _resolveNodeType(SiteType type) {
    if (type.id.contains('nursery')) {
      return 'nursery';
    } else if (type.id.contains('outplant') || type.id.contains('outplanting')) {
      return 'outplant';
    }
    return 'site';
  }
}
