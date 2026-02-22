# Multi-Organism API Notes

SeaFoundry’s REST + Firestore APIs expose the same neutral models used by the Flutter app. This document summarizes the key resources, fields, and migration considerations so backend-integrations and external partners can consume or publish multi-organism data safely.

---

## 1. Inventory & Taxonomy Models

| Model | Collection / Document | Highlights |
| --- | --- | --- |
| `SpeciesRecord` | `taxonomy_species/{speciesId}` | Fields: `organismKind`, `genus`, `species`, `code`, `commonNames`, `propagationModes`, `metadata`. |
| `ProvenanceRecord` | `taxonomy_provenances/{provenanceId}` | Fields: `organismKind`, `provenanceKind`, `displayName`, `speciesId`, `parentProvenanceId`, `siteId`, `metadata`. |
| `HoldingRecord` | `inventory_records/{holdingId}` | Neutral holdings (seeded-line batches, gametes, larvae). Includes `lifeStage`, `provenanceId`, `populationMeasurement`, `supportedOrganismKinds`. |
| `Site` | `sites/{siteId}` | Now persists `siteTypeId` (enum) + `supportedOrganismKinds` (copied from `SiteCapabilities` or org defaults.) |
| `Group` | `groups/{groupId}` | Uses `groupTypeId` enum plus new group metadata for kelp/oyster structures (longlines, dropper lines, racks, etc.). |

### Enum Governance

- Site type IDs live in `lib/models/types/site_type.dart`.
- Group type IDs live in `lib/models/types/group_type.dart`.
- `OrganismKind` metadata describes default measurement units, life stages, and supported site/structure types (`lib/models/types/organism_kind.dart`).

When integrating directly with Firestore, use these IDs verbatim; the facility migration script (`npm run migrate:facility-enums`) can normalize older documents automatically.

---

## 2. Service Layer Entry Points

| Service | File | Purpose |
| --- | --- | --- |
| `RepositoriesProvider` | `lib/widgets/repositories/repositories_provider.dart` | Builds `OrganismContext` instances per supported organism and wires repositories/cubits with the correct context. |
| `TaxonomyService` | `lib/services/taxonomy_service.dart` | Cached Firestore accessor for species + provenance documents (used by dialogs, CSV importers, and taxonomy admin tooling). |
| `InventoryCsvImporter` | `lib/services/csv/import/importers/inventory_csv_importer.dart` | Handles CSV v2 rows, including organism validation, measurement units, permit metadata, and provenance IDs. |
| `OrganismHoldingLoader` | `lib/services/organism_holding_loader.dart` | Aggregates holdings across non-coral organisms so dialogs/spreadsheets can render a consistent preview panel. |
| `EventPropagationService` | `lib/services/event_propagation_service.dart` | Ensures propagated events carry `metadata.organismKind` for downstream consumers. |

---

## 3. REST / Firestore Contract Changes

1. **Event metadata** – `events/{eventId}` now stores `metadata.organismKind`. Use the `backfill_event_metadata.js` script (or `npm run migrate:event-organism-kind:plan`) to normalize existing events before relying on the field.
2. **Facility documents** – `sites` and `groups` use the new enum IDs; `supportedOrganismKinds` is required for sites. Run `npm run migrate:facility-enums` to patch legacy docs.
3. **CSV uploads** – All ingestion now assumes the CSV v2 schema. See `docs/csv/csv_v2_migration.md` for the column mapping and upgrade workflow.
4. **Taxonomy Admin API** – When creating new species/provenances programmatically, populate the organism kind and provenance type fields so the taxonomy service can hydrate the Flutter app without custom lists.

---

## 4. Integration Checklist

1. Ensure `supportedOrganismKinds` is set on the organization document; `RepositoriesProvider` uses this to seed contexts.
2. Seed taxonomy data in every environment (production, staging, emulator) before running CSV imports or tests.
3. Run both migration scripts whenever enabling a new organism:
   - `npm run migrate:event-organism-kind:plan`
   - `npm run migrate:facility-enums`
4. Prefer the v2 CSV adapters/importers for any automated ETL jobs (see `lib/services/csv/v2`).
5. When consuming Firestore data externally, key off `metadata.organismKind` and the site/group enums to determine which UX/actions to expose.

---

## 5. References

- Taxonomy architecture & ADRs – `docs/architecture/taxonomy/README.md`
- Task list – `docs/architecture/taxonomy/taxonomy_task_list.md`
- Work tracking – `.github/issues/taxonomy-work-log-summary.md`
- Multi-organism user guide – `docs/user_guides/multi_organism_guide.md`
- CSV v2 migration guide – `docs/csv/csv_v2_migration.md`
