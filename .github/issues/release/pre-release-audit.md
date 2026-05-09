# Pre-Release Audit

**Status**: 🟡 Triage
**Priority**: P0 — Release Readiness
**Labels**: `release`, `audit`, `quality`, `tech-debt`

## Overview

Audit of 1,779 Dart files surfaced stability risks, incomplete workflows, and
coverage gaps. This issue tracks remediation and structures the parallel
workstreams required to reach release readiness.

## Immediate Focus (Week 1)

- Audit dialog provider patterns to prevent "Provider not found" crashes.
- Replace empty catch blocks with `LoggingService` to restore error visibility.

## Workstreams (Parallel)

### Workstream 1: Stability, Safety, Error Visibility
**Goal**: Prevent silent failures and dialog crashes.

- [x] Replace empty catch blocks with `LoggingService`:
  - `lib/widgets/historical/provenance_detail_modal.dart`
  - `lib/screens/public/public_holdings_map_screen.dart`
- [x] Audit `showDialog` + `context.read` usage (71 files) and align with
  `lib/widgets/dialogs/base/dialog_base.dart`.
- [x] Reduce force-unwrap hotspots (4,627 `!` instances); start with
  `lib/widgets/dialogs/filtered_organism_list_sheet.dart` and dialog-heavy
  files.
- **Team 1 progress**:
  - Dialogs: aligned `showDialog` calls with DialogBase patterns and set
    `useRootNavigator: false` to keep provider scopes stable.
  - Dialogs: `TransferDialog` now uses
    `DialogBase.showDialogWithProviders` with injected `NavigationCubit`,
    `TransferService`, and `OrganizationRepository`.
  - Null-safety: removed force-unwraps in dialog flows
    (`lib/widgets/dialogs/filtered_organism_list_sheet.dart`,
    `lib/widgets/dialogs/validation_rule_edit_dialog.dart`).
  - Logging: restored error visibility with `LoggingService.warn` in
    provenance modal and public holdings map.
  - Tests: `flutter test --tags unit` (pass).

### Workstream 2: Workflow Coverage & Feature Completion
**Goal**: Remove "coming soon" blockers for community workflows.

- [x] Core community workflows:
  - Transfers: `lib/widgets/dialogs/transfer/*.dart`
  - Outplanting: `lib/widgets/dialogs/outplant_batch_dialog.dart`
  - Inventory: `lib/widgets/graph_node/actions/inventory_tiles_builder.dart`
  - Onboarding: `lib/screens/onboarding/organization_setup_page.dart`
- [x] Data import/export gaps:
  - Onboarding CSV import: `lib/screens/onboarding/data_import_page.dart`
- [x] Bulk action stubs in
  `lib/widgets/graph_node/actions/bulk_action_executors.dart`.
- [x] Other incomplete features:
  - Tag persistence: `lib/services/outplanting_service.dart`
  - Event history service injection:
    `lib/widgets/event_history/event_history_widget.dart`
  - Public impact map data:
    `lib/widgets/public/public_impact_map_section.dart`
  - GitHub repo link:
    `lib/screens/auth/community_auth_screen.dart`
- **Team 2 progress**:
  - Completed community workflow dialogs for transfer, outplant, inventory,
    and onboarding.
  - Implemented onboarding CSV import.
  - Implemented bulk action executors for quantity and size workflows.
  - Added outplant tag persistence and event history service fallback.
  - Removed remaining placeholders: public impact map empty state and
    GitHub repo link.

### Workstream 3: Technical Debt & Architecture
**Goal**: Reduce maintenance risk and improve modularity.

- [x] Decompose large files:
  - [x] `lib/services/transfer_service.dart` (115 lines) → split into
    `lib/services/transfer_service_initiation.dart` (767),
    `lib/services/transfer_service_acceptance.dart` (1,310),
    `lib/services/transfer_service_manifest.dart` (784),
    `lib/services/transfer_service_validation.dart` (546)
  - [x] `lib/widgets/dialogs/outplant_batch_dialog.dart` (585 lines) →
    extracted UI components into:
    `lib/widgets/dialogs/outplant_batch_dialog_sections.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_site.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_deliverable.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_attachment.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_schedule.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_organisms.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_metrics.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_permit.dart`,
    `lib/widgets/dialogs/outplant_batch_dialog_notes.dart`
  - [x] `lib/widgets/navigation/summary_statistics.dart` (292 lines) → split tab
    components into:
    `lib/widgets/navigation/summary_statistics_cards.dart`,
    `lib/widgets/navigation/summary_statistics_data.dart`,
    `lib/widgets/navigation/summary_statistics_inventory_tab.dart`
  - [x] `lib/services/csv/adapters/universal_csv_adapter_v2.dart` (674 lines)
    → `lib/services/csv/adapters/universal_csv_adapter_v2_mapper.dart` (1,144),
    `lib/services/csv/adapters/universal_csv_adapter_v2_validator.dart` (227),
    `lib/services/csv/adapters/universal_csv_adapter_v2_parser.dart` (221)
  - [x] `lib/blocs/outplant_batch/outplant_batch_bloc.dart` — decomposed into
    handler and loader part files
  - [x] `lib/repositories/inventory/event_repository.dart` (36 lines) →
    `lib/repositories/inventory/event_repository_helpers.dart` (115),
    `lib/repositories/inventory/event_repository_history.dart` (237),
    `lib/repositories/inventory/event_repository_mutations.dart` (818),
    `lib/repositories/inventory/event_repository_queries.dart` (692)
  - [x] `lib/widgets/repositories/repositories_provider.dart` (1,571 lines) →
    reduce coupling (imports down to 23)
