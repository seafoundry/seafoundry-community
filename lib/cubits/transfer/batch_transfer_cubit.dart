// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_item.dart';
import 'package:seafoundry_app/models/events/event_permit_metadata.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/transfer_ownership_type.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/transfer_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class BatchTransferState extends Equatable {
  const BatchTransferState({
    required this.mode,
    this.step = BatchTransferStep.selectFixed,
    this.fixedOrganization,
    this.fixedGenetId,
    this.fixedGenetLocalId,
    this.availableInventory,
    this.items = const [],
    this.comment = '',
    this.permitMetadata = const EventPermitMetadata.empty(),
    this.isCancelled = false,
  });

  final BatchTransferMode mode;
  final BatchTransferStep step;
  final Organization? fixedOrganization;
  final String? fixedGenetId;
  final String? fixedGenetLocalId;
  final int? availableInventory;
  final List<BatchTransferItem> items;
  final String comment;
  final EventPermitMetadata permitMetadata;
  final bool isCancelled;

  // -- Computed getters -----------------------------------------------------

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  int get successCount =>
      items.where((i) => i.status == BatchItemStatus.success).length;

  int get failureCount =>
      items.where((i) => i.status == BatchItemStatus.failure).length;

  bool get hasFailures => failureCount > 0;

  bool get canGoNext => switch (step) {
        BatchTransferStep.selectFixed =>
          mode == BatchTransferMode.multiGenetToOneOrg
              ? fixedOrganization != null
              : fixedGenetId != null,
        BatchTransferStep.addItems =>
          items.isNotEmpty && items.every((i) => i.quantity > 0),
        BatchTransferStep.review => canSubmit,
        BatchTransferStep.submitting => false,
        BatchTransferStep.complete => false,
      };

  bool get canSubmit {
    if (items.isEmpty || items.any((i) => i.quantity <= 0)) return false;
    return switch (mode) {
      BatchTransferMode.multiGenetToOneOrg => fixedOrganization != null,
      BatchTransferMode.oneGenetToMultiOrg =>
        fixedGenetId != null &&
            totalQuantity <= (availableInventory ?? 0),
    };
  }

  static const _sentinel = Object();

  BatchTransferState copyWith({
    BatchTransferMode? mode,
    BatchTransferStep? step,
    Object? fixedOrganization = _sentinel,
    Object? fixedGenetId = _sentinel,
    Object? fixedGenetLocalId = _sentinel,
    Object? availableInventory = _sentinel,
    List<BatchTransferItem>? items,
    String? comment,
    EventPermitMetadata? permitMetadata,
    bool? isCancelled,
  }) {
    return BatchTransferState(
      mode: mode ?? this.mode,
      step: step ?? this.step,
      fixedOrganization: fixedOrganization == _sentinel
          ? this.fixedOrganization
          : fixedOrganization as Organization?,
      fixedGenetId: fixedGenetId == _sentinel
          ? this.fixedGenetId
          : fixedGenetId as String?,
      fixedGenetLocalId: fixedGenetLocalId == _sentinel
          ? this.fixedGenetLocalId
          : fixedGenetLocalId as String?,
      availableInventory: availableInventory == _sentinel
          ? this.availableInventory
          : availableInventory as int?,
      items: items ?? this.items,
      comment: comment ?? this.comment,
      permitMetadata: permitMetadata ?? this.permitMetadata,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  @override
  List<Object?> get props => [
        mode, step, fixedOrganization, fixedGenetId, fixedGenetLocalId,
        availableInventory, items, comment, permitMetadata, isCancelled,
      ];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class BatchTransferCubit extends Cubit<BatchTransferState> {
  BatchTransferCubit({
    required BatchTransferMode mode,
    required TransferService transferService,
    required OrganismRecordRepository organismRecordRepository,
    required Organization currentOrganization,
  })  : _transferService = transferService,
        _organismRecordRepository = organismRecordRepository,
        _currentOrganization = currentOrganization,
        super(BatchTransferState(mode: mode));

  final TransferService _transferService;
  final OrganismRecordRepository _organismRecordRepository;
  final Organization _currentOrganization;

  // -- Fixed target setters -------------------------------------------------

  void setFixedOrganization(Organization org) {
    if (org.id == _currentOrganization.id) return;
    // Clear cart when target org changes — items store the org reference.
    final shouldClear = state.fixedOrganization != null &&
        state.fixedOrganization!.id != org.id &&
        state.items.isNotEmpty;
    emit(state.copyWith(
      fixedOrganization: org,
      items: shouldClear ? const [] : null,
    ));
  }

  void setFixedGenet(String genetId, String localGenetId, int availableInventory) {
    // Clear cart when genet changes — items store the genet reference.
    final shouldClear = state.fixedGenetId != null &&
        state.fixedGenetId != genetId &&
        state.items.isNotEmpty;
    emit(state.copyWith(
      fixedGenetId: genetId,
      fixedGenetLocalId: localGenetId,
      availableInventory: availableInventory,
      items: shouldClear ? const [] : null,
    ));
  }

  // -- Cart operations ------------------------------------------------------

  Future<AddItemResult> addItem({
    String? genetId,
    String? genetLocalId,
    String? organizationId,
    String? organizationName,
    required int quantity,
  }) async {
    if (state.mode == BatchTransferMode.multiGenetToOneOrg) {
      return _addGenetItem(genetId, genetLocalId, quantity);
    }
    return _addOrgItem(organizationId, organizationName, quantity);
  }

  Future<AddItemResult> _addGenetItem(
    String? genetId,
    String? genetLocalId,
    int quantity,
  ) async {
    if (genetId == null || genetLocalId == null) {
      return AddItemResult.missingFixedTarget;
    }
    if (state.fixedOrganization == null) return AddItemResult.missingFixedTarget;
    if (state.items.any((i) => i.genetId == genetId)) {
      return AddItemResult.duplicateGenet;
    }

    final ownership = await _detectOwnership(genetId);
    if (isClosed) return AddItemResult.closed;

    // Re-check after async gap
    if (state.items.any((i) => i.genetId == genetId)) {
      return AddItemResult.duplicateGenet;
    }

    final items = List<BatchTransferItem>.from(state.items);
    items.add(BatchTransferItem(
      genetId: genetId,
      genetLocalId: genetLocalId,
      toOrganizationId: state.fixedOrganization!.id,
      toOrganizationName: state.fixedOrganization!.name,
      quantity: quantity,
      ownershipType: ownership.type,
      originalOwnerOrganizationId: ownership.ownerId,
    ));
    emit(state.copyWith(items: List.unmodifiable(items)));
    return AddItemResult.success;
  }

  Future<AddItemResult> _addOrgItem(
    String? organizationId,
    String? organizationName,
    int quantity,
  ) async {
    if (organizationId == null || organizationName == null) {
      return AddItemResult.missingFixedTarget;
    }
    if (state.fixedGenetId == null || state.fixedGenetLocalId == null) {
      return AddItemResult.missingFixedTarget;
    }
    if (organizationId == _currentOrganization.id) {
      return AddItemResult.selfTransfer;
    }
    if (state.items.any((i) => i.toOrganizationId == organizationId)) {
      return AddItemResult.duplicateOrganization;
    }
    if (state.totalQuantity + quantity > (state.availableInventory ?? 0)) {
      return AddItemResult.exceedsInventory;
    }

    final ownership = await _detectOwnership(state.fixedGenetId!);
    if (isClosed) return AddItemResult.closed;

    // Re-check after async gap
    if (state.items.any((i) => i.toOrganizationId == organizationId)) {
      return AddItemResult.duplicateOrganization;
    }
    if (state.totalQuantity + quantity > (state.availableInventory ?? 0)) {
      return AddItemResult.exceedsInventory;
    }

    final items = List<BatchTransferItem>.from(state.items);
    items.add(BatchTransferItem(
      genetId: state.fixedGenetId!,
      genetLocalId: state.fixedGenetLocalId!,
      toOrganizationId: organizationId,
      toOrganizationName: organizationName,
      quantity: quantity,
      ownershipType: ownership.type,
      originalOwnerOrganizationId: ownership.ownerId,
    ));
    emit(state.copyWith(items: List.unmodifiable(items)));
    return AddItemResult.success;
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final items = List<BatchTransferItem>.from(state.items)..removeAt(index);
    emit(state.copyWith(items: List.unmodifiable(items)));
  }

  bool updateItemQuantity(int index, int quantity) {
    if (index < 0 || index >= state.items.length || quantity <= 0) return false;

    if (state.mode == BatchTransferMode.oneGenetToMultiOrg) {
      final otherTotal = state.totalQuantity - state.items[index].quantity;
      if (otherTotal + quantity > (state.availableInventory ?? 0)) return false;
    }

    final items = List<BatchTransferItem>.from(state.items);
    items[index] = items[index].copyWith(quantity: quantity);
    emit(state.copyWith(items: List.unmodifiable(items)));
    return true;
  }

  // -- Navigation -----------------------------------------------------------

  void goToStep(BatchTransferStep step) {
    if (state.step == BatchTransferStep.submitting) return;
    if (state.step == BatchTransferStep.complete) return;
    if (step == BatchTransferStep.submitting ||
        step == BatchTransferStep.complete) {
      return;
    }
    if (step == BatchTransferStep.review && state.items.isEmpty) return;
    emit(state.copyWith(step: step));
  }

  // -- Shared fields --------------------------------------------------------

  void setComment(String comment) => emit(state.copyWith(comment: comment));

  void setPermit(EventPermitMetadata permit) =>
      emit(state.copyWith(permitMetadata: permit));

  // -- Submission -----------------------------------------------------------

  Future<void> submitAll() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(
      step: BatchTransferStep.submitting,
      isCancelled: false,
    ));
    await _submitPendingItems();
  }

  void cancelSubmission() => emit(state.copyWith(isCancelled: true));

  Future<void> retryFailed() async {
    final items = List<BatchTransferItem>.from(state.items);
    for (var i = 0; i < items.length; i++) {
      if (items[i].status == BatchItemStatus.failure) {
        items[i] = items[i].copyWith(
          status: BatchItemStatus.pending,
          errorMessage: null,
          resultTransferEventId: null,
        );
      }
    }
    emit(state.copyWith(
      items: List.unmodifiable(items),
      step: BatchTransferStep.submitting,
      isCancelled: false,
    ));
    await _submitPendingItems();
  }

  /// Iterates pending items sequentially via [TransferService.initiateTransfer].
  /// Checks [isCancelled] between items (Dart's single-threaded event loop
  /// guarantees [cancelSubmission] emits before the next iteration reads state).
  /// On cancellation, pending items remain pending and step returns to review.
  Future<void> _submitPendingItems() async {
    final items = List<BatchTransferItem>.from(state.items);
    for (var i = 0; i < items.length; i++) {
      if (items[i].status != BatchItemStatus.pending) continue;
      if (isClosed) return;
      if (state.isCancelled) break;

      items[i] = items[i].copyWith(status: BatchItemStatus.submitting);
      if (isClosed) return;
      emit(state.copyWith(items: List.unmodifiable(items)));

      try {
        final event = await _transferService.initiateTransfer(
          genetId: items[i].genetId,
          toOrganizationId: items[i].toOrganizationId,
          quantity: items[i].quantity,
          comment: state.comment.isNotEmpty ? state.comment : null,
          permitMetadata: state.permitMetadata,
          ownershipType: items[i].ownershipType,
          originalOwnerOrganizationId: items[i].originalOwnerOrganizationId,
          inventorySelection: null,
        );
        items[i] = items[i].copyWith(
          status: BatchItemStatus.success,
          resultTransferEventId: event.id,
        );
      } on TransferWorkflowException catch (e) {
        items[i] = items[i].copyWith(
          status: BatchItemStatus.failure,
          errorMessage: e.message,
        );
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Batch transfer failed for genet ${items[i].genetLocalId} '
          'to ${items[i].toOrganizationName}',
          e,
          stackTrace,
        );
        items[i] = items[i].copyWith(
          status: BatchItemStatus.failure,
          errorMessage: e.toString(),
        );
      }
      if (isClosed) return;
      emit(state.copyWith(items: List.unmodifiable(items)));
    }
    if (isClosed) return;

    // If cancelled mid-submission, pending items remain — return to review.
    final hasPending = items.any((i) => i.status == BatchItemStatus.pending);
    emit(state.copyWith(
      step: hasPending ? BatchTransferStep.review : BatchTransferStep.complete,
    ));
  }

  // -- Helpers --------------------------------------------------------------

  Future<_OwnershipDetection> _detectOwnership(String genetId) async {
    try {
      final organisms = await _organismRecordRepository
          .queryByGenet(genetId)
          .first;
      if (organisms.isEmpty) {
        LoggingService.instance.warning(
          'No organisms found for genet $genetId, defaulting to fullTransfer',
        );
        return const _OwnershipDetection(TransferOwnershipType.fullTransfer);
      }
      final thirdPartyOrg = organisms
          .where((o) =>
              o.ownerOrganizationId != null &&
              o.ownerOrganizationId!.isNotEmpty &&
              o.ownerOrganizationId != _currentOrganization.id)
          .firstOrNull;
      if (thirdPartyOrg != null) {
        return _OwnershipDetection(
          TransferOwnershipType.thirdPartyTransfer,
          thirdPartyOrg.ownerOrganizationId,
        );
      }
      return const _OwnershipDetection(TransferOwnershipType.fullTransfer);
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to detect ownership for genet $genetId, '
        'defaulting to fullTransfer',
        e,
      );
      return const _OwnershipDetection(TransferOwnershipType.fullTransfer);
    }
  }
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Result of adding an item to the batch transfer cart.
enum AddItemResult {
  success,
  duplicateGenet,
  duplicateOrganization,
  exceedsInventory,
  missingFixedTarget,
  selfTransfer,
  closed,
}

class _OwnershipDetection {
  const _OwnershipDetection(this.type, [this.ownerId]);
  final TransferOwnershipType type;
  final String? ownerId;
}
