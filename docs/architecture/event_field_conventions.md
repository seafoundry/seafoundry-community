# Event Field Conventions

**Last Updated:** 2026-01-08

This document describes the required and optional fields for event records in SeaFoundry.

## Required Fields (All Events)

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier for the event |
| `modelType` | String | Must be `"event"` |
| `eventTypeId` | String | Event type identifier (see Event Types below) |
| `organizationId` | String | ID of the owning organization |
| `urlPath` | String | Hierarchical path (e.g., `demo-seafoundry/site-a/tank-a/evt123`) |
| `createdAt` | String (ISO8601) | Creation timestamp |
| `createdById` | String | User ID who created the event |

## Common Event Types

### Inventory Events

These events track changes to organism inventory:

| eventTypeId | Description | Special Fields |
|-------------|-------------|----------------|
| `event_create` | New organism/genet created | `snapshotData` |
| `event_move_in` | Organism moved into container | `snapshotData`, `fromUrlPath`, `toParentId` |
| `event_move_out` | Organism moved out of container | `snapshotData`, `fromUrlPath`, `toUrlPath` |
| `event_frag` | Fragmentation event | `snapshotData`, `inputOrganismIds`, `outputOrganismIds` |
| `event_population_gain` | Population increase | `snapshotData`, `quantity` |
| `event_population_loss` | Population decrease/mortality | `snapshotData`, `quantity`, `lossReasonId` |
| `outplant_event` | Organisms outplanted | `snapshotData`, `siteId`, `allocations`, `deliverableId`, `attachmentMethodId` |

### Observation Events

| eventTypeId | Description | Special Fields |
|-------------|-------------|----------------|
| `event_observation` | General observation | `comment`, `healthStatus` |
| `event_disease_observation` | Disease detected | `diseaseId`, `severity` |
| `event_thermal_stress_observation` | Thermal stress | `stressLevel` |

## OutplantEvent Fields

The `outplant_event` type has several special fields for tracking organism outplanting to sites.

### Required OutplantEvent Fields

| Field | Type | Description |
|-------|------|-------------|
| `siteId` | String | Target site ID for outplanting |
| `allocations` | List | Array of organism allocations (organismId, quantity) |

### Optional OutplantEvent Fields (Added 2026-01-08)

| Field | Type | Description |
|-------|------|-------------|
| `deliverableId` | String? | Links outplant event to a permit Deliverable for tracking |
| `attachmentMethodId` | String? | Method used to attach organisms (builtin or custom) |

### Attachment Method IDs

**Builtin Methods:**
| ID | Name | Description |
|----|------|-------------|
| `attachment_method_nail` | Nail | Metal nail or spike attachment |
| `attachment_method_cement` | Cement | Marine cement or epoxy putty |
| `attachment_method_epoxy` | Epoxy | Two-part epoxy adhesive |
| `attachment_method_substrate` | Substrate | Natural substrate placement |

**Custom Methods:** Custom attachment methods use the prefix `custom_attach_` (e.g., `custom_attach_wire_tie`).

### OutplantEvent Example

```javascript
{
  id: 'evt_outplant_123',
  modelType: 'event',
  eventTypeId: 'outplant_event',
  organizationId: 'org_xyz',
  urlPath: 'demo-seafoundry/site-a/evt_outplant_123',
  createdAt: '2026-01-08T10:30:00Z',
  createdById: 'user_abc',
  // Required outplant fields
  siteId: 'site_reef_one',
  allocations: [
    { organismId: 'org_001', quantity: 5 },
    { organismId: 'org_002', quantity: 3 }
  ],
  // Optional enhancement fields
  deliverableId: 'deliverable_permit_2026',  // Optional: link to permit deliverable
  attachmentMethodId: 'attachment_method_cement'  // Optional: attachment method used
}
```

See `docs/OUTPLANT_DIALOG_ENHANCEMENT_IMPLEMENTATION.md` for full implementation details.

---

## Snapshot Data Field

### Critical: Use `snapshotData`, NOT `snapshot`

For inventory events, the organism/record snapshot MUST be stored in a field called `snapshotData`, not `snapshot`.

```javascript
// ❌ WRONG - will cause parsing errors
{
  eventTypeId: 'event_create',
  snapshot: { id: 'org1', slug: 'ACER-001', ... }  // Wrong field name!
}

// ✅ CORRECT
{
  eventTypeId: 'event_create',
  snapshotData: { id: 'org1', slug: 'ACER-001', modelType: 'organismRecord', ... }
}
```

