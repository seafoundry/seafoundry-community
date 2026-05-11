part of 'genetics_events_table.dart';

bool _isSupportedEventType(String? eventTypeId) {
  if (eventTypeId == null ||
      eventTypeId.isEmpty ||
      eventTypeId == Missing.string) {
    return false;
  }
  return _supportedEventTypeIds.contains(eventTypeId);
}

bool _isRelevantRecordType(ModelType? type) =>
    type == ModelType.genet || type == ModelType.organismRecord;

String _eventLabelFor(String? eventTypeId) {
  final sanitized = _sanitizeEventTypeId(eventTypeId);
  if (sanitized == null) {
    return 'Unknown Event';
  }
  if (_eventLabelOverrides.containsKey(sanitized)) {
    return _eventLabelOverrides[sanitized]!;
  }
  return EventType.builtins[sanitized]?.name ?? sanitized;
}

String _geneticsAwareEventLabel(
  String? eventTypeId,
  String? provenanceTypeLabel,
) {
  // For update events with genetics provenance, use provenance type as label
  final sanitized = _sanitizeEventTypeId(eventTypeId);
  if (sanitized == 'event_update' &&
      provenanceTypeLabel != null &&
      provenanceTypeLabel.isNotEmpty) {
    return provenanceTypeLabel; // e.g., "Sexual Cohort", "Wild Collection"
  }
  return _eventLabelFor(eventTypeId);
}

String _recordTypeLabel(ModelType? type) {
  switch (type) {
    case ModelType.genet:
      return 'Genet';
    case ModelType.organismRecord:
      return 'Organism';
    default:
      return '';
  }
}

String? _speciesLabel(String? speciesId) {
  final id = _asNonEmptyString(speciesId);
  if (id == null) return null;
  return SpeciesRegistry.globalById(id)?.name ?? id;
}

String? _provenanceLabelFromTypeId(String? provenanceTypeId) {
  final provenanceType = _provenanceTypeFromId(provenanceTypeId);
  if (provenanceType != null) {
    return provenanceType.displayName;
  }
  return _provenanceTypeLabel(provenanceTypeId);
}

String? _lifeStageLabelFromId(String? lifeStageId) {
  final id = _asNonEmptyString(lifeStageId);
  if (id == null) return null;
  final stage = LifeStageX.tryParse(id);
  return stage?.displayName;
}

String? _provenanceTypeLabelFromId(String? provenanceTypeId) {
  final id = _asNonEmptyString(provenanceTypeId);
  if (id == null) return null;
  final type = ProvenanceTypeX.tryParse(id);
  return type?.displayName;
}

String? _physicalFormLabel(String? physicalFormId) {
  final id = _asNonEmptyString(physicalFormId);
  if (id != null) {
    // Physical form ids are already human-readable; return raw id.
    return id;
  }
  return null;
}

ProvenanceType? _provenanceTypeFromId(String? provenanceTypeId) {
  final id = _asNonEmptyString(provenanceTypeId);
  if (id == null) return null;
  return ProvenanceTypeX.tryParse(id);
}

String? _provenanceTypeLabel(String? provenanceTypeId) {
  final id = _asNonEmptyString(provenanceTypeId);
  if (id == null) return null;
  final provenanceType = ProvenanceTypeX.tryParse(id);
  if (provenanceType != null) return provenanceType.displayName;
  // Fallback for unknown provenance types
  return id;
}

String _statusLabel(String? raw) {
  final parsed = tryParseTransferStatus(raw) ?? TransferStatus.draft;
  switch (parsed) {
    case TransferStatus.draft:
      return 'Draft';
    case TransferStatus.pending:
      return 'Pending';
    case TransferStatus.shipped:
      return 'Shipped';
    case TransferStatus.received:
      return 'Received';
    case TransferStatus.rejected:
      return 'Rejected';
    case TransferStatus.cancelled:
      return 'Cancelled';
  }
}

String? _asNonEmptyString(Object? value) {
  if (value == null) return null;
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _sanitizeEventTypeId(String? raw) {
  if (raw == null || raw.isEmpty || raw == Missing.string) {
    return null;
  }
  return raw;
}
