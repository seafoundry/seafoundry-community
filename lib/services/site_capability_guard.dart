// @tier: community
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Capability switches that can be enforced at the service/repository layer.
enum SiteCapabilityAction {
  propagation,
  outplant,
  move,
  environmentalAdjustment,
  receiveTransfer,
}

/// Centralised enforcement for site-level capability guardrails. UI elements
/// can hide actions based on [SiteCapabilities], but services/repositories
/// should still call this guard so bypassed UI (deep links, stale clients)
/// raises a typed [CapabilityConstraintError].
class SiteCapabilityGuard {
  const SiteCapabilityGuard();

  /// Ensures the provided [site] supports the requested [action].
  void ensureSiteAllows({
    required Site site,
    required SiteCapabilityAction action,
    OrganismKind? organism,
  }) {
    if (organism != null && !site.supportsOrganism(organism)) {
      throw CapabilityConstraintError(
        message: _organismMessage(site, organism),
        capability: '${organism.name}_unsupported',
        recoverySuggestion: _organismRecovery(organism),
      );
    }
    final capabilities = SiteCapabilities.resolve(site.siteType);
    final allowed = switch (action) {
      SiteCapabilityAction.propagation => true,
      SiteCapabilityAction.outplant => capabilities.allowOutplantActions,
      SiteCapabilityAction.move => capabilities.allowMoveActions,
      SiteCapabilityAction.environmentalAdjustment => true,
      SiteCapabilityAction.receiveTransfer => capabilities.canReceiveTransfers,
    };

    if (!allowed) {
      throw CapabilityConstraintError(
        message: _messageFor(site, action),
        capability: action.name,
        recoverySuggestion: _recoveryFor(action),
      );
    }
  }

  /// Attempts to resolve a [Site] for the given [node] and apply
  /// [ensureSiteAllows]. Nodes that are not scoped to a site (organization
  /// level) bypass the guard.
  void ensureNodeAllows({
    required GraphNode node,
    required SiteCapabilityAction action,
    OrganismKind? organism,
  }) {
    final site = siteForNode(node);
    if (site == null) {
      return;
    }
    ensureSiteAllows(site: site, action: action, organism: organism);
  }

  /// Resolve the [Site] associated with a [GraphNode], or `null` if the node
  /// does not belong to a site hierarchy (e.g. organization root).
  Site? siteForNode(GraphNode node) {
    if (node is SiteNode) {
      return _siteFromSiteNode(node);
    }
    final siteNode = node.siteNode;
    if (siteNode == null) {
      return null;
    }
    return _siteFromSiteNode(siteNode);
  }

  Site _siteFromSiteNode(GraphNode<Site> siteNode) {
    final state = siteNode.state;
    if (state is SiteLoadedState) {
      return state.site;
    }
    return siteNode.initialRecord;
  }

  String _messageFor(Site site, SiteCapabilityAction action) {
    final siteLabel = site.siteType.name;
    return switch (action) {
      SiteCapabilityAction.propagation =>
        'Propagation actions are disabled for $siteLabel locations.',
      SiteCapabilityAction.outplant =>
        'Outplant actions are disabled for $siteLabel locations.',
      SiteCapabilityAction.move =>
        'Inventory moves are not permitted within $siteLabel locations.',
      SiteCapabilityAction.environmentalAdjustment =>
        'Environmental adjustments cannot be recorded for $siteLabel locations.',
      SiteCapabilityAction.receiveTransfer =>
        '$siteLabel sites cannot receive organisms from transfers or moves.',
    };
  }

  String? _recoveryFor(SiteCapabilityAction action) {
    return switch (action) {
      SiteCapabilityAction.propagation =>
        'Move organisms to a nursery site before propagating.',
      SiteCapabilityAction.outplant =>
        'Start outplanting from a nursery site that supports outplant workflows.',
      SiteCapabilityAction.move =>
        'Use specialized workflows (like outplant or transfer) to relocate inventory.',
      SiteCapabilityAction.environmentalAdjustment =>
        'Record environmental adjustments at nursery facilities instead.',
      SiteCapabilityAction.receiveTransfer =>
        'Select a nursery or outplanting site that can receive organisms.',
    };
  }

  String _organismMessage(Site site, OrganismKind organism) {
    final siteLabel = site.siteType.name;
    final organismLabel = organism.metadata.displayName;
    return '$organismLabel workflows are disabled for $siteLabel locations.';
  }

  String _organismRecovery(OrganismKind organism) {
    final organismLabel = organism.metadata.displayName.toLowerCase();
    return 'Select a site type that supports $organismLabel workflows.';
  }
}
