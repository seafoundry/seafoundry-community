# Firestore Collection Architecture

**Last Updated:** 2026-01-20

This document describes the Firestore collection structure used in SeaFoundry, including which collections are root-level vs. organization-nested.

## Collection Types

### Global/Shared Collections

These collections contain reference data or app configuration shared across all organizations. Write access is typically restricted to server-side operations or requires authentication.

| Collection | Description | Write Access |
|------------|-------------|--------------|
| `taxonomy` | Legacy taxonomy reference data | Server-only |
| `taxonomy_species` | Canonical species catalog | Server-only |
| `taxonomy_provenances` | Canonical provenances catalog | Server-only |
| `taxonomy_lineages` | Legacy lineage fallback data | Server-only |
| `taxonomy_overrides` | Global taxonomy configuration overrides | Admin-only |
| `species` | Legacy species reference data | Server-only |
| `group_types` | Group type definitions | Server-only |
| `site_types` | Site type definitions | Server-only |
| `tier_manifest` | App configuration and feature flags | Server-only |
| `training_media` | Shared training/onboarding content | Server-only |
| `historical_impact_points` | Legacy historical data | Read-only |
| `historical_outplant_events` | Legacy historical events | Read-only |
| `historical_filter_options` | Legacy filter metadata | Read-only |
| `historical_reef_aggregates` | Legacy aggregate data | Read-only |
| `provenance_crosswalk` | Provenance ID mappings | Server-only |
| `community_provenances` | Community tier provenance ranges | Server-only |
| `community_genetics_provenances` | Genetics provenance ranges | Server-only |
| `community_genetics_aliases` | Genetics ID aliases | Server-only |

### Audit Collections

| Collection | Description | Write Access |
|------------|-------------|--------------|
| `taxonomy_audit` | Taxonomy admin audit log (server-only) | Server-only |

### Root Collections

Root collections are stored at the top level of Firestore and use `organizationId` field filtering to scope data.

| Collection | Description |
|------------|-------------|
| `organizations` | Organization records |
| `users` | User profiles |
| `sites` | Site records |
| `events` | All event records |
| `invitations` | User invitations |
| `brand_profiles` | Organization branding |

### Organization-Nested Collections

These collections are stored under `organizations/{orgId}/` for better data isolation. The collection path itself scopes data to the organization.

| Collection | Full Path |
|------------|-----------|
| `members` | `organizations/{orgId}/members` |
| `groups` | `organizations/{orgId}/groups` |
| `genets` | `organizations/{orgId}/genets` |
| `organism_records` | `organizations/{orgId}/organism_records` |
| `slugCounts` | `organizations/{orgId}/slugCounts` |
| `reports` | `organizations/{orgId}/reports` |
| `custom_task_types` | `organizations/{orgId}/custom_task_types` |
| `custom_observation_types` | `organizations/{orgId}/custom_observation_types` |
| `custom_group_types` | `organizations/{orgId}/custom_group_types` |
| `custom_attachment_methods` | `organizations/{orgId}/custom_attachment_methods` |

#### Membership Subcollection

**Document Path**: `/organizations/{orgId}/members/{uid}`

This subcollection is the foundation for the **UID-based identity migration** (Phase R0-C). It provides explicit organization membership tracking and enables future multi-org support.

**Schema**:
```javascript
{
  role: "admin" | "practitioner_plus" | "practitioner" | "view_only",
  status: "active" | "invited" | "suspended",
  joinedAt: Timestamp,
  email: "user@example.com",  // Lowercase, for display/search
  invitedBy: "uid_of_inviter", // Optional, UID of user who sent invitation
  invitedAt: Timestamp         // Optional, when invitation was sent
}
```

**Purpose**:
- Replaces implicit membership via `user.organizationId` field
- Enables explicit permission checks via `isMember(orgId)` helper
- Allows users to belong to multiple organizations (future enhancement)
- Provides audit trail for invitations and role changes

**Access Control**:
- **Read**: Org members can list other members
- **Create**: Org creator (during onboarding) or via invitation acceptance
- **Update**: Admins can change roles; users can update their own profile fields
- **Delete**: Only admins can remove members

**Migration Notes**:
- Phase R0-B adds rules and app code to write membership docs
- Phase R2-C backfills membership docs for all existing users
- Phase R3-B switches from implicit `user.organizationId` to explicit `isMember()` checks
- See `docs/migration/RULES_MIGRATION_RUNBOOK.md` for full migration plan

#### Custom Type Subcollections (Pro Tier)

**Document Paths**:
- `/organizations/{orgId}/custom_task_types/{typeId}`
- `/organizations/{orgId}/custom_observation_types/{typeId}`
- `/organizations/{orgId}/custom_group_types/{typeId}`
- `/organizations/{orgId}/custom_attachment_methods/{typeId}`

These subcollections allow Pro tier organizations to create custom enum types beyond the builtin options. Each type follows a similar schema pattern:

**Schema** (example for `custom_attachment_methods`):
```javascript
{
  id: "custom_attach_wire_tie",        // Must match ID prefix pattern
  name: "Wire Tie",                     // Display name
  description: "Metal wire tie attachment",  // Optional
  icon: "link",                         // Optional Material icon name
  color: "#4CAF50",                     // Optional hex color
  isActive: true,                       // Whether visible in dropdowns
  sortOrder: 0,                         // Order in lists (builtins first)
  organizationId: "org_xyz",            // Must match parent org
  createdAt: Timestamp,
  createdById: "user_abc",
  updatedAt: Timestamp,
  updatedById: "user_abc"
}
```

