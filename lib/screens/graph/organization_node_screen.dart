// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/navigation/community_graph_scaffold.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/screens/graph/graph_node_section.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/navigation/summary_statistics.dart';
import 'package:seafoundry_app/widgets/visual/did_you_know_banner.dart';
// GraphNodeEventsList is Pro-only - community uses simplified event display

/// Community version of OrganizationNodeScreen without map/forecasting features.
class OrganizationNodeScreen extends StatefulWidget {
  const OrganizationNodeScreen({
    super.key,
    required this.loadedNodeState,
    required this.graphNode,
  });

  final OrganizationLoadedState loadedNodeState;
  final GraphNode graphNode;

  @override
  State<OrganizationNodeScreen> createState() =>
      _OrganizationNodeScreenState();
}

class _OrganizationNodeScreenState
    extends State<OrganizationNodeScreen> {
  // Cache the service to prevent creating a new stream on every rebuild.
  // CRITICAL: Creating PublicReadModelsService in build() causes infinite
  // rebuilds on web because each new instance creates a new Firestore stream,
  // which emits initial data, triggering a rebuild, creating another stream...
  late final PublicReadModelsService _brandService;
  late final Stream<BrandProfile?> _brandProfileStream;

  @override
  void initState() {
    super.initState();
    _brandService = PublicReadModelsService();
    _brandProfileStream = _brandService.streamBrandProfile(
      widget.loadedNodeState.organization.id,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            body: _OrganizationNodeBody(
              loadedNodeState: widget.loadedNodeState,
              graphNode: widget.graphNode,
            ),
          ),
        );
      },
    );
  }
}

class _OrganizationNodeBody extends StatelessWidget {
  const _OrganizationNodeBody({
    required this.loadedNodeState,
    required this.graphNode,
  });

  final OrganizationLoadedState loadedNodeState;
  final GraphNode graphNode;

  @override
  Widget build(BuildContext context) {
    final sections = _buildChildrenSections();

    return SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contextual education banner for staff/visitors
              DidYouKnowBanner(
                nodeType: 'organization',
                dismissKey: 'dyk-org-${loadedNodeState.organization.id}',
              ),
              SizedBox(height: Spacing.sm),
              // Map section removed - Pro feature
              SizedBox(height: Spacing.sm),
              SummaryStatistics(node: graphNode),
              SizedBox(height: Spacing.md),
              // OrganizationNodeInfo removed - Pro feature
              if (sections.isNotEmpty) ...sections,
          // Events list removed - Pro feature (GraphNodeEventsList)
        ],
      ),
    );
  }

  List<Widget> _buildChildrenSections() {
    if (loadedNodeState.siteNodes.isEmpty) {
      return [];
    }

    final sites = loadedNodeState.siteNodes;
    final sitesByType = <String, List<GraphNode<Site>>>{};

    for (final node in sites) {
      final site = node.currentRecord;
      final typeName = site.siteType.name;
      sitesByType.putIfAbsent(typeName, () => []).add(node);
    }

    // Define preferred order
    final order = [
      'Gene Bank',
      'Ex-Situ Nursery',
      'In-Situ Nursery',
      'Outplanting Site',
      'Seagrass Plot',
      'Mangrove Outplant',
    ];

    final sections = <Widget>[];

    // Add sections in preferred order
    for (final typeName in order) {
      if (sitesByType.containsKey(typeName)) {
        sections.add(
          GraphNodeSection(title: typeName, children: sitesByType[typeName]!),
        );
        sitesByType.remove(typeName);
      }
    }

    // Add remaining sections
    for (final entry in sitesByType.entries) {
      sections.add(GraphNodeSection(title: entry.key, children: entry.value));
    }

    return sections;
  }
}
