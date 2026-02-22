// @tier: community
part of 'pending_transfers_cubit.dart';

enum PendingTransfersStatus { initial, loading, success, error }

class PendingTransfersState extends Equatable {
  const PendingTransfersState({
    this.status = PendingTransfersStatus.initial,
    this.entries = const [],
    this.isProcessing = false,
    this.errorMessage,
    this.message,
  });

  final PendingTransfersStatus status;
  final List<PendingTransferEntry> entries;
  final bool isProcessing;
  final String? errorMessage;
  final PendingTransfersMessage? message;

  bool get isLoading => status == PendingTransfersStatus.loading;
  bool get hasError => status == PendingTransfersStatus.error;
  bool get isEmpty => status == PendingTransfersStatus.success && entries.isEmpty;

  PendingTransfersState copyWith({
    PendingTransfersStatus? status,
    List<PendingTransferEntry>? entries,
    bool? isProcessing,
    String? Function()? errorMessage,
    PendingTransfersMessage? Function()? message,
  }) {
    return PendingTransfersState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      message: message != null ? message() : this.message,
    );
  }

  static const _listEquality = ListEquality<PendingTransferEntry>();

  @override
  List<Object?> get props => [
        status,
        _listEquality.hash(entries),
        isProcessing,
        errorMessage,
        message,
      ];
}

class PendingTransferEntry extends Equatable {
  const PendingTransferEntry({
    required this.transfer,
    this.genet,
    this.fromOrganization,
  });

  final TransferEvent transfer;
  final ProvenanceRecord? genet;
  final Organization? fromOrganization;

  ProvenanceLifeStageSelection get provenanceSelection =>
      buildTransferProvenanceSelection(
        transfer: transfer,
        provenance: genet,
      );

  @override
  List<Object?> get props => [transfer, genet, fromOrganization];
}

class PendingTransfersMessage extends Equatable {
  const PendingTransfersMessage._({
    required this.text,
    required this.type,
  });

  factory PendingTransfersMessage.success(String text) =>
      PendingTransfersMessage._(text: text, type: PendingTransfersMessageType.success);

  factory PendingTransfersMessage.warning(String text) =>
      PendingTransfersMessage._(text: text, type: PendingTransfersMessageType.warning);

  factory PendingTransfersMessage.error(String text) =>
      PendingTransfersMessage._(text: text, type: PendingTransfersMessageType.error);

  final String text;
  final PendingTransfersMessageType type;

  bool get isError => type == PendingTransfersMessageType.error;

  @override
  List<Object?> get props => [text, type];
}

enum PendingTransfersMessageType { success, warning, error }
