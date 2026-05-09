part of 'genetics_events_table.dart';

String _describeGenetInventoryEvent(InventoryEvent event, Genet genet) {
  if (event is CreateEvent) {
    final details = <String>[_eventRecordLabel('Local ID', genet.name)];
    final selection = ProvenanceLifeStageSelection.fromGenet(genet);
    details.add(selection.provenanceType.displayName);
    details.add(selection.lifeStage.displayName);
    if (_asNonEmptyString(genet.provenanceId) != null) {
      details.add(genet.provenanceId);
    }
    return 'Genet created • ${details.join(' • ')}';
  }
  return 'Genet snapshot captured';
}

String _describeOrganismInventoryEvent(
  InventoryEvent event,
  OrganismRecord organism,
) {
  if (event is CreateEvent) {
    final details = <String>[
      _eventRecordLabel('Record Name', organism.name),
      'Qty ${organism.measurement.value.round()}',
    ];
    final lifeStageLabel = organism.lifeStage.stage.displayName;
    final physicalFormLabel = _physicalFormLabel(organism.physicalForm?.formId);
    details.add(lifeStageLabel);
    if (physicalFormLabel != null) {
      details.add(physicalFormLabel);
    }
    return 'Organism created • ${details.join(' • ')}';
  }
  return 'Organism snapshot captured';
}

String _eventRecordLabel(String label, String value) {
  final trimmed = value.trim();
  return '$label ${trimmed.isEmpty ? '—' : trimmed}';
}

List<OrganismAlias> _aliasesFromRaw(dynamic raw) {
  if (raw == null) return const <OrganismAlias>[];
  if (raw is Iterable) return OrganismAlias.listFromJson(raw);
  return OrganismAlias.listFromJson([raw]);
}

String _formatTransferDescription(TransferEvent event) {
  final statusLabel = _statusLabel(event.status);
  final parts = <String>['Quantity ${event.quantity}'];
  final fromOrg = _asNonEmptyString(event.fromOrganizationId);
  if (fromOrg != null) {
    parts.add('From $fromOrg');
  }
  final toOrg = _asNonEmptyString(event.toOrganizationId);
  if (toOrg != null) {
    parts.add('To $toOrg');
  }
  final comment = _asNonEmptyString(event.comment);
  if (comment != null) {
    parts.add(comment);
  }
  return 'Transfer $statusLabel • ${parts.join(' • ')}';
}

String _formatUpdateDescription(
  UpdateEvent event,
  ModelType recordType, {
  OrganismRecord? organism,
}) {
  final prefix = recordType == ModelType.genet
      ? 'Genet updated'
      : 'Organism updated';

  // Check if this update includes provenance type information (genetics events)
  // First check the fieldUpdates for various possible field paths, then fall back to the resolved organism
  String? provenanceTypeId =
      event.fieldUpdates['provenanceType']?.toString() ??
          event.fieldUpdates['provenanceTypeId']?.toString() ??
          event.fieldUpdates['metadata.provenanceTypeId']?.toString();

  if (provenanceTypeId == null && organism?.provenanceType != null) {
    provenanceTypeId = organism!.provenanceType!.id;
  }
  final provenanceTypeLabel = _provenanceTypeLabelFromId(provenanceTypeId);

  if (event.fieldUpdates.isEmpty) {
    // If no field updates but we have organism with provenance type, show that
    if (provenanceTypeLabel != null && organism != null) {
      final details = <String>[provenanceTypeLabel];

      final quantity = organism.measurement.value.round();
      if (quantity > 0) {
        details.add('Qty $quantity');
      }

      final lifeStageLabel = organism.lifeStage.stage.displayName;
      if (lifeStageLabel.isNotEmpty) {
        details.add(lifeStageLabel);
      }

      final physicalFormLabel = _physicalFormLabel(
        organism.physicalForm?.formId ??
            organism.metadata?['physicalFormId']?.toString(),
      );
      if (physicalFormLabel != null) {
        details.add(physicalFormLabel);
      }

      return details.join(' • ');
    }

    if (_asNonEmptyString(event.notes) != null) {
      return '$prefix • Notes: ${event.notes!.trim()}';
    }
    return prefix;
  }

  final updates = <String>[];

  // For genetics events, highlight provenance type first
  if (provenanceTypeLabel != null) {
    updates.add(provenanceTypeLabel);
  }

  // Extract quantity from field updates or organism
  String? quantityStr;
  if (event.fieldUpdates.containsKey('quantity')) {
    quantityStr = event.fieldUpdates['quantity']?.toString();
  } else if (event.fieldUpdates.containsKey('measurement')) {
    quantityStr = event.fieldUpdates['measurement']?.toString();
  } else if (organism != null) {
    quantityStr = organism.measurement.value.round().toString();
  }

  // Extract life stage from field updates or organism
  String? lifeStageLabel;
  if (event.fieldUpdates.containsKey('lifeStageId')) {
    lifeStageLabel =
        _lifeStageLabelFromId(event.fieldUpdates['lifeStageId']?.toString());
  } else if (event.fieldUpdates.containsKey('metadata.lifeStageId')) {
    lifeStageLabel = _lifeStageLabelFromId(
        event.fieldUpdates['metadata.lifeStageId']?.toString());
  } else if (organism != null) {
    lifeStageLabel = organism.lifeStage.stage.displayName;
  }

  event.fieldUpdates.forEach((field, value) {
    // Skip fields we've already processed
    if (field == 'provenanceType' ||
        field == 'provenanceTypeId' ||
        field == 'metadata.provenanceTypeId') {
      return;
    }
    if (field == 'quantity' || field == 'measurement') return;
    if (field == 'lifeStageId' || field == 'metadata.lifeStageId') return;

    final label = _fieldLabel(recordType, field);
    if (label == null) return;
    final display = _formatFieldValue(field, value);
    if (display.isEmpty) return;

    // For genetics events, simplify the display
    if (provenanceTypeLabel != null) {
      // Just show the value for key fields
      if (field == 'physicalForm.formId' ||
          field == 'metadata.physicalFormId') {
        updates.add(display);
      } else {
        updates.add('$label → $display');
      }
    } else {
      updates.add('$label → $display');
    }
  });

  // Add quantity and life stage to updates for genetics events
  if (provenanceTypeLabel != null) {
    if (quantityStr != null && quantityStr.isNotEmpty) {
      final qty = double.tryParse(quantityStr)?.round();
      if (qty != null && qty > 0) {
        updates.insert(1, 'Qty $qty'); // Insert after provenance type
      }
    }

    if (lifeStageLabel != null && lifeStageLabel.isNotEmpty) {
      updates.add(lifeStageLabel);
    }
  }

  if (_asNonEmptyString(event.notes) != null) {
    updates.add('Notes: ${event.notes!.trim()}');
  }

  if (updates.isEmpty) {
    return prefix;
  }

  final updateTypeLabel = _formatUpdateType(event.updateType);
  final suffix = updates.join(' • ');

  // For genetics events, use cleaner format without redundant prefix
  if (provenanceTypeLabel != null) {
    return suffix;
  }

  return '$prefix${updateTypeLabel != null ? ' • $updateTypeLabel' : ''}: $suffix';
}

