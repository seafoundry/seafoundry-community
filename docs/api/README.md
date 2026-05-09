# SeaFoundry Developer API Reference

**Last Updated**: 2026-01-13

SeaFoundry's backend is built on Firebase (Auth + Firestore + Cloud Functions) with public REST entry points for CSV ingestion, taxonomy administration, and inventory exports. Use this guide when integrating external services or building automation around the SeaFoundry data model.

---

## Environments & Tooling

| Name | Description | Notes |
| --- | --- | --- |
| `production` | Live customer data | Use service accounts and run migration scripts with extreme care. |
| `staging` | Full copy of production schema w/ sample data | Ideal for integration testing and partner pilots. |
| `emulator` | Local Firebase emulator (`localhost:58080` Firestore) | Seeded via `npm run seed:emulator` or targeted scripts. |

### CLI Essentials

```bash
# Install dependencies
npm install

# Authenticate with Firebase
firebase login --reauth

# Start emulator (Auth + Firestore + Storage)
npm run emulator:start

# Seed taxonomy/species/provenance data
npm run seed:taxonomy        # production/staging
npm run seed:taxonomy:emulator

# Run migrations
npm run migrate:event-organism-kind:plan   # Event metadata backfill
npm run migrate:facility-enums             # Site/group enum + organism defaults
```

---

## Firestore Collections

| Collection | Purpose | Highlights |
| --- | --- | --- |
| `organizations` | Org metadata and settings | Coral-only in community tier. |
| `sites` | Facilities (nurseries, outplanting sites) | Fields: `siteTypeId`, `geometry`. Site types: `nursery` and `outplanting` only. |
| `groups` | Structures inside a site (longlines, racks, tags, etc.) | Field: `groupTypeId`. |
| `taxonomy_species` | Canonical species definitions | See `TaxonomyService` for the consumer API. |
| `taxonomy_provenances` | Provenance records (genets, broodstock, cohorts) | Replaces legacy lineage fields. |
| `inventory_records` | Coral organism records | Includes `lifeStage`, `populationMeasurement`, provenance IDs. |
| `events` | Activity, observation, task, transfer events | `metadata.organismKind` and `recordModelType` identify context. |

All collection schemas align with the Flutter models under `lib/models/**`. Use those files as the canonical reference when building export/import scripts.

---

## Authentication & REST Access

- **Service Accounts** – Use `firebase-service-account.json` (or `FIREBASE_*` env vars) with the Admin SDK for server-to-server access.
- **User Tokens** – For user-facing integrations, obtain Firebase ID tokens via OAuth (handled by the SeaFoundry web/mobile clients) and include them in `Authorization: Bearer <token>` headers when calling Cloud Functions/REST endpoints.
- **App Check** – Production Cloud Functions enforce App Check. Register custom clients before calling protected endpoints.

---

## CSV & Import APIs

SeaFoundry’s CSV importer is exposed through:

1. **Admin UI** – Upload CSV v2 files directly from the Inventory workspace. Legacy v1 files are not supported.
2. **REST** – `POST /api/csv/import` (Cloud Function) accepts multipart CSV uploads. Headers: `Authorization`, `X-Organization-Id`. The function mirrors the UI importer pipeline.

Key files:
- `lib/services/csv/import/importers/inventory_csv_importer.dart`
- `docs/csv/csv_v2_migration.md` (schema and migration guidance)

---

## Export APIs

- `InventoryExportJob` (Cloud Function invoked via UI) produces CSV v2-compliant exports.
- `ExportService` (`lib/services/export/export_service.dart`) orchestrates the export flow inside the Flutter app.
- Firestore queries for exports rely on the normalized site/group enums; run the facility migration script before enabling exports for new organisms.

---

## Migration Scripts

Legacy migration scripts have been archived to `scripts/archive/backfills/` and `scripts/archive/migrations/`. The npm commands that referenced them (e.g., `migrate:event-organism-kind:plan`, `migrate:facility-enums`, `export:inventory:plan`) still exist in `package.json` but their target scripts are no longer at the original paths.

If you need to run a historical migration, check `scripts/archive/` for the relevant script and update the npm command path accordingly.

---

## Helpful References

- Taxonomy architecture: `docs/architecture/taxonomy/README.md`
- CSV v2 migration guide: `docs/csv/csv_v2_migration.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
