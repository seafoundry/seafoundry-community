// @tier: community
import 'package:seafoundry_app/models/types/event_type.dart';

/// Event type definitions for gene bank operations such as audits,
/// temperature monitoring, and viability testing.
class GeneBankEventType extends EventType {
  const GeneBankEventType({required super.id, required super.name});

  static const String auditId = 'event_gene_bank_audit';
  static const GeneBankEventType audit = GeneBankEventType(
    id: auditId,
    name: 'Gene Bank Audit',
  );

  static const String temperatureMonitoringId = 'event_gene_bank_temperature';
  static const GeneBankEventType temperatureMonitoring = GeneBankEventType(
    id: temperatureMonitoringId,
    name: 'Temperature Monitoring',
  );

  static const String viabilityTestId = 'event_gene_bank_viability';
  static const GeneBankEventType viabilityTest = GeneBankEventType(
    id: viabilityTestId,
    name: 'Viability Test',
  );

  /// Ordered list of gene bank event types for UI/query helpers.
  static const List<GeneBankEventType> values = [
    audit,
    temperatureMonitoring,
    viabilityTest,
  ];

  static final Map<String, GeneBankEventType> builtins = {
    for (final type in values) type.id: type,
  };

  static GeneBankEventType? fromId(String? id) {
    return builtins[id ?? ''];
  }
}
