# SeaFoundry CSV v2 Migration Guide

This guide helps data teams and project administrators move existing coral CSV pipelines, templates, and datasets to the **SeaFoundry Universal CSV v2** schema. It complements the canonical spec (`SeaFoundry_Universal_CSV_v2_spec.json`) and the working examples under `docs/csv/fixtures/v2/`.

---

## Who Should Read This

- **Partner organizations** that submit inventory data via CSV.
- **Internal ops / deployment teams** responsible for validating incoming data before import.
- **Developers** wiring CSV import/export features who need a concise checklist of the schema changes.

---

## Summary of Changes in CSV v2

- **Organism metadata** is now explicit: every row includes `organismKind` plus organism-appropriate `lifeStage` values (see `lib/models/types/life_stage.dart`).
- **Five-axis metadata** is first-class: rows can capture `provenanceType`, `physicalFormId`, `sizeBandId`, and `sizeClass` so imports preserve the canonical `OrganismRecord` payload.
- **Site compliance context** is standardized via the `siteJurisdiction`, `habitatType`, and `protectedAreaFlag` columns.
- **Measurement units** are encoded with `quantityValue` + `measurementUnit`, replacing legacy assumptions with explicit unit types.
- **Geometry and structure identifiers** (site, group, enclosure, etc.) are normalized into shared columns.
- **Provenance terminology** replaces legacy lineage fields. CSV v2 stores `provenanceId`, `provenanceKind`, and `accessionId`.
- **CSV translation tooling** (the universal adapter + upgrade service) now validates organism-aware constraints and produces descriptive errors.

### Common Field Mapping

| CSV v1 Column           | CSV v2 Equivalent                        | Notes |
|-------------------------|-------------------------------------------|-------|
| `coralType`             | `lifeStage`                               | Use coral life-stage values (`recruit`, `juvenile`, `adult`, `fragment`, etc.). |
| `count`, `mass`, etc.   | `quantityValue`, `measurementUnit`       | Units must match the organism context; see spec metadata. |
| `lineageId` / `lineage` | `provenanceId`, `provenanceKind`          | Accepts IDs from the taxonomy service (`taxonomy_provenances`). |
| _(new)_                 | `provenanceType`, `physicalFormId`, `sizeBandId`, `sizeClass` | Optional but recommended for every row so fragments inherit the canonical five-axis payload captured in dialogs and transfer manifests. |
| `structureType`         | `groupTypeId` / `structurePath`           | Aligns with the Site/Group enums introduced in ADR-002. |
| `siteType` (free text)  | `siteTypeId` (enum)                       | Must match `lib/models/types/site_type.dart` identifiers. |

Refer to the spec for the full column list and validation rules.

---

## Canonical Species IDs

SeaFoundry CSV imports (legacy v1 adapters, the v1→v2 upgrade utility, and the native v2 adapter) now require the **canonical taxonomy document ID** for every `speciesId` value. The canonical IDs come directly from the `taxonomy_species/{speciesId}` document (for example, `species_acropora_cervicornis`) and are what the importer persists in Firestore. Human-friendly species codes such as `APAL` or `ACER` still appear in partner-facing templates via the `speciesCode` column, but they are no longer accepted in the `speciesId` field after translation.

To stay aligned:

- Seed or sync the taxonomy collections before running any CSV import so the `SpeciesRegistry` mirrors the latest IDs (`SpeciesRegistry.globalMap()` drives all adapter lookups).
- When generating CSVs programmatically, fetch the canonical ID from the taxonomy API or `SpeciesRegistry.byId`/`byCode` helpers and write that value into `speciesId`.
- If you only have a scientific name or species code, rely on the adapters: they accept the legacy inputs, resolve them through the registry, and emit the canonical `speciesId` in the translated payload. Downstream importers will reject rows that still contain non-canonical identifiers.

This rule keeps organism-record services consistent and avoids mixing historical shorthand IDs inside Firestore.

---

## Migration Workflow

### 1. Prepare Taxonomy + Facilities

1. **Seed taxonomy collections:** Run `npm run seed:taxonomy` (or `npm run seed:taxonomy:emulator`) so every environment exposes the species/provenance IDs referenced by CSV v2.
2. **Normalize facility documents:** Execute `npm run migrate:facility-enums` to rewrite legacy `siteTypeId`/`groupTypeId` values. This guarantees that validations inside the CSV importer have the correct metadata.

### 2. Update Templates & Documentation

1. Distribute the refreshed coral template in `docs/csv/examples/`, which already follows the v2 contract.
2. Share this guide plus the canonical spec with field teams so they can update their data capture workflows.

### 3. Convert Existing CSV Files

CSV v1 files are no longer supported. Convert legacy files to the v2 schema
before import using your own tooling, then validate the output with the v2
fixtures and schema guide in this document.

### 4. Validate

- Run relevant CSV integration tests to ensure coral imports succeed.
- Use the emulator to exercise the end-to-end CSV pathway locally.
- Spot-check imported records in the app to verify measurement units and organism labels render correctly.

### 5. Deploy & Monitor

1. Re-run the CSV importer in staging with real partner files and review the validation output.
2. Toggle feature flags / UI copy to mention the v2 schema once you’re confident the data looks correct.
3. Monitor `HoldingRepository` and `InventoryExportRowSource` logs during the first production uploads to ensure organism metadata propagates through exports.

---

## Troubleshooting

| Symptom | Resolution |
|---------|------------|
| **`Unsupported organismKind`** | Confirm the CSV row uses one of the `OrganismKind` enum values. For legacy files, rely on the adapter’s defaulting logic or manually add the column. |
| **Structure mismatch** | Ensure `groupTypeId`/`siteTypeId` are pulled from the new enums. Run the facility enum migration if existing Firestore docs still use legacy IDs. |
| **Lineage IDs rejected** | Migrate them to taxonomy provenances (seed the collection first, then update CSV rows to reference `provenanceId`). |

If issues persist, attach the failing CSV row plus the validation output when filing an issue so the data team can reproduce quickly.

---

## References

- `SeaFoundry_Universal_CSV_v2_spec.json` (schema + validation rules)
- CSV fixtures under `docs/csv/fixtures/v2/`
- Migration tooling:
  - `lib/services/csv/import/importers/inventory_csv_importer.dart`
  - `lib/services/csv/import/csv_import_coordinator.dart`

Keep this guide alongside partner-facing documentation so every CSV submission uses the same contract.
