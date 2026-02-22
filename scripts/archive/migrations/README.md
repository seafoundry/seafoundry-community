# Archived Migration Scripts

One-time migration scripts that have been executed and should not be run again.
Preserved for historical reference and audit purposes.

**DO NOT RUN THESE SCRIPTS** - they were designed for one-time data migrations.

## Archived Scripts

- `migrate_corals_to_organisms.js` - Migrated Coral model to OrganismRecord
- `migrate_event_type_aliases.js` - Migrated event type aliases
- `migrate_registry_ids.js` - Migrated registry IDs
- `migrate-coral-types.js` - Migrated coral type fields
- `migrate-createdEvent-recordModelType.js` - Added recordModelType to createdEvent
- `migrate-death-to-population-loss.js` - Renamed death events to population loss
- `migrate-events-recordModelType.js` - Added recordModelType to event documents
- `migrate-geometry-backfill.js` - Backfilled geometry data
- `migrate-moveEvents-snapshotData.js` - Added snapshotData to move events

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
