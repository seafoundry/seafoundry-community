# Genetics Module (Claude Notes)

## Guardrails
- Use `GenetRepository` for genet CRUD; it handles nested collections.
- Normalize local IDs and names via `UniqueNameValidationService`.
- For transfers, use the transfer dialogs and capture providers before
  `showDialog` calls.
- Keep `TransferCountCubit` wired to `EventRepository` for pending counts.

## Provenance ID System
- Single `provenanceId` field (format `PID-Gspec-XXX`). No separate `communityProvenanceId`.
- `ProvenanceLookupService` searches both crosswalk and alias_index for autocomplete.
- `ProvenanceSearchMixin` (in `lib/mixins/`) encapsulates debounce, stale-request guards, conflict detection. Used by both `GenetCreationBloc` and `OrganismCreationCubit`.
- `ProvenanceSearchState` (in `lib/models/`) tracks independent clonalId/accession matches with computed `hasConflict`, `resolvedProvenanceId`, `conflictMessage`.
- PID inheritance: `GenetRepository.createGenet(inheritedProvenanceId:)` skips counter increment and uniqueness check when a crosswalk-matched PID is passed.
- Species-scoped: all autocomplete searches require a species code. Changing species resets provenance state.
- Conflict resolution: when clonalId and accessionNumber resolve to different PIDs, submit is blocked with an error message.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Validate transfer workflows for non-coral organisms and holdings panels.
- Ensure transfer manifests preserve canonical provenance metadata.

## Touchpoints
- Screen: `lib/screens/genetics_screen.dart`
- Repos: `lib/repositories/inventory/genet_repository.dart`
- Transfer dialogs: `lib/widgets/dialogs/transfer/`
- Provenance: `lib/services/provenance_lookup_service.dart`, `lib/mixins/provenance_search_mixin.dart`
- Genet creation: `lib/widgets/dialogs/genet_creation/genet_provenance_section.dart`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.

## Identity Model (Critical Distinction)

### localId vs recordName
These two fields serve different purposes and MUST NOT be confused:

1. **`localId`** (Genet Identifier)
   - The genet/genetic lineage identifier (e.g., "ACER-001")
   - Maps directly to a Provenance ID (PID)
   - Associated with clonalID, alias, accession number via crosswalk
   - Shared by all organism records belonging to the same genet
   - Used in genetics tracking, transfers, and provenance systems

2. **`recordName`** (Friendly Distinguishing Adjective)
   - User-friendly name for a specific organism record instance
   - Examples: "Fluffy", "Nursery Fragment A"
   - Unique per record, not shared across genet
   - Should ALWAYS differ from localId
   - Used for human identification when multiple records share a genet

### Genet Resolution
- Always use `GenetIdResolver.resolve(record)` for canonical genet ID resolution
- Never access `foreignKeys['genetId']?.id` directly
- The genet's `name` field corresponds to `localId`
