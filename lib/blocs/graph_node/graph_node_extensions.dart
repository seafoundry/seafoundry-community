// @tier: community

import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/models/models.dart';

/// Extension methods for GraphNode to simplify graph traversal and record resolution.
///
/// These extensions eliminate duplicated graph-walking logic by providing
/// canonical methods for resolving parent records (Site, Group) and finding
/// child/descendant nodes by ID.
///
/// ## Stale Data Considerations
///
/// All resolution methods prioritize **performance over freshness** by checking
/// `GraphLoadedState` first, then falling back to `initialRecord` if the node
/// hasn't loaded yet. This means returned data may be stale if:
/// - The node is still in loading state (GraphNodeInitial or GraphNodeLoading)
/// - The parent/child nodes haven't been refreshed after mutations
///
/// This is an acceptable trade-off (TOCTOU limitation) for most UI use cases
/// where immediate response is more important than perfect consistency.
///
/// ## Usage Examples
///
/// ### Basic Resolution
/// ```dart
/// // Resolve site from organism node
/// final site = organismNode.resolveSite();
/// if (site != null) {
///   print('Organism is in site: ${site.name}');
/// }
///
/// // Resolve group from organism node
/// final group = organismNode.resolveGroup();
/// ```
///
/// ### Null-Safety Pattern
/// ```dart
/// // Using pattern matching for null safety
/// if (node.resolveSite() case final site?) {
///   // site is non-null here
///   showPermitSection(site);
/// }
/// ```
///
/// ### Finding Children
/// ```dart
/// // Find direct child by ID
/// final child = parentNode.findChildById('child-id-123');
///
/// // Find descendant by ID (recursive search)
/// final descendant = rootNode.findDescendantById('deep-child-id', maxDepth: 5);
/// ```
///
/// ### Ensuring Fresh Data
/// ```dart
/// // If you need guaranteed fresh data, await loading first
/// await node.awaitLoaded();
/// final site = node.resolveSite();
/// // Now site is guaranteed to be from loaded state
/// ```
///
/// ## When to Use vs Not Use
///
/// **Use these extensions when:**
/// - Resolving parent Site/Group for UI display or validation
/// - Finding child nodes for user selection dialogs
/// - You need graceful null handling (returns null instead of throwing)
/// - Performance matters more than absolute freshness
///
/// **Don't use these extensions when:**
/// - You need guaranteed fresh data for critical operations (use awaitLoaded first)
/// - You're already inside a node's loaded state (use state.record directly)
/// - You need complex traversal logic beyond parent/child relationships
/// - You need repository-backed queries (use repositories directly)
extension GraphNodeResolution on GraphNode {
  /// Resolves the Site record from the current node's hierarchy.
  ///
  /// This method walks up the graph hierarchy to find the nearest Site ancestor.
  /// It checks:
  /// 1. If current node is a Site node → returns its record
  /// 2. If current node is a Group → resolves Site from parent siteNode
  /// 3. Otherwise → walks up parent chain until Site is found
  ///
  /// Returns null if no Site ancestor exists (e.g., OrganizationNode) or if
  /// type verification fails.
  ///
  /// **Type Safety**: Uses runtime type checks (`is Site`) to ensure returned
  /// record is actually a Site, even when using the initialRecord fallback.
  /// This defensive approach prevents potential ClassCastException errors.
  ///
  /// **Performance Note**: Uses siteNode shortcut when available, falls back
  /// to parent traversal otherwise.
  ///
  /// Example:
  /// ```dart
  /// final site = organismNode.resolveSite();
  /// if (site != null) {
  ///   validatePermit(site);
  /// }
  /// ```
  Site? resolveSite() {
    // Check if current node is already a Site node
    final nodeState = state;
    if (nodeState is GraphLoadedState<Site>) {
      return nodeState.record;
    }

    // Fallback: check initialRecord if not loaded yet
    final initial = initialRecord;
    if (initial is Site) {
      return initial;
    }

    // If parent is a Group, use siteNode shortcut
    if (nodeState is GraphLoadedState<Group>) {
      final site = siteNode;
      if (site != null) {
        final siteState = site.state;
        if (siteState is GraphLoadedState<Site>) {
          return siteState.record;
        }
        // Fallback: If state isn't loaded yet, try initialRecord with type check
        // Note: This check is defensive against the unsafe cast in siteNode getter
        // (lineage[1] as GraphNode<Site>). The analyzer flags this as unnecessary
        // but it's needed to prevent ClassCastException if the cast is incorrect.
        final initial = site.initialRecord;
        // ignore: unnecessary_type_check
        if (initial is Site) {
          return initial;
        }
      }
      return null;
    }

    // For OrganismRecord or other types, walk up parent chain
    GraphNode? current = parent;
    while (current != null) {
      final currentState = current.state;
      if (currentState is GraphLoadedState<Site>) {
        return currentState.record;
      }

      // Fallback: check initialRecord
      final currentInitial = current.initialRecord;
      if (currentInitial is Site) {
        return currentInitial;
      }

      current = current.parent;
    }

    return null;
  }

