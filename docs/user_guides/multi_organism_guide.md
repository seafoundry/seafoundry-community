# SeaFoundry Multi-Organism User Guide

This guide explains how to enable kelp, oyster, seagrass, mangrove, and other organisms inside SeaFoundry, and how the organism-aware tooling (taxonomy service, repositories, CSV v2, dialogs, spreadsheets) fits together.

---

## 1. Enable Multi-Organism Support

| Step | Action | Notes |
| --- | --- | --- |
| 1 | **Seed taxonomy data** (`npm run seed:taxonomy` or `npm run seed:taxonomy:emulator`) | Installs canonical species & provenance documents referenced by CSV v2/importers. |
| 2 | **Normalize facilities** (`npm run migrate:facility-enums`) | Rewrites legacy site/group IDs and injects `supportedOrganismKinds` so dialogs/spreadsheets know which organisms are allowed at each facility. |
| 3 | **Configure organization defaults** (`Organization.supportedOrganismKinds`) | The org’s whitelist controls which organisms appear in selectors and in the `OrganismContext` provided by `RepositoriesProvider`. |
| 4 | **Review Site capabilities** (`SiteCapabilities.resolve(siteType)`) | Each site type maps to allowed structures, actions, permits, and default organism sets; use this as a checklist when onboarding new facilities. |

Once the steps above are complete, the app surfaces organism selectors automatically in spreadsheets, dialogs, and analytics views.

---

## 2. Working With Taxonomy

- **Species & provenances** live under `taxonomy_species` and `taxonomy_provenances`. Use the Taxonomy Admin Panel to search, add, or edit entries.
- **Provenance terminology** replaces legacy lineage fields everywhere (CSV v2, dialogs, exports). Backfill existing data with the `backfill_event_metadata.js` and facility migrations before enabling new organisms.
- **Docs for admins**:
  - Architecture & ADRs: `docs/architecture/taxonomy/README.md`
  - Task list: `docs/architecture/taxonomy/taxonomy_task_list.md`
  - Work tracking: `.github/issues/taxonomy-work-log-summary.md`

---

## 3. CSV Pipelines

- **Upgrade to CSV v2** using the [CSV v2 Migration Guide](../csv/csv_v2_migration.md). Key highlights:
  - Every row must provide `organismKind`, organism-appropriate `lifeStage`, and structured permit data.
  - Measurement units are explicit (value + unit).
  - Lineage columns are replaced with `provenanceId`/`provenanceKind`.
- **CSV v2 only**: legacy CSV v1 files are not supported.
- **Validation**: run `flutter test test/integration/multi_organism_workflow_test.dart` and the mixed nursery integration suite after updating any CSV templates or pipeline code.

---

## 4. UI & Workflow Coverage

| Area | Status |
| --- | --- |
| **Spreadsheets** (inventory, holdings, genetics, husbandry, monitoring, outplant) | Include organism selectors, hide coral-only filters when not applicable, and reuse the shared non-coral holdings loader. |
| **Dialogs** (monitoring, task, observation, transfer) | Show holdings previews + “coming soon” messaging when non-coral organisms are selected. Transfer initiations/acceptance short-circuit to placeholders until write flows ship. |
| **Repositories & services** | `RepositoriesProvider` builds `OrganismContext` instances per supported kind. Holding, cohort, and CSV services rely on the neutral models implemented in Pod A. |
| **Exports/Analytics** | `InventoryExportRowSource` and analytics screens read organism metadata from `OrganismContext` so exports retain the organism/life stage context. |

For outstanding tasks see the taxonomy checklist (Phases B–F).

---

## 5. Operational Runbook

1. **Before enabling a new organism**:
   - Seed taxonomy entries (species + provenances).
   - Run `npm run migrate:facility-enums` and the event metadata backfill for the relevant organizations.
   - Review permit templates and CSV v2 examples with field teams.
2. **During pilot deployments**:
   - Use a dedicated staging org with the organism whitelist enabled.
   - Collect CSV samples and run them through the importer pipeline.
   - Monitor logs from `HoldingRepository`, `InventoryCsvImporter`, and `InventoryExportRowSource`.
3. **Production rollout**:
   - Update organization settings to include the new organism.
   - Communicate the required site/group types (e.g., kelp farms require longlines, dropper lines).
   - Keep the migration guide and taxonomy docs handy for partners.

---

## 6. Support & Troubleshooting

- **Permit validation errors** – ensure every required permit column is populated, or explicitly set `permitProtectedArea=false`.
- **Structure mismatch** – confirm the site/group documents use the new enum IDs (rerun the facility migration if necessary).
- **CSV v1 submissions** – not supported; convert to v2 before upload.
- **Missing taxonomy data** – run `npm run seed:taxonomy` in the relevant environment (or use the admin panel) before importing CSVs that reference new species/provenances.

If you encounter issues, file a ticket with the failing CSV row or Firestore document ID plus the validation output so the taxonomy team can reproduce quickly.

---

## Related Resources

- Architecture & ADRs: `docs/architecture/taxonomy/README.md`
- Task list: `docs/architecture/taxonomy/taxonomy_task_list.md`
- Work tracking: `.github/issues/taxonomy-work-log-summary.md`
- CSV v2 migration guide: `docs/csv/csv_v2_migration.md`
- Facility enum migration: `scripts/migrations/backfill_facility_enums.ts`
- Event organism-kind backfill: `scripts/backfill_event_metadata.js`
