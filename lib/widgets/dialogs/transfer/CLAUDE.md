# Transfer Dialogs

Genetic material transfers between organizations.

## Files

### Single Transfer
- `transfer_shared.dart` - `OrganizationSearchDialog`, shared mixins
- `transfer_initiate_dialog.dart` - Send transfer to another org
- `transfer_receive_dialog.dart` - Receive via manifest payload
- `transfer_manual_register_dialog.dart` - Manual registration without manifest

### Batch Transfer
- `batch_transfer_dialog.dart` - Multi-step wizard orchestrator (SafeDialogMixin)
- `batch_transfer_target_step.dart` - Step 1: select fixed org (Mode A) or genet (Mode B)
- `batch_transfer_items_step.dart` - Step 2: add items to cart
- `batch_transfer_review_step.dart` - Step 3: review and comment
- `batch_transfer_progress_step.dart` - Step 4-5: submission progress and completion
- `batch_transfer_cart.dart` - Reusable cart display (editable or read-only)

## Entry Point

`lib/widgets/dialogs/transfer_dialog.dart` - All `show*` methods. Captures providers from parent context before `showDialog`.

- `showBatch()` - Batch transfer (Mode A: multi-genet→one-org, Mode B: one-genet→multi-org)

## State

- `TransferInitiateCubit` in `lib/cubits/transfer/` - Single transfers
- `BatchTransferCubit` in `lib/cubits/transfer/` - Batch transfers
- `BatchTransferItem` in `lib/cubits/transfer/` - Cart item model
- `batch_transfer_enums.dart` - `BatchTransferMode`, `BatchTransferStep`, `BatchItemStatus`

## Key Behaviors

- `OrganizationSearchDialog` takes `excludeOrganizationId` to prevent self-transfers
- Recipient modes: organization search OR direct email
- Coral-only: only coral transfers are supported

### Batch Transfer
- Two modes: `multiGenetToOneOrg` (Mode A) and `oneGenetToMultiOrg` (Mode B)
- Each (genet, org) pair creates an independent `TransferEvent` via `TransferService.initiateTransfer()`
- Auto-organism-selection (v1): `inventorySelection: null` — no per-record selection
- Per-item ownership auto-detection via `OrganismRecordRepository.queryByGenet()`
- Sequential submission with cancellation support (`isCancelled` flag)
- Partial failure: failed items can be retried independently
- Cart deduplication: rejects duplicate genets (Mode A) or duplicate orgs (Mode B)
- Mode B validates `sum(quantities) <= availableInventory`

## Providers Required in Dialog

All must be captured before `showDialog` and re-provided via `DialogBase.showDialogWithProviders`.

### showManualRegister
- `OrganizationRepository`
- `ManualTransferRegistrationService` (interface; `TransferService` is the implementation)
- `Organization`
- `NavigationCubit`
- `UniqueNameValidationService` (for local ID suggestions)

### showInitiate / showForEdit
- `OrganismRecordRepository`, `GroupRepository`, `SiteRepository` (via `safeReadAll`)
- `OrganizationRepository`
- `TransferService`
- `Organization`
- `NavigationCubit`
- `BlocProvider<TransferInitiateCubit>` (created in show method)

### showReceive
- `OrganizationRepository`
- `OrganismRecordRepository`
- `SiteRepository`
- `UniqueNameValidationService` (local ID + record name suggestions)
- `TransferService`
- `Organization`
- `NavigationCubit`
- `BlocProvider<TransferReceiveCubit>` (created in show method)

### showBatch
- `OrganismRecordRepository`, `GenetRepository` (via `safeReadAll`)
- `OrganizationRepository`
- `TransferService`
- `Organization`
- `NavigationCubit`
- `BlocProvider<BatchTransferCubit>` (created in show method)

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
