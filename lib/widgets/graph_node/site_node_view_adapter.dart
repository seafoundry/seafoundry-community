import 'package:seafoundry_community/models/graph/graph_node_utils.dart';
import 'package:seafoundry_community/models/graph/group_node.dart';
import 'package:seafoundry_community/models/graph/site_node.dart';
import 'package:seafoundry_community/models/site_capabilities.dart';
import 'package:seafoundry_community/models/types/event_type.dart';
import 'package:seafoundry_community/models/types/group_type.dart';

/// Helper struct describing a child section within the site node view.
class SiteChildSection {
  const SiteChildSection({
    required this.title,
    required this.groupType,
    required this.nodes,
  });

  final String title;
  final GroupType groupType;
  final List<GroupNode> nodes;
}

/// Adapts [SiteLoadedState] into the data needed by the site graph node UI.
class SiteNodeViewAdapter {
  SiteNodeViewAdapter({required this.state})
    : capabilities = SiteCapabilities.resolve(state.site.siteType);

  final SiteLoadedState state;
  final SiteCapabilities capabilities;

  /// Build sections grouped by group type, applying capability labels and
  /// sorting alphabetically by the resolved title.
  List<SiteChildSection> buildChildSections() {
    final grouped = groupsByType(state.groupNodes);
    if (grouped.isEmpty) {
      return const [];
    }

    final sections = grouped.entries
        .map(
          (entry) => SiteChildSection(
            title: capabilities.labelForGroupType(entry.key),
            groupType: entry.key,
            nodes: List<GroupNode>.from(entry.value)
              ..sort((a, b) => a.name.compareTo(b.name)),
          ),
        )
        .toList();

    sections.sort((a, b) => a.title.compareTo(b.title));
    return sections;
  }

  /// Initial filter state for activity feed, respecting capability defaults.
  Map<EventType, bool> initialEventFilters() {
    return capabilities.initialFilterState(state.events);
  }

  bool get hasChildren => state.groupNodes.isNotEmpty;
}
