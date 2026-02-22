# RecordName + LocalId Normalization and UID Auth Consistency

**Status**: 🔄 In Progress
**Priority**: P0 - Data model and UX alignment
**Labels**: `inventory`, `data-model`, `csv`, `auth`, `genet`, `ux`

## Summary
- Replace organismName with recordName everywhere (models/DTOs/CSV/export/import/UI).
- Require localId + recordName for all inventory records and holdings; recordName is primary label.
- RecordName defaults to adjective-localId with unique adjective per record and uniqueness enforced org-wide.
- Use UID-based user docs everywhere (`/users/{uid}`); email used only for invitations.
- Update search/results/event cards/spreadsheets and genet profile to surface recordName + localId with navigation links.
- Seed data to demonstrate family trees for APAL/ACER.
- Ensure organism graph node shows species reference thumbnails and observation image gallery.

## Decisions
- Auth user doc IDs: UID only. No email-keyed user docs; invitations remain email-based.
- localId required for all inventory records; recordName required and primary label.
- recordName unique within org; adjective prefix unique per record; random adjective pool must not repeat within org.
- recordName click -> organism GraphNode; localId click -> Genet profile.
- CSV uses recordName column (recordName / record_name), no organism_name aliases.

## Progress
- Updated CSV v2 spec/schema + adapters/importers/exporters for recordName/localId.
- Updated UI surfaces (search, event cards, inventory/holdings/outplant/monitoring spreadsheets) to show recordName + localId with links.
- Added RecordNameLink/GenetIdLink helpers and recordName formatting utilities.
- Updated recordName validation/suggestion logic (unique adjectives, suffixing per-localId) + recordName fallback.
- Updated organism/holding models and creation flows to require localId + recordName.
- Enhanced Genet profile with record lists, summaries, and genetic tree visualization.
- Integrated species reference thumbnails + observation image gallery for organism cards.
- Normalized auth to UID-based user docs; updated rules, storage rules, docs, and scripts; removed email-migration artifacts.
- Updated seed scripts to generate recordName/localId for all inventory/holdings and build APAL/ACER family trees.
- Genet profile resolves by record ID or localId; localId links now always route to genet profiles.

### Workstream A Update (Pending Review Notes)
- Record-name handling now normalizes local IDs and tracks suffixes per-genet for uniqueness in `lib/services/unique_name_validation_service.dart`.
- Record name suggestions pull from adjective list and only suffix when that localId/adjective pair was previously used in `lib/utils/record_name_suggester.dart`.
- Collection flow auto-suggests record names via the same service in `lib/widgets/dialogs/organism_collection_dialog.dart`.
- Genetics CSV import auto-generates missing record names + requires resolvable localId for coral rows in `lib/services/csv/import/importers/genetics_csv_importer.dart`.
- Holding creation + fixtures updated to include recordName/localId requirements across unit/integration tests.

## Remaining Workstreams
### QA + release
- [ ] Run `flutter analyze` and targeted tests.
- [ ] Fix failures and update fixtures if needed.
- [ ] Reseed demo data, rebuild, redeploy web, then run full CI.

## References
- `lib/models/inventory/organism_record.dart`
- `lib/services/csv/adapters/universal_csv_adapter_v2.dart`
- `lib/services/csv/import/importers/inventory_csv_importer.dart`
- `lib/services/csv/import/importers/genetics_csv_importer.dart`
- `lib/services/export/inventory_export_row_formatter.dart`
- `lib/widgets/common/organism_reference_links.dart`
- `lib/widgets/spreadsheet/monitoring_spreadsheet.dart`
- `lib/services/unique_name_validation_service.dart`
- `lib/utils/record_name_suggester.dart`
- `scripts/seed-demo.js`
- `scripts/seed-non-coral-holdings.js`
- `firestore.rules`
- `storage.rules`
