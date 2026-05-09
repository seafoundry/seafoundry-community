# Management Dialog Architecture

## Overview

The management dialog system provides a unified pattern for inventory management operations (edit properties, edit identity, edit physical form, remove/archive) for coral organism records.

## Current Architecture

### Management Dialog Mode Enum

```dart
enum OrganismManagementMode {
  editProperties,   // Life stage, quantity, physical form, aliases, ownership
  editIdentity,     // LocalId, recordName, clonal ID, accession, provenance
  editPhysicalForm, // Physical form and size band
  remove,           // Archive/remove with reason tracking
}
```

### Management Dialogs

| Dialog | Operations | Status |
|--------|-----------|--------|
| `OrganismManagementDialog` | `editProperties`, `editIdentity`, `editPhysicalForm`, `remove` | Complete |
| `GenetManagementDialog` | Remove, aliases, split, merge | Complete |
| `BatchManagementDialog` | Split, combine, graduate | Complete (service-based pattern) |

### How Editing Works

All property/identity/physical-form editing flows through `OrganismRecordEditDialog` via `OrganismManagementMode`:

- **`editProperties`** opens the full `OrganismRecordEditDialog` (life stage, quantity, physical form, aliases, ownership, size metrics)
- **`editIdentity`** opens `OrganismRecordEditDialog` scoped to `OrganismRecordEditScope.identityOnly` (localId, recordName, clonal ID, accession number, provenance)
- **`editPhysicalForm`** opens `OrganismRecordEditDialog` scoped to `OrganismRecordEditScope.physicalFormOnly`
- **`remove`** opens the removal dialog backed by `OrganismRemovalCubit`

### Backing Cubits

```
lib/blocs/organism_record_edit/
  organism_record_edit_cubit.dart   # Property/identity editing (OrganismRecordEditDialog)
  organism_record_edit_state.dart

lib/cubits/
  genet_edit_name/                  # Genet rename (GenetManagementDialog)
  genet_removal/                    # Genet removal
  organism_removal/                 # Organism removal/archival
  structure_edit_name/              # Structure (site/group) rename
```

### Save Flow

The `OrganismManagementDialog` wires `onSubmit` to `repository.updateRecordWithEvents()`, which:
1. Detects all changes via `OrganismRecordChangeService`
2. Emits typed events for each change (life stage, physical form, size, quantity, aliases, ownership)
3. Commits record update + events atomically in a single batch

After the repository save, `OrganismRecordEditCubit._emitIdentityChangeEvents()` emits identity-specific events (recordNameChange, localIdChange, genetIdentityChange, ownershipChange) with structured metadata for audit tracking.

### Component Map

```
lib/widgets/dialogs/
  organism_management_dialog.dart     # Unified entry point with mode enum
  organism_record_edit_dialog.dart    # Property/identity edit surface
  batch_management_dialog.dart        # Batch operations (different pattern)
  genet_management_dialog.dart        # Genet-specific operations

lib/blocs/organism_record_edit/       # Property/identity edit cubit
lib/cubits/organism_removal/          # Organism removal cubit
lib/cubits/genet_removal/             # Genet removal cubit
lib/cubits/genet_edit_name/           # Genet rename cubit
lib/cubits/structure_edit_name/       # Structure rename cubit
```

## Gap Analysis

| Feature | Organism Records | Genet | Structures |
|---------|-----------------|-------|------------|
| Edit properties | Via OrganismRecordEditDialog | N/A | N/A |
| Edit identity | Via OrganismRecordEditDialog (identity scope) | Via GenetManagementDialog | Via StructureEditNameCubit |
| Edit physical form | Via OrganismRecordEditDialog (physical form scope) | N/A | N/A |
| Remove/archive | Via OrganismRemovalCubit | Via GenetRemovalCubit | N/A |
| Batch operations | Via BatchManagementDialog | Via BatchManagementDialog | N/A |

## Extension Points

- Add more operations (transfer, propagation) via new `OrganismManagementMode` values
- Structure management dialogs for sites and groups
- Spreadsheet inline editing can delegate to the same management dialog
