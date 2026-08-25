import 'package:seafoundry_community/models/types/event_type.dart';

/// Event types for inter-organization loans/transfers of inventory records.
class LoanEventType extends EventType {
  const LoanEventType({required super.id, required super.name});

  static const String loanId = 'event_loan';
  static const LoanEventType loan = LoanEventType(
    id: loanId,
    name: 'Loan',
  );

  /// Legacy identifier used by early community forks (kept for compatibility).
  static const String legacyTransferId = 'event_transfer';
  static const LoanEventType legacyTransfer = LoanEventType(
    id: legacyTransferId,
    name: 'Transfer (Legacy)',
  );

  static const List<LoanEventType> values = [
    loan,
    legacyTransfer,
  ];

  static final Map<String, LoanEventType> builtins = {
    for (final type in values) type.id: type,
  };

  /// Helper to include both primary and legacy event ids in Firestore queries.
  static List<String> get queryIds => builtins.keys.toList(growable: false);
}
