// @tier: community
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/update_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';

/// Result of formatting an update event for display.
class UpdateDisplay {
  const UpdateDisplay({required this.details, this.quantityDelta});

  final String details;
  final String? quantityDelta;
}

/// Formats inventory event data for display in spreadsheets and UI.
///
/// Contains static methods for formatting permits, moves, updates, and
/// other inventory event details.
class InventoryEventFormatter {
  InventoryEventFormatter._();

  /// Formats permit metadata into a display summary.
  static String formatPermitSummary(EventPermitMetadata permit) {
    final id = permit.permitId ?? '';
    final type = permit.permitType ?? '';
    if (id.isEmpty && type.isEmpty) {
      return '';
    }
    if (id.isNotEmpty && type.isNotEmpty) {
      return '$type ($id)';
    }
    return id.isNotEmpty ? id : type;
  }

  /// Formats permit validity window for display.
  static String formatPermitWindow(EventPermitMetadata permit) {
    final start = permit.validFrom;
    final end = permit.validTo;
    if (start == null && end == null) {
      return '';
    }
    final formatter = DateFormat.yMMMd();
    final buffer = StringBuffer();
    if (start != null) {
      buffer.write(formatter.format(start));
    }
    buffer.write(' - ');
    if (end != null) {
      buffer.write(formatter.format(end));
    }
    return buffer.toString();
  }

  /// Formats move event details showing from/to locations.
  static String formatMoveDetails({
    String? fromSiteName,
    String? fromStructureName,
    String? toSiteName,
    String? toStructureName,
  }) {
    String joinParts(String? site, String? structure) {
      final segments = <String>[];
      if (site != null && site.isNotEmpty) {
        segments.add(site);
      }
      if (structure != null && structure.isNotEmpty && structure != site) {
        segments.add(structure);
      }
      return segments.join(' - ');
    }

    final fromParts = joinParts(fromSiteName, fromStructureName);
    final toParts = joinParts(toSiteName, toStructureName);

    if (fromParts.isEmpty && toParts.isEmpty) {
      return 'Move recorded';
    }
    if (fromParts.isEmpty) {
      return 'To: $toParts';
    }
    if (toParts.isEmpty) {
      return 'From: $fromParts';
    }
    return 'From: $fromParts -> To: $toParts';
  }

  /// Formats an update event for display, extracting field changes.
  static UpdateDisplay formatUpdateDisplay({
    required UpdateEvent event,
    required OrganismRecord? resolvedOrganism,
  }) {
    final updates = <String>[];
    String? quantityDelta;
    final fieldUpdates = event.fieldUpdates;

    if (fieldUpdates.isNotEmpty) {
      quantityDelta = _quantityDeltaFromFieldUpdates(fieldUpdates);

      final quantityLabel =
          _quantityLabelFromFieldUpdates(fieldUpdates, resolvedOrganism);
      if (quantityLabel != null) {
        updates.add(quantityLabel);
      }

      final lifeStageLabel =
          _lifeStageLabelFromFieldUpdates(fieldUpdates, resolvedOrganism);
      if (lifeStageLabel != null && lifeStageLabel.isNotEmpty) {
        updates.add(lifeStageLabel);
      }

      fieldUpdates.forEach((field, value) {
        if (_handledUpdateField(field)) return;
        final label = _updateFieldLabel(field);
        if (label == null) return;
        final formatted = _formatUpdateValue(value);
        if (formatted.isEmpty) return;
        updates.add('$label -> $formatted');
      });
    } else if (resolvedOrganism != null) {
      final qty = resolvedOrganism.measurement.value.round();
      if (qty > 0) {
        updates.add('Qty $qty');
      }
      final lifeStage = resolvedOrganism.lifeStage.stage.displayName;
      if (lifeStage.isNotEmpty) {
        updates.add(lifeStage);
      }
      final physicalForm =
          resolvedOrganism.physicalForm?.formId ??
          resolvedOrganism.metadata?['physicalFormId']?.toString();
      if (physicalForm != null && physicalForm.isNotEmpty) {
        updates.add(physicalForm);
      }
    }

    final notes = event.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      updates.add('Notes: $notes');
    }

    final updateType =
        event.updateType.isNotEmpty && event.updateType != 'unknown'
            ? event.updateType
            : 'Updated';
    final fieldCount = fieldUpdates.length;
    final fieldLabel = fieldCount == 1 ? 'field' : 'fields';