### Required snapshotData Fields

The `snapshotData` object should contain:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Record ID |
| `modelType` | Yes | `'organismRecord'` for organisms, `'genet'` for genets |
| `slug` | Yes | Display identifier (e.g., 'ACER-001') |
| `speciesId` | Yes | Species identifier |
| `organizationId` | Yes | Organization ID |

Example snapshotData:

```javascript
snapshotData: {
  id: 'organism_abc123',
  modelType: 'organismRecord',
  slug: 'ACER-001',
  speciesId: 'ACER',
  organizationId: 'org_xyz',
  groupId: 'group_tank_a',
  groupName: 'Tank A',
  quantity: 5,
  lifeStage: 'fragment',
  physicalForm: 'fragment'
}
```

## Record Model Type

### Use `organismRecord`, NOT `coral`

For organism-related events, use `recordModelType: 'organismRecord'`:

```javascript
// ❌ WRONG - legacy type, will cause lookup failures
{
  eventTypeId: 'event_create',
  recordModelType: 'coral',  // Wrong!
  recordId: 'org123'
}

// ✅ CORRECT
{
  eventTypeId: 'event_create',
  recordModelType: 'organismRecord',
  recordId: 'org123'
}
```

## Common Errors and Solutions

### "snapshotData keys: not a map"

**Cause**: `snapshotData` field is missing or not a Map object.

**Solution**: Ensure every inventory event has a `snapshotData` field containing a Map with the required organism/record fields.

### "Record snapshot missing for coral..."

**Cause**: Event has `recordModelType: 'coral'` but organisms are stored as `organismRecord`.

**Solution**: Use `recordModelType: 'organismRecord'` for organism events.

### "Unknown event type: undefined"

**Cause**: `eventTypeId` field is missing from the event JSON.

**Solution**: Every event must have an `eventTypeId` field with a valid event type string.

### Event not showing in UI

**Cause**: Often due to `urlPath` mismatch between event and the node being viewed.

**Solution**: Ensure event `urlPath` is a descendant of the viewing node's path. For example, an event at `demo-seafoundry/site-a/tank-a/evt123` will show when viewing `demo-seafoundry/site-a/tank-a` or any ancestor.

## Seeding Script Examples

### Create Event

```javascript
const createEvent = {
  id: `evt_create_${organism.id}`,
  modelType: 'event',
  eventTypeId: 'event_create',
  recordModelType: 'organismRecord',
  recordId: organism.id,
  organizationId: ORG_ID,
  urlPath: `${ORG_URL_PATH}/${eventSlug}`,
  internalPath: `${ORG_INTERNAL_PATH}/${eventId}`,
  slug: eventSlug,
  createdAt: now,
  createdById: USER_ID,
  updatedAt: now,
  updatedById: USER_ID,
  snapshotData: {
    id: organism.id,
    modelType: 'organismRecord',
    slug: organism.slug,
    speciesId: organism.speciesId,
    organizationId: ORG_ID,
    groupId: organism.groupId,
    groupName: organism.groupName,
    quantity: organism.quantity,
    lifeStage: organism.lifeStage,
    physicalForm: organism.physicalForm
  }
};
```

### Observation Event

```javascript
const observationEvent = {
  id: `evt_obs_${Date.now()}`,
  modelType: 'event',
  eventTypeId: 'event_observation',
  recordModelType: 'organismRecord',
  recordId: organism.id,
  organizationId: ORG_ID,
  urlPath: `${organism.urlPath}/${eventSlug}`,
  internalPath: `${organism.internalPath}/${eventId}`,
  slug: eventSlug,
  createdAt: now,
  createdById: USER_ID,
  updatedAt: now,
  updatedById: USER_ID,
  // Note: 'comment' not 'notes' for observation text
  comment: 'Healthy growth observed',
  healthStatus: 'healthy',
  snapshotData: {
    id: organism.id,
    modelType: 'organismRecord',
    slug: organism.slug,
    // ... other required fields
  }
};
```

## Related Files

- `lib/models/factories/event_factory.dart` - Event parsing logic
- `lib/models/events/event.dart` - Event classes including OutplantEvent
- `lib/models/events/event_mixins.dart` - SnapshotEvent mixin with `snapshotFromJson()`
- `lib/models/events/inventory_event.dart` - Base class for inventory events
- `lib/models/types/attachment_method.dart` - Builtin attachment methods (4)

