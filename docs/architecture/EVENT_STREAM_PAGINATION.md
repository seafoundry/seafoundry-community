# Event Stream Limits & Pagination Strategy

## Overview

SeaFoundry uses a tiered approach to event loading that balances responsiveness with scalability:

1. **Real-time Streams**: Limited initial load for responsive UI
2. **Pagination Methods**: Cursor-based pagination for historical access
3. **Organization-level Scaling**: Higher limits for aggregate views

---

## Stream Limits by Context

### Record-Level Views (Default)
- **Method**: `EventRepository.streamEventsForUrlPath()`
- **Default Limit**: 100 events
- **Use Case**: Activity feed for individual organisms, groups, sites
- **Location**: `lib/repositories/inventory/event_repository.dart:160-215`

### Organization-Level Views
- **Method**: `GraphRepository.streamEventsForUrlPath()`  
- **Default Limit**: 500 events
- **Use Case**: Dashboard summaries, organization-wide activity
- **Location**: `lib/repositories/graph_repository.dart:486-500`

### Rationale
- Organization-level views show aggregated descendant events, requiring higher limits
- Record-level views typically have fewer events, so 100 is sufficient
- Both streams use server-side `limit()` to reduce network transfer and parsing overhead

---

## Pagination Methods

### Historical Events (Date-Range)
```dart
// Fetch events within a date range with cursor-based pagination
final events = await eventRepository.fetchHistoricalEvents(
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 12, 31),
  limit: 1000,
  startAfter: lastDocument, // Cursor from previous fetch
);
```
- **Location**: `lib/repositories/inventory/event_repository.dart:218-246`
- **Use Case**: Reports, exports, analytics over time periods

### Historical Events for URL Path (Paginated)
```dart
// Fetch historical events for a specific record with pagination
final result = await eventRepository.fetchHistoricalEventsForUrlPath(
  urlPath: '/org/site/group',
  startDate: startDate,
  endDate: endDate,
  limit: 100,
  startAfter: cursor,
);
// result.events - list of events
// result.cursor - DocumentSnapshot for next page
// result.hasMore - whether more events exist
```
- **Location**: `lib/repositories/inventory/event_repository.dart:252+`
- **Use Case**: "Load more" functionality in activity feeds

---

## Scaling Considerations

### Current Limits Work For
- Organizations with < 50,000 events per record
- Activity feeds displaying recent 30-180 days of activity
- Dashboard views aggregating up to 500 recent events

### Signs You May Need Higher Limits
1. Users report "missing events" in activity feeds
2. Dashboard shows incomplete data for active organizations
3. Export/report operations time out

### Mitigation Strategies
1. **Increase stream limits** (monitor memory usage)
2. **Add time-window filtering** in combination with limits
3. **Implement infinite scroll** with pagination cursors
4. **Create summary/aggregation tables** for dashboard metrics

---

## Implementation Notes

### Server-Side Filtering
All event streams use Firestore server-side filtering where possible:
- `organizationId` equality filter
- `urlPath` range queries for hierarchical filtering
- `createdAt` ordering for chronological display

### Client-Side Filtering (Post-Query)
Some filtering happens after the Firestore query:
- `recordId` filter (when fetching events for multiple records)
- `shallow` filter (excluding deeply nested children)
- Task completion date sorting (overrides createdAt for completed tasks)

### Index Requirements
Event queries require these Firestore indexes:
- `organizationId` + `urlPath` + `createdAt`
- `organizationId` + `createdAt`

See `firestore.indexes.json` for complete index configuration.

---

## Related Files

| File | Purpose |
|------|---------|
| `lib/repositories/inventory/event_repository.dart` | Core event streaming and pagination |
| `lib/repositories/graph_repository.dart` | Organization-level event aggregation |
| `lib/screens/graph/graph_node_events_list.dart` | Activity feed UI with load-more |
| `firestore.indexes.json` | Required Firestore indexes |
