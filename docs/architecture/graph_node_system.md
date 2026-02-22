# Graph Node System Architecture

This document describes the hierarchical graph node system used for inventory navigation and state management in SeaFoundry.

## Overview

The graph node system provides a reactive, hierarchical representation of the inventory tree. Each node represents an entity (organization, site, group, or organism) and streams its children, events, and metadata in real-time via RxDart.

```
OrganizationNode
├── SiteNode (nursery)
│   ├── GroupNode (tank)
│   │   └── OrganismNode (coral fragment)
│   └── OrganismNode (direct child)
└── SiteNode (outplanting)
    ├── GroupNode (zone)
    │   └── GroupNode (subplot)
    │       └── OrganismNode (outplanted coral)
    └── OrganismNode (direct outplant)
```

## Core Classes

### GraphNode<T> (`graph_node_bloc.dart`)

Abstract base class for all graph nodes. Extends `Cubit<GraphNodeState<T>>` for state management.

**Key Properties:**
- `currentRecord` - The underlying data record (Site, Group, OrganismRecord)
- `currentUrlPath` - URL path for navigation (e.g., `org/site/group/organism`)
- `parent` - Reference to parent node in hierarchy
- `state` - Current node state (Initial, Loading, Loaded, Error)

**Key Methods:**
- `awaitLoaded()` - Async wait for node to reach loaded or error state
- `buildDefaultChildrenStream()` - Override to define child streaming logic
- `loadedStateFromData()` - Override to construct loaded state from stream data

### GraphNodeState<T> (`graph_node_state.dart`)

```dart
sealed class GraphNodeState<T> {}

class GraphNodeInitial<T> extends GraphNodeState<T> {}
class GraphNodeLoading<T> extends GraphNodeState<T> {}
class GraphLoadedState<T> extends GraphNodeState<T> {
  final T record;
  final List<GraphNode> children;
  final List<Event> events;
  final User? creator;
}
class GraphNodeError<T> extends GraphNodeState<T> {
  final Object error;
  final StackTrace stackTrace;
}
```

## Node Types

### OrganizationNode (`organization_node.dart`)
Root node representing the organization. Streams sites as children.

### SiteNode (`site_node.dart`)
Represents a physical location (nursery, outplanting site). Streams both groups AND organisms as children.

**Special Behavior:**
- Outplanting sites combine URL-path events with `siteId`-referenced outplant events
- Organisms can be direct children (not nested in groups)

### GroupNode (`group_node.dart`)
Container for organizing organisms (tanks, tables, zones, subplots). Streams child groups and organisms.

### OrganismNode (`organism_node.dart`)
Leaf node representing an individual organism record. Can have child organisms for fragmentation hierarchies.

## Stream Architecture

Each node builds four primary streams that are combined via `CombineLatestStream`:

```dart
CombineLatestStream.list([
  recordStream,      // Real-time record updates
  childrenStream,    // Child node list
  eventsStream,      // Events for this node
  creatorStream,     // User who created record
])
```

### Error Handling Pattern

All streams follow this pattern for robustness:

```dart
graphRepository.streamData()
    .doOnError((error, stackTrace) {
      LoggingService.instance.error('Context message', error, stackTrace);
    })
    .onErrorReturn(const <DataType>[])  // Prevent hanging
    .shareReplay(maxSize: 1)            // Share subscription
    .startWith(const <DataType>[])      // Immediate emission
    .toBroadcastIfNeeded(StreamType.x)
```

**Key Points:**
1. `.doOnError()` - Log errors for debugging
2. `.onErrorReturn()` - Return empty list to prevent stream from hanging
3. `.shareReplay()` - Share subscription across multiple listeners
4. `.startWith()` - Emit immediately for `CombineLatestStream` to fire

## Navigation & Path Resolution

### URL Path Structure

Every record has a `urlPath` for navigation:
```
{org-slug}/{site-slug}/{group-slug}/{organism-localId}
```

### Path Resolution (`graph_repository.dart`)

To navigate to a path:

1. Parse path into segments
2. Starting from organization, recursively load parent nodes
3. Call `awaitLoaded()` on each parent to ensure children are available
4. Find matching child node by slug/localId
5. Return the target node or null if not found

```dart
Future<GraphNode?> getNodeForUrlPath(String urlPath) async {
  // Normalize and validate path
  // Recursively load parent chain
  // Find and return target node
}
```

### awaitLoaded() Behavior

The `awaitLoaded()` method waits for a node to complete loading:

```dart
Future<void> awaitLoaded() async {
  if (state is GraphLoadedState) return;
  if (state is GraphNodeError) {
    throw (state as GraphNodeError<T>).error;
  }
  final finalState = await stream.firstWhere(
    (s) => s is GraphLoadedState || s is GraphNodeError,
  );
  if (finalState is GraphNodeError<T>) {
    throw finalState.error;
  }
}
```

**Important:** This method throws if the node enters an error state. Callers must handle this:

```dart
try {
  await node.awaitLoaded();
  // Use node.state
} catch (e) {
  // Handle load failure
}
```

## Caching (`graph_cache_manager.dart`)

The `GraphCacheManager` maintains a cache of loaded nodes by URL path:

- Nodes are cached when first loaded
- Cache is invalidated on record deletion
- Pending loads are tracked via `Completer` to prevent duplicate requests

## MovableNode Mixin

Nodes that can be moved between parents (OrganismNode, GroupNode) mix in `MovableNode<T>`:

```dart
mixin MovableNode<T extends GraphNodeRecord> on GraphNode<T> {
  Future<void> moveToParent(GraphNode newParent);
}
```

## Best Practices

### Adding New Node Types

1. Extend `GraphNode<T>` with your record type
2. Override `buildDefaultChildrenStream()` with proper error handling
3. Override `loadedStateFromData()` to construct your loaded state
4. Create a corresponding `XLoadedState` class extending `GraphLoadedState<T>`

### Error Handling

- Always use `.doOnError()` for logging
- Always use `.onErrorReturn()` to prevent hangs
- Always use `.startWith()` for immediate emission
- Wrap `awaitLoaded()` calls in try/catch

### Performance

- Use `.shareReplay(maxSize: 1)` to share subscriptions
- Use `synchronizeGraphNodes()` to reuse existing node instances
- Call `close()` on removed nodes to clean up subscriptions

## Related Files

- `lib/blocs/graph_node/graph_node_bloc.dart` - Base GraphNode class
- `lib/blocs/graph_node/graph_node_state.dart` - State classes
- `lib/blocs/graph_node/organization_node.dart` - Organization node
- `lib/blocs/graph_node/site_node.dart` - Site node
- `lib/blocs/graph_node/group_node.dart` - Group node
- `lib/blocs/graph_node/organism_node.dart` - Organism node
- `lib/blocs/graph_node/graph_factory.dart` - Node synchronization utilities
- `lib/repositories/graph_repository.dart` - Path resolution and caching
- `lib/services/cache_manager.dart` - GraphCacheManager implementation
