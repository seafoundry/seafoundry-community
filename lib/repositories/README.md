# Repository Architecture

This document describes the repository patterns used in SeaFoundry. Understanding when to use each pattern is critical for maintaining consistency and avoiding architectural drift.

## Repository Patterns

### 1. RepositoryBase<T> - Simple Lookup Data

**Location**: `lib/repositories/base/repository_base.dart`

**Use when**:
- Data is not organization-scoped (global lookup tables)
- Simple CRUD operations with stream caching
- No complex filtering or hierarchical relationships needed

**Features**:
- StreamCache-based lazy subscription for list/record streams
- Standard CRUD: create, update, delete, getById, getAll
- Batch operation support
- Custom query builders

**Examples**: Brand profiles, global configuration

```dart
class MyLookupRepository extends RepositoryBase<MyRecord> {
  MyLookupRepository({required super.firestore});

  @override
  String get collectionPath => 'myRecords';

  @override
  ModelType get modelType => ModelType.myRecord;

  @override
  MyRecord fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      RecordFactory.recordFromJson<MyRecord>(doc.data()!);

  @override
  Map<String, dynamic> toFirestore(MyRecord record) => record.toJson();
}
```

### 2. InventoryRecordRepository<T> - Org-Scoped Inventory

**Location**: `lib/repositories/inventory/inventory_record_repository.dart`

**Use when**:
- Data is scoped to an organization
- Records have `urlPath` for hierarchical navigation
- Need BehaviorSubject-based reactive streams for real-time updates
- Support for nested collections (groups, organisms, genets, zones, subplots)

**Features**:
- Organization + user context required at construction
- BehaviorSubject provides latest state to all consumers
- URL path-based filtering for hierarchical relationships
- Slug generation with transaction-based counters
- Automatic error recovery for Firestore internal errors
- Nested collection support for certain model types

**Examples**: Sites, groups, organisms, genets, zones, events

```dart
class MySiteRepository extends InventoryRecordRepository<Site> {
  MySiteRepository({
    required Organization organization,
    required User user,
    required FirebaseFirestore firestore,
  }) : super(
    modelType: ModelType.site,
    organization: organization,
    user: user,
    firestore: firestore,
  );
}
```

### 3. RecordRepository - Generic Record Operations

**Location**: `lib/repositories/record_repository.dart`

**Use when**:
- Need to fetch records across model types without type-specific repository
- Looking up records by ID when the repository isn't available in context
- Cross-cutting concerns that span multiple model types

**Features**:
- Model type-agnostic CRUD operations
- Organization scoping for root collections
- Nested collection awareness for inventory types

**Dependency Injection**:
Always inject via Provider. The singleton pattern (`maybeInstance`, `configure`, `reset`) exists only for test harness compatibility and is marked `@visibleForTesting`.

```dart
// Production code - use provider
final repo = context.read<RecordRepository>();
final site = await repo.getRecord<Site>(ModelType.site, siteId);

// Test code only - singleton pattern
RecordRepository.configure(firestore: fakeFirestore);
final repo = RecordRepository.maybeInstance!;
```

### 4. Ad-hoc Domain Repositories

**Use when**:
- Complex domain-specific business logic
- Multiple Firestore operations in single transactions
- Special pagination or caching requirements
- Cross-collection operations

**Examples**:
- `CommentRepository` - Real-time comment threads with pagination
- `ChatRepository` - Message streaming with read receipts
- `CommunityEventsRepository` - Cross-org event aggregation

These repositories implement their own patterns tailored to their domain needs rather than extending a base class.

## Choosing the Right Pattern

| Requirement | Pattern |
|-------------|---------|
| Global lookup data, no org scoping | RepositoryBase |
| Org-scoped with urlPath hierarchy | InventoryRecordRepository |
| Cross-type record access | RecordRepository |
| Complex domain logic | Ad-hoc |

## Collection Structure

### Root Collections
Used for global data or when organizationId filtering is sufficient:
- `organizations`
- `users`
- `species`
- `siteTypes`

### Nested Collections
Used for better data isolation and security rule simplicity:
- `organizations/{orgId}/groups`
- `organizations/{orgId}/organismRecords`
- `organizations/{orgId}/genets`
- `organizations/{orgId}/zones`
- `organizations/{orgId}/subplots`

## Key Principles

1. **Prefer InventoryRecordRepository** for inventory data - it handles the complexity of org scoping, URL path filtering, and real-time updates.

2. **Never use RecordRepository singleton in production** - always inject via Provider.

3. **BehaviorSubject for inventory** - ensures UI always gets latest state, supports multiple concurrent listeners.

4. **StreamCache for lookup data** - lazy subscription reduces Firestore reads for infrequently accessed data.

5. **URL path for hierarchy** - enables efficient descendant queries without complex joins.

## See Also

- `lib/services/url_path_resolver.dart` - URL path normalization and hierarchy checks
- `CLAUDE.md` - Overall architecture patterns and conventions