- [x] Reduce import coupling:
  - `lib/widgets/repositories/repositories_provider.dart` (23 imports)
  - `lib/widgets/navigation/wrapped_navigator.dart` (18)
  - `lib/screens/admin/organization_structure_screen.dart` (26)
  - `lib/widgets/repositories/community_repositories_provider.dart` (20)
  - `lib/widgets/dialogs/outplant_batch_dialog.dart` (33)
- [x] Complete Bloc → Cubit migration (no remaining `extends Bloc` usages in
  `lib/`; only `BlocObserver` + `BlocBase` references).
- [x] Remove deprecated code (no remaining `@Deprecated` annotations in `lib/`;
  `SizeSpec` deprecations removed, legacy JSON parsing retained).
- [x] Workteam 3 triage:
  - Captured line/import counts for split/coupling targets (details above).
  - Located LifeStageProgression* wiring in
    `lib/widgets/repositories/repositories_provider.dart`,
    `lib/widgets/repositories/community_repositories_provider.dart`, and
    `lib/navigation/wrapped_navigator.dart`.
  - `lib/screens/admin/operations_admin_screen.dart` has no direct references
    by name (rg); pending route audit.
  - Split summary stats into tab components and reduced outplant batch dialog
    imports (54 → 33).
  - Split transfer service, universal CSV adapter v2, outplant batch bloc, and
    event repository into part files (updated line counts above).

### Workstream 4: Test Coverage & CI Health
**Goal**: Raise coverage and stabilize CI confidence.
**Owner**: Workteam 4
**Progress**:
- [x] Triaged skipped tests and confirmed blockers in code TODOs:
  - `test/blocs/graph_node/graph_node_bloc_test.dart`: reload path fails to emit a second loaded state (loadSequence stays 1).
- [x] Fixed skipped tests with deterministic setup/listeners.
- [x] Added unit/widget coverage for providers, theme, errors, constants, navigation, and forms.

- [x] Fix skipped tests:
  - `test/blocs/graph_node/graph_node_bloc_test.dart`
- [x] Add tests for untested areas:
  - `lib/providers/`
  - `lib/theme/`
  - `lib/errors/`
  - `lib/constants/`
  - `lib/navigation/`
  - `lib/forms/`
- [ ] Coverage targets:
  - Cubits: 17% → 35%
  - Screens: 6% → 20%
  - Services: 38% → 50%

## Release Gates

- [x] No empty catch blocks; logging present.
  - Verified: No empty catch blocks in `lib/`
- [x] Dialog provider pattern audit complete.
  - Verified: No `showDialog` + inline `context.read` patterns
- [x] Skipped tests resolved or removed with justification.

## Audit Log

### 2026-01-23 Comprehensive Audit

**Commits Analyzed**: b9b02306, c8e9f436, 58cb260d, 4607cee6

**Key Improvements Found**:
- Permission system simplified: `isAdmin` field removed, computed from role
- Dead code removed: 357 lines in `permission_mixin.dart`
- UID-based identity migration completed
- Export service canonicalization implemented

**Architecture Decomposition Verified**:
| Component | Lines | Status |
|-----------|-------|--------|
| `transfer_service.dart` + 4 parts | 3,538 | ✅ Split |
| `event_repository.dart` + 4 parts | 1,928 | ✅ Split |
| `outplant_batch_bloc.dart` + 4 parts | 3,124 | ⚠️ Main still 1,706 lines |
| `universal_csv_adapter_v2.dart` + 3 parts | 2,280 | ✅ Split |

**Migration Status**:
- Bloc → Cubit: ✅ Complete (no `extends Bloc<` in lib/)
- @Deprecated cleanup: ✅ Complete (only in test/tool files)
- Import coupling: `repositories_provider.dart` at 23 imports ✅

**Remaining Work**:
- [ ] Coverage targets not yet met (Cubits: 17%→35%, Screens: 6%→20%, Services: 38%→50%)
- [ ] `outplant_batch_bloc.dart` should be further decomposed

**GitHub Issue**: Comment added to #292

## References

- `docs/architecture/taxonomy/README.md`
- `docs/architecture/firestore_collections.md`