**ID Prefix Patterns**:
| Collection | Required Prefix | Example |
|------------|-----------------|---------|
| `custom_task_types` | `custom_task_` | `custom_task_photo_doc` |
| `custom_observation_types` | `custom_obs_` | `custom_obs_spawning` |
| `custom_group_types` | `custom_group_` | `custom_group_broodstock` |
| `custom_attachment_methods` | `custom_attach_` | `custom_attach_wire_tie` |

**Access Control**:
- **Read**: Org members can read custom types
- **Create/Update/Delete**: Admin role + Pro tier required
- **Validation**: ID must match prefix pattern, name required, organizationId must match

**Related Documentation**:
- `docs/CUSTOM_ENUM_TYPES_IMPLEMENTATION.md` - Task, observation, group types
- `docs/OUTPLANT_DIALOG_ENHANCEMENT_IMPLEMENTATION.md` - Attachment methods

## Repository Implementation Patterns

### Using FirestoreCollectionResolver

All repositories MUST use `FirestoreCollectionResolver` for collection access:

```dart
// For root collections
final collection = FirestoreCollectionResolver.instance.collection(
  firestore,
  'sites',
);

// For nested collections
final collection = FirestoreCollectionResolver.instance.subcollection(
  firestore,
  'organizations',
  organizationId,
  'groups',
);
```

### BaseInventoryRecordRepository Pattern

The base class automatically handles nested vs. root collections based on `ModelType`:

```dart
static bool _usesNestedCollection(ModelType type) {
  return type == ModelType.group ||
      type == ModelType.organismRecord ||
      type == ModelType.genet;
}
```

### RecordRepository Organization-Aware Methods

When using `RecordRepository` for ad-hoc queries, pass `organizationId` for nested collection types:

```dart
// For nested collection types (group, genet, organismRecord)
final record = await recordRepository.getRecord<Group>(
  ModelType.group,
  groupId,
  organizationId: currentOrganization.id,
);

// For root collection types (site, event, user)
final record = await recordRepository.getRecord<Site>(
  ModelType.site,
  siteId,
);
```

## Common Pitfalls

### 1. Missing organizationId in Queries

**Problem**: Querying nested collections without `organizationId` returns no results.

```dart
// ❌ Wrong - missing organizationId for nested collection
final record = await recordRepository.streamRecord<Group>(
  ModelType.group,
  groupId,
);

// ✅ Correct - includes organizationId
final record = await recordRepository.streamRecord<Group>(
  ModelType.group,
  groupId,
  organizationId: event.organizationId,
);
```

### 2. Inconsistent Seeding

**Problem**: Seeding scripts use different paths than app queries.

**Solution**: Always verify:
- Root collections are queried with proper `organizationId` filtering
- Nested collections use `organizations/{orgId}/` path

### 3. ProvenanceRepository vs. GenetRepository

Both manage genets but have different implementations:
- `GenetRepository`: Extends `InventoryRecordRepository`, overrides `collectionRef` to use nested path
- `ProvenanceRepository`: Standalone repository, must explicitly use `subcollection()`

## Adding New Collections

When adding a new collection type:

1. **Decide root vs. nested**: Prefer nested if data is organization-specific
2. **Update `_usesNestedCollection()`** in `BaseInventoryRecordRepository` if nested
3. **Update `_getCollectionRef()`** in `RecordRepository` if it will be queried there
4. **Document here** with the collection path
5. **Update seeding scripts** to use correct paths

## Taxonomy Overrides Governance

### Current State Analysis

**Discovery from Phase 0 Review**: `taxonomy_overrides` is used as a **GLOBAL shared configuration** collection, NOT org-scoped. Documents have fixed IDs like:
- `physical_form_size_overrides`
- `environmental_thresholds`
- `husbandry_schedules`

These are accessed WITHOUT `organizationId` in the codebase:
```dart
// base_repositories_provider.dart:193-194
final snapshot = await firestore
    .collection('taxonomy_overrides')
    .doc(_environmentalThresholdsDocId)  // No org scoping
    .get();
```

### Decision: Keep taxonomy_overrides GLOBAL

`taxonomy_overrides` should remain **GLOBAL** (not org-scoped) because:

1. **Current usage pattern**: All existing code accesses global doc IDs without org context
2. **Purpose**: These are app-wide configuration defaults, not per-org customizations
3. **Breaking change**: Making it org-scoped would require data migration + code changes to ALL access points

### Current Rules

| Environment | Rule Location | Behavior | Status |
|-------------|---------------|----------|--------|
| Production | `firestore.rules` | Authenticated read, admin-only write | ✅ Implemented |

**Community rules:** `firestore.community.rules` currently keeps `taxonomy_overrides` server-only (no client writes). Align with admin-only writes if community builds need client-side taxonomy admin.

**Future Consideration**: If per-org overrides are needed later, create a separate `organizations/{orgId}/taxonomy_overrides` subcollection.

## Related Files

- `lib/services/firestore_collection_resolver.dart` - Collection path resolution
- `lib/repositories/inventory/base_inventory_record_repository.dart` - Nested collection logic
- `lib/repositories/record_repository.dart` - Organization-aware record queries
- `lib/repositories/inventory/provenance_repository.dart` - Genet/provenance data
- `firestore.rules` - Security rules
