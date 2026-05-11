import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';

/// A single item in the batch transfer cart.
///
/// Each item represents one (genet, organization) pair that will produce
/// an independent [TransferEvent] via [TransferService.initiateTransfer].
class BatchTransferItem extends Equatable {
  const BatchTransferItem({
    required this.genetRecordId,
    required this.genetLocalId,
    required this.toOrganizationId,
    required this.toOrganizationName,
    required this.quantity,
    this.status = BatchItemStatus.pending,
    this.errorMessage,
    this.resultTransferEventId,
  });

  /// The genet ID for this transfer item.
  final String genetRecordId;

  /// Display name for the genet (e.g., "ACER-001").
  final String genetLocalId;

  /// Target organization ID.
  final String toOrganizationId;

  /// Target organization display name.
  final String toOrganizationName;

  /// Number of organisms to transfer.
  final int quantity;

  /// Current submission status of this item.
  final BatchItemStatus status;

  /// Error message if submission failed.
  final String? errorMessage;

  /// The resulting TransferEvent ID on success.
  final String? resultTransferEventId;

  static const _sentinel = Object();

  BatchTransferItem copyWith({
    String? genetRecordId,
    String? genetLocalId,
    String? toOrganizationId,
    String? toOrganizationName,
    int? quantity,
    BatchItemStatus? status,
    Object? errorMessage = _sentinel,
    Object? resultTransferEventId = _sentinel,
  }) {
    return BatchTransferItem(
      genetRecordId: genetRecordId ?? this.genetRecordId,
      genetLocalId: genetLocalId ?? this.genetLocalId,
      toOrganizationId: toOrganizationId ?? this.toOrganizationId,
      toOrganizationName: toOrganizationName ?? this.toOrganizationName,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      resultTransferEventId: resultTransferEventId == _sentinel
          ? this.resultTransferEventId
          : resultTransferEventId as String?,
    );
  }

  @override
  List<Object?> get props => [
        genetRecordId,
        genetLocalId,
        toOrganizationId,
        toOrganizationName,
        quantity,
        status,
        errorMessage,
        resultTransferEventId,
      ];
}
