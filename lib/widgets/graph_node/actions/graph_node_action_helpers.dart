// @tier: community
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';

/// Helper utilities for graph node actions
class GraphNodeActionHelpers {
  /// Get capabilities for a graph node
  SiteCapabilities? capabilitiesFor(GraphNode node) {
    SiteNode? siteNode;
    if (node is SiteNode) {
      siteNode = node;
    } else {
      final siteGraphNode = node.siteNode;
      siteNode = siteGraphNode is SiteNode ? siteGraphNode : null;
    }
    final siteState = siteNode?.state;
    if (siteState is SiteLoadedState) {
      return SiteCapabilities.resolve(siteState.site.siteType);
    }
    return null;
  }

  /// Safely get record from GraphNode state
  GraphNodeRecord getRecord(GraphNode node) {
    final state = node.state;
    if (state is! GraphLoadedState) {
      throw StateError('Node must be loaded to show actions');
    }
    return state.record;
  }

  /// Safely get record from GraphNode state (nullable)
  GraphNodeRecord? maybeRecord(GraphNode node) {
    final state = node.state;
    return state is GraphLoadedState ? state.record : null;
  }

  /// Get site for graph node
  Site? siteForGraphNode(GraphNode node) {
    if (node is SiteNode) {
      final state = node.state;
      if (state is SiteLoadedState) {
        return state.site;
      }
      return node.site;
    }

    final record = maybeRecord(node);
    if (record is Site) {
      return record;
    }

    final ancestor = node.siteNode;
    if (ancestor is SiteNode) {
      final state = ancestor.state;
      if (state is SiteLoadedState) {
        return state.site;
      }
      return ancestor.site;
    }

    return null;
  }

  /// Get children nodes
  List<GraphNode> getChildren(GraphNode node) {
    final state = node.state;
    if (state is! GraphLoadedState) {
      return const [];
    }
    return state.children;
  }

  /// Check if organism node is propagatable (e.g. coral)
  bool isPropagatable(OrganismNode node) {
    final state = node.state;
    if (state is! GraphLoadedState<OrganismRecord>) {
      return false;
    }
    final organism = state.record;
    // Only organisms that support propagation - check metadata flag
    final readyForPropagation = organism.readyForPropagation;
    return readyForPropagation && organism.healthStatus == HealthStatus.healthy;
  }

  /// Count overdue tasks
  int overdueTaskCount(GraphNode node) {
    final state = node.state;
    if (state is! GraphLoadedState) {
      return 0;
    }

    final now = DateTime.now();
    return state.events
        .whereType<TaskEvent>()
        .where(
          (task) =>
              task.completedAt == null &&
              task.deadline != null &&
              task.deadline!.isBefore(now),
        )
        .length;
  }

  /// Count incomplete tasks (not completed)
  int incompleteTaskCount(GraphNode node) {
    final state = node.state;
    if (state is! GraphLoadedState) {
      return 0;
    }

    return state.events
        .whereType<TaskEvent>()
        .where((task) => task.completedAt == null)
        .length;
  }

  /// Check if node has inventory actions
  bool hasInventoryActions(
    GraphNode node, {
    OrganismKind? organismKind,
  }) {
    if (!_supportsOrganismWorkflows(node, organismKind)) return false;
    return node is OrganizationNode ||
        node is SiteNode ||
        node is GroupNode ||
        node is OrganismNode;
  }

  /// Check if node has observation actions
  bool hasObservationActions(
    GraphNode node, {
    OrganismKind? organismKind,
  }) {
    if (!_supportsOrganismWorkflows(node, organismKind)) return false;
    return true;
  }

  /// Check if node has husbandry actions
  bool hasHusbandryActions(
    GraphNode node, {
    OrganismKind? organismKind,
  }) {
    if (!_supportsOrganismWorkflows(node, organismKind)) return false;
    return node is OrganizationNode ||
        node is SiteNode ||
        node is GroupNode ||
        node is OrganismNode;
  }

  /// Check if node has task actions
  bool hasTaskActions(GraphNode node) {
    return true;
  }

  /// Check if category is supported
  bool supportsCategory(
    GraphNode node,
    SiteCapabilities? capabilities,
    SiteActionCategory category, {
    OrganismKind? organismKind,
  }) {
    if (!_supportsOrganismWorkflows(node, organismKind) &&
        category != SiteActionCategory.tasks) {
      return false;
    }
    if (capabilities == null) {
      return true;
    }
    return capabilities.enabledActionCategories.contains(category);
  }

  bool _supportsOrganismWorkflows(
    GraphNode node,
    OrganismKind? activeOrganism,
  ) {
    final site = siteForGraphNode(node);
    if (site == null) {
      return true;
    }
    if (activeOrganism == null) {
      return site.supportedOrganismKinds.isNotEmpty;
    }
    return site.supportsOrganism(activeOrganism);
  }
}