    final details =
        updates.isEmpty
            ? '$updateType - $fieldCount $fieldLabel updated'
            : '$updateType - ${updates.join(' - ')}';

    return UpdateDisplay(details: details, quantityDelta: quantityDelta);
  }

  /// Appends a comment to details with proper formatting.
  static String appendComment(String details, String? comment) {
    if (comment == null) {
      return details;
    }
    final trimmed = comment.trim();
    if (trimmed.isEmpty) {
      return details;
    }
    if (details.isEmpty) {
      return trimmed;
    }
    return '$details - $trimmed';
  }
}

// Private helper functions

String? _quantityDeltaFromFieldUpdates(Map<String, dynamic> updates) {
  int? delta;
  for (final key in ['quantity', 'measurement', 'measurement.value']) {
    final value = updates[key];
    delta = _extractQuantityDelta(value);
    if (delta != null) break;
  }
  if (delta == null) return null;
  return delta >= 0 ? '+$delta' : delta.toString();
}

int? _extractQuantityDelta(dynamic raw) {
  if (raw is Map) {
    final before = _asInt(raw['before']);
    final after = _asInt(raw['after']);
    if (before != null && after != null) {
      return after - before;
    }
    if (raw.containsKey('value')) {
      return _extractQuantityDelta(raw['value']);
    }
  }
  return null;
}

String? _quantityLabelFromFieldUpdates(
  Map<String, dynamic> updates,
  OrganismRecord? organism,
) {
  int? value;
  for (final key in ['quantity', 'measurement', 'measurement.value']) {
    value = _extractQuantityValue(updates[key]);
    if (value != null) break;
  }
  value ??= organism?.measurement.value.round();
  if (value == null) return null;
  return 'Qty $value';
}

int? _extractQuantityValue(dynamic raw) {
  if (raw is num) return raw.round();
  if (raw is Map) {
    if (raw.containsKey('after')) {
      final after = raw['after'];
      if (after is num) {
        return after.round();
      }
    }
    if (raw.containsKey('value')) {
      return _extractQuantityValue(raw['value']);
    }
  }
  return null;
}

String? _lifeStageLabelFromFieldUpdates(
  Map<String, dynamic> updates,
  OrganismRecord? organism,
) {
  final value =
      updates['lifeStageId'] ??
      updates['lifeStage'] ??
      updates['metadata.lifeStageId'] ??
      updates['metadata.lifeStage'];
  final raw = _extractAfterString(value);
  final parsed = LifeStageX.tryParse(raw);
  if (parsed != null) {
    return parsed.displayName;
  }
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  return organism?.lifeStage.stage.displayName;
}

bool _handledUpdateField(String field) {
  const handled = {
    'quantity',
    'measurement',
    'measurement.value',
    'lifeStage',
    'lifeStageId',
    'metadata.lifeStage',
    'metadata.lifeStageId',
  };
  return handled.contains(field);
}

String? _updateFieldLabel(String field) {
  const labels = {
    'healthStatus': 'Health',
    'healthStatusId': 'Health',
    'readyForOutplant': 'Outplant status',
    'readyForPropagation': 'Propagation status',
    'groupId': 'Structure',
    'siteId': 'Site',
    'speciesId': 'Species',
    'physicalForm.formId': 'Physical form',
    'metadata.physicalFormId': 'Physical form',
    'provenanceTypeId': 'Provenance type',
    'metadata.provenanceTypeId': 'Provenance type',
  };
  return labels[field] ?? field;
}

String _formatUpdateValue(dynamic value) {
  if (value is Map) {
    final before = _extractAfterString(value['before']);
    final after =
        _extractAfterString(value['after']) ?? _extractAfterString(value['value']);
    if (before != null && after != null && before != after) {
      return '$before -> $after';
    }
    if (after != null && after.isNotEmpty) {
      return after;
    }
    if (before != null && before.isNotEmpty) {
      return before;
    }
    return '';
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }
  return value?.toString() ?? '';
}

String? _extractAfterString(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    if (raw.containsKey('after')) {
      final after = raw['after'];
      if (after != null && after.toString().isNotEmpty) {
        return after.toString();
      }
    }
    if (raw.containsKey('value')) {
      return _extractAfterString(raw['value']);
    }
  }
  final asString = raw.toString();
  return asString.isEmpty ? null : asString;
}

int? _asInt(dynamic value) {
  if (value is num) return value.round();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