String _formatGenetModificationDescription(GenetModificationEvent event) {
  if (event.changes.isEmpty) {
    return 'Genet details updated';
  }

  final details = <String>[];

  event.changes.forEach((field, rawChange) {
    final label = _genetFieldLabels[field] ?? field;
    if (rawChange is Map) {
      if (field == 'provenance') {
        details.add('Provenance updated');
        return;
      }
      final before = _stringifyChangeValue(rawChange['before']);
      final after = _stringifyChangeValue(rawChange['after']);
      if (before == after) {
        details.add('$label updated');
      } else {
        details.add('$label: $before → $after');
      }
    } else {
      details.add('$label updated');
    }
  });

  if (details.isEmpty) {
    return 'Genet details updated';
  }

  if (details.length > 3) {
    final preview = details.take(3).join(' • ');
    return 'Genet updated • $preview • +${details.length - 3} more';
  }

  return 'Genet updated • ${details.join(' • ')}';
}

String _stringifyChangeValue(dynamic value) {
  if (value == null) return '—';
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is Iterable) {
    final items = value
        .map(_stringifyChangeValue)
        .where((element) => element != '—')
        .toList();
    return items.isEmpty ? '—' : items.join(', ');
  }
  if (value is Map) {
    if (value.isEmpty) return '—';
    final entries = value.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) =>
              '${_formatProvenanceKey(entry.key)}=${_stringifyChangeValue(entry.value)}',
        )
        .take(3)
        .toList();
    if (entries.isEmpty) return '—';
    final result = entries.join(', ');
    return value.length > entries.length ? '$result…' : result;
  }
  return value.toString();
}

String _formatProvenanceKey(String key) {
  if (key.isEmpty) return key;
  final parts = key.split('_').where((part) => part.isNotEmpty);
  return parts
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String? _formatUpdateType(String updateType) {
  final normalized = updateType.trim();
  if (normalized.isEmpty) return null;
  switch (normalized) {
    case 'genet_type_update':
      return 'Provenance Type';
    case 'quantity_adjustment':
      return 'Quantity';
    default:
      return normalized.replaceAll('_', ' ');
  }
}

String? _fieldLabel(ModelType recordType, String field) {
  if (recordType == ModelType.genet) {
    return _genetFieldLabels[field] ?? field;
  }
  if (recordType == ModelType.organismRecord) {
    return _coralFieldLabels[field] ?? field;
  }
  return field;
}

String _formatFieldValue(String field, Object? value) {
  if (value == null) return '';
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    switch (field) {
      case 'provenanceTypeId':
      case 'metadata.provenanceTypeId':
        return _provenanceTypeLabelFromId(trimmed) ?? trimmed;
      case 'speciesId':
        return _speciesLabel(trimmed) ?? trimmed;
      case 'lifeStageId':
      case 'metadata.lifeStageId':
        return _lifeStageLabelFromId(trimmed) ?? trimmed;
      case 'physicalForm.formId':
        return _physicalFormLabel(trimmed) ?? trimmed;
      case 'metadata.physicalFormId':
        return _physicalFormLabel(trimmed) ?? trimmed;
      default:
        return trimmed;
    }
  }
  if (value is Iterable) {
    return value
        .map((entry) => entry.toString())
        .where((entry) => entry.trim().isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }
  return value.toString();
}