  /// Resolves the Group record from the current node.
  ///
  /// This method returns the Group record if:
  /// 1. Current node is a Group node → returns its record
  /// 2. Current node is an Organism with a parent Group → returns parent Group
  ///
  /// Returns null if current node is not a Group and has no Group parent.
  ///
  /// Example:
  /// ```dart
  /// final group = organismNode.resolveGroup();
  /// if (group != null) {
  ///   print('Organism is in group: ${group.name}');
  /// }
  /// ```
  Group? resolveGroup() {
    // Check if current node is already a Group node
    final nodeState = state;
    if (nodeState is GraphLoadedState<Group>) {
      return nodeState.record;
    }

    // Fallback: check initialRecord if not loaded yet
    final initial = initialRecord;
    if (initial is Group) {
      return initial;
    }

    // Check if parent is a Group (for OrganismRecord children)
    final parentNode = parent;
    if (parentNode != null) {
      final parentState = parentNode.state;
      if (parentState is GraphLoadedState<Group>) {
        return parentState.record;
      }

      // Fallback: check parent's initialRecord with type check
      final parentInitial = parentNode.initialRecord;
      if (parentInitial is Group) {
        return parentInitial;
      }
    }

    return null;
  }

  /// Resolves the OrganismRecord from the current node.
  ///
  /// This method returns the OrganismRecord if the current node is an
  /// OrganismNode. Returns null otherwise.
  ///
  /// Example:
  /// ```dart
  /// final organism = node.resolveOrganism();
  /// if (organism != null) {
  ///   print('Organism: ${organism.id}');
  /// }
  /// ```
  OrganismRecord? resolveOrganism() {
    final nodeState = state;
    if (nodeState is GraphLoadedState<OrganismRecord>) {
      return nodeState.record;
    }

    // Fallback: check initialRecord
    final initial = initialRecord;
    if (initial is OrganismRecord) {
      return initial;
    }

    return null;
  }

  /// Finds a direct child node by its ID.
  ///
  /// Searches only immediate children (not recursive). Returns null if:
  /// - Node is not loaded yet (no children available)
  /// - Child with given ID is not found
  ///
  /// **Requires loaded state**: This method only searches children from
  /// GraphLoadedState. If you call it on an unloaded node, it returns null.
  ///
  /// Example:
  /// ```dart
  /// final childNode = parentNode.findChildById('child-123');
  /// if (childNode != null) {
  ///   // Work with child
  /// }
  /// ```
  GraphNode? findChildById(String id) {
    final nodeState = state;
    if (nodeState is! GraphLoadedState) {
      return null;
    }

    for (final child in nodeState.children) {
      if (child.id == id) {
        return child;
      }
    }

    return null;
  }

  /// Recursively finds a descendant node by ID.
  ///
  /// Performs depth-first search up to [maxDepth] levels deep (default: 10).
  /// Returns the first matching node found, or null if no match exists.
  ///
  /// **Warning**: This is a potentially expensive operation for large graphs.
  /// Prefer [findChildById] if you know the node is a direct child.
  ///
  /// Parameters:
  /// - [id]: The node ID to search for
  /// - [maxDepth]: Maximum recursion depth (default: 10 levels)
  ///
  /// Example:
  /// ```dart
  /// // Find deeply nested organism
  /// final organism = siteNode.findDescendantById('org-456', maxDepth: 5);
  /// ```
  GraphNode? findDescendantById(String id, {int maxDepth = 10}) {
    if (maxDepth <= 0) {
      return null;
    }

    // Check direct children first
    final directChild = findChildById(id);
    if (directChild != null) {
      return directChild;
    }

    // Recursively search children's descendants
    final nodeState = state;
    if (nodeState is! GraphLoadedState) {
      return null;
    }

    for (final child in nodeState.children) {
      final descendant = child.findDescendantById(id, maxDepth: maxDepth - 1);
      if (descendant != null) {
        return descendant;
      }
    }

    return null;
  }

  /// Specialized method to resolve Site from an OrganismNode's hierarchy.
  ///
  /// This is a convenience wrapper around [resolveSite] specifically for
  /// OrganismRecord nodes. It traverses: Organism → Group → Site.
  ///
  /// Throws StateError if:
  /// - No Site ancestor can be found (rare - indicates graph corruption)
  ///
  /// **Use this when**: You need a Site and want to fail fast if it's missing
  /// (e.g., during form submission where Site is mandatory).
  ///
  /// **Don't use this when**: You want graceful null handling (use [resolveSite] instead).
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final site = organismNode.resolveSiteFromOrganism();
  ///   submitEvent(site);
  /// } catch (e) {
  ///   showError('Cannot find site for organism');
  /// }
  /// ```
  Site resolveSiteFromOrganism() {
    final site = resolveSite();
    if (site != null) {
      return site;
    }

    throw StateError('Unable to resolve site for organism node $id');
  }
}
