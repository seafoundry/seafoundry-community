// @tier: community
enum TransferStatus { draft, pending, shipped, received, rejected, cancelled }

extension TransferStatusX on TransferStatus {
  String get value => name;

  bool canTransitionTo(TransferStatus target) =>
      TransferStateMachine.canTransition(this, target);

  bool get isTerminal =>
      this == TransferStatus.received ||
      this == TransferStatus.rejected ||
      this == TransferStatus.cancelled;
}

/// Simple state machine to enforce valid transfer state transitions.
class TransferStateMachine {
  static const Map<TransferStatus, Set<TransferStatus>> _transitions = {
    TransferStatus.draft: {TransferStatus.pending, TransferStatus.rejected},
    TransferStatus.pending: {
      TransferStatus.shipped,
      TransferStatus.received,
      TransferStatus.rejected,
      TransferStatus.cancelled, // Sender-initiated cancellation
    },
    TransferStatus.shipped: {
      TransferStatus.received,
      TransferStatus.rejected,
      TransferStatus.cancelled, // Sender-initiated cancellation (e.g., shipment recalled)
    },
    TransferStatus.received: {},
    TransferStatus.rejected: {},
    TransferStatus.cancelled: {}, // Terminal state
  };

  static bool canTransition(TransferStatus from, TransferStatus to) {
    return _transitions[from]?.contains(to) ?? false;
  }
}

TransferStatus parseTransferStatus(
  String? raw, {
  TransferStatus fallback = TransferStatus.draft,
}) {
  if (raw == null || raw.isEmpty) {
    return fallback;
  }
  final normalized = raw.toLowerCase();
  return TransferStatus.values.firstWhere(
    (status) => status.value == normalized,
    orElse: () => fallback,
  );
}

TransferStatus? tryParseTransferStatus(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final normalized = raw.toLowerCase();
  for (final status in TransferStatus.values) {
    if (status.value == normalized) {
      return status;
    }
  }
  return null;
}
