# Agentic Bloat Follow-Up Tasks

This document tracks post-wave consolidation opportunities and completion status.

## Completed In This Pass
1. Consolidate manifest/genet metadata hydration in transfer service.
   - Implemented in `lib/services/transfer_service.dart` via canonical metadata hydration helpers.

2. Decompose `PendingTransfersDialog` into container/display/components.
   - Implemented by extracting UI/detail dialogs into
     `lib/widgets/dialogs/pending_transfers_dialog_components.dart`.

3. Remove remaining legacy alias/ID compatibility reads in provenance repository.
   - Implemented in `lib/repositories/inventory/provenance_repository.dart`
     (canonical top-level reads only).

4. Harden CSV v2 legacy ID handling from warning to blocking error where appropriate.
   - Implemented in
     `lib/services/csv/adapters/universal_csv_adapter_v2_validator.dart`.

5. Remove residual transfer fallback/compat comments and stale docs.
   - Implemented in transfer service comments and through targeted orphan-doc deletion.

6. Resolve transfer shipping API dead code.
   - Implemented by restoring the public `markTransferShipped` wrapper in
     `lib/services/transfer_service.dart`.

7. Remove unused `_computeChanges` helper from provenance repository.
   - Implemented in `lib/repositories/inventory/provenance_repository.dart`.

## Remaining Ranked Queue
1. Add minimal root `test/` smoke coverage (or update scripts) so regression checks are meaningful.
   - Location: repository root testing setup.
   - Benefit: enables per-task runtime regression verification instead of structural test failure.

2. Move `PendingTransfersDialog` state/data orchestration into a cubit/controller.
   - Location: `lib/widgets/dialogs/pending_transfers_dialog.dart`.
   - Benefit: further shrinks widget complexity and improves testability.

## Validation Gap To Address
- Flutter unit/widget smoke checks are currently blocked because repository root has no `test/` directory.
- Recommended follow-up: restore a minimal `test/` suite (or adjust CI scripts) so per-task regression checks execute meaningful tests instead of structural failure.
