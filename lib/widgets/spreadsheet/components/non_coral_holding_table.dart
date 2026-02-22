// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/services/location_display_service.dart';
import '../../common/organism_reference_links.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/alias_badge.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';

/// Reusable spreadsheet table for displaying non-coral holdings (seeded lines,
/// gamete batches, larval batches, etc.) with organism-aware headers.
class NonCoralHoldingTable extends StatelessWidget {
  const NonCoralHoldingTable({
    super.key,
    required this.rows,
    required this.organismKind,
    required this.reloadToken,
    this.headerLabel,
    this.onEditHolding,
    this.onViewHistory,
  });

  final List<Map<String, dynamic>> rows;
  final OrganismKind organismKind;
  final int reloadToken;
  final String? headerLabel;
  final void Function(Map<String, dynamic> row)? onEditHolding;
  final void Function(Map<String, dynamic> row)? onViewHistory;

  static const PaginationService<Map<String, dynamic>> _paginationService =
      PaginationService<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    String? organizationDomain;
    try {
      organizationDomain = context.read<Organization>().domain;
    } catch (_) {
      organizationDomain = null;
    }
    final feature = _HoldingColumnFeatures.fromRows(
      rows,
      organismKind,
      showActions: onEditHolding != null || onViewHistory != null,
    );
    return SpreadsheetBase<Map<String, dynamic>>(
      key: ValueKey('non-coral-holdings-${organismKind.name}-$reloadToken'),
      columns: feature.buildColumns(),
      rowBuilder: (row) => _buildRow(
        row,
        feature,
        onEditHolding,
        onViewHistory,
        organizationDomain,
      ),
      pageLoader: _paginationService.buildListLoader(() => rows),
      sortField: null,
      header: headerLabel != null
          ? Text(headerLabel!)
          : const SizedBox.shrink(),
    );
  }

  static SpreadsheetRow _buildRow(
    Map<String, dynamic> row,
    _HoldingColumnFeatures feature,
    void Function(Map<String, dynamic> row)? onEdit,
    void Function(Map<String, dynamic> row)? onHistory,
    String? organizationDomain,
  ) {
    final holdingKind = row['holdingKind']?.toString() ?? '';
    final recordName = row['recordName']?.toString();
    final localId = row['localId']?.toString();
    final urlPath = row['urlPath']?.toString();
    final genetId = row['genetId']?.toString();
    final holdingLabel = OrganismReferenceLinks(
      recordName: recordName,
      localId: localId,
      urlPath: urlPath,
      genetId: genetId,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final holdingCell =
        holdingKind.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(holdingKind),
                  const SizedBox(height: 2),
                  holdingLabel,
                ],
              )
            : holdingLabel;
    final organismLabel = _organismLabel(row['organismKind']);
    final speciesLabel = row['speciesScientific']?.toString().isNotEmpty == true
        ? row['speciesScientific'].toString()
        : row['speciesCode']?.toString().isNotEmpty == true
        ? row['speciesCode'].toString()
        : row['speciesId']?.toString() ?? '';
    final lifeStage = row['lifeStage']?.toString() ?? '';
    final physicalForm =
        row['physicalForm']?.toString() ??
        '';
    final measurement = formatMeasurementRow(row);
    final siteName = row['siteName']?.toString() ?? '';
    final rawLocationPath = row['groupId']?.toString() ?? '';
    final locationLabel = LocationDisplayService.formatFromPath(
      rawLocationPath.isNotEmpty ? rawLocationPath : null,
      organizationDomain: organizationDomain,
      fallback: siteName,
    );
    final structure = row['structureType']?.toString() ?? '';
    final permit = _formatPermitSummary(row);
    final eventDate = _formatTimestamp(
      row['eventDate']?.toString() ??
          row['lastEventAt']?.toString() ??
          row['createdAt']?.toString(),
    );
    final notes = row['notes']?.toString() ?? '';
    final aliasEntries = _parseAliasEntries(row);

    final cells = <String, SpreadsheetCell>{
      'holding': SpreadsheetCell(child: holdingCell),
      'organism': SpreadsheetCell.text(organismLabel),
      'species': SpreadsheetCell.text(speciesLabel),
      'lifeStage': SpreadsheetCell.text(lifeStage),
      'physicalForm': SpreadsheetCell.text(physicalForm),
      'measurement': SpreadsheetCell.text(
        measurement,
        textAlign: TextAlign.right,
      ),
      'location': SpreadsheetCell.text(locationLabel),
      'structure': SpreadsheetCell.text(structure),
    };

    if (feature.hasAliases) {
      cells['aliases'] = SpreadsheetCell(
        child: SpreadsheetAliasBadges(aliases: aliasEntries),
      );
    }

    cells.addAll({
      'permit': SpreadsheetCell.text(permit),
      'eventDate': SpreadsheetCell.text(eventDate),
      'notes': SpreadsheetCell.text(notes),
    });

    if (feature.hasLineIdentifier) {
      cells['lineIdentifier'] = SpreadsheetCell.text(
        row['lineIdentifier']?.toString() ?? row['lineId']?.toString() ?? '',
      );
    }
    if (feature.hasLineLength) {
      final length = row['lineLengthMeters'];
      cells['lineLengthMeters'] = SpreadsheetCell.text(
        length == null || length.toString().isEmpty
            ? ''
            : '${length.toString()} m',
        textAlign: TextAlign.right,
      );
    }
    if (feature.hasParentProvenances) {
      cells['parentProvenanceIds'] = SpreadsheetCell.text(
        (row['parentProvenanceIds'] ?? '').toString(),
      );
    }
    if (feature.hasSettlementWindow) {
      cells['settlementWindow'] = SpreadsheetCell.text(
        _formatSettlementWindow(
          row['settlementWindowStart'],
          row['settlementWindowEnd'],
        ),
      );
    }

    if (feature.showActions) {
      cells['actions'] = SpreadsheetCell(
        child: Wrap(
          spacing: 8,
          children: [
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit record',
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => onEdit(row),
              ),
            if (onHistory != null)
              IconButton(
                tooltip: 'Change history',
                icon: const Icon(Icons.history, size: 20),
                onPressed: () => onHistory(row),
              ),
          ],
        ),
      );
    }

    return SpreadsheetRow(
      raw: row,
      key: ValueKey(row['provenanceId'] ?? row.hashCode),
      cells: cells,
    );
  }

  @visibleForTesting
  static String formatMeasurementRow(Map<String, dynamic> row) {
    final parts = <String>[];
    final measurementField = row['measurement'];
    if (measurementField is Map<String, dynamic>) {
      final formatted =
          _formatBaseMeasurement(measurementField['value'], measurementField['unit']);
      if (formatted.isNotEmpty) {
        parts.add(formatted);
      }
    } else {
      final preset = measurementField?.toString().trim() ?? '';
      if (preset.isNotEmpty) {
        parts.add(preset);
      } else {
        final fallback = _formatBaseMeasurement(
          row['quantityValue'] ?? row['measurementValue'],
          row['measurementUnit'],
        );
        if (fallback.isNotEmpty) {
          parts.add(fallback);
        }
      }
    }

    void appendMetric({
      required List<String> keys,
      required String label,
      String? suffix,
    }) {
      final value = _firstNumeric(row, keys);
      if (value == null) return;
      final precision = value % 1 == 0 ? 0 : 1;
      final formatted = value.toStringAsFixed(precision);
      final suffixText = suffix != null && suffix.isNotEmpty ? ' $suffix' : '';
      parts.add('$label: $formatted$suffixText'.trim());
    }

    appendMetric(
      keys: const ['shellHeight_mm', 'shellHeightMm'],
      label: 'Shell',
      suffix: 'mm',
    );
    appendMetric(
      keys: const ['biomass_kg_per_m', 'biomassKgPerM'],
      label: 'Biomass',
      suffix: 'kg/m',
    );
    appendMetric(
      keys: const ['bladeLength_cm', 'bladeLengthCm'],
      label: 'Blade',
      suffix: 'cm',
    );
    appendMetric(
      keys: const ['bladeLength_m', 'bladeLengthM', 'blade_length_m'],
      label: 'Blade',
      suffix: 'm',
    );
    appendMetric(
      keys: const ['salinity_psu', 'salinityPsu'],
      label: 'Salinity',
      suffix: 'PSU',
    );
    appendMetric(
      keys: const ['temperature_c', 'temperatureC'],
      label: 'Temp',
      suffix: '°C',
    );

    return parts.isEmpty ? '' : parts.join(' • ');
  }

  static String _formatBaseMeasurement(dynamic value, dynamic unit) {
    if (value == null) return '';
    final valueText = value.toString().trim();
    if (valueText.isEmpty) return '';
    final unitText = unit?.toString().trim() ?? '';
    return unitText.isEmpty ? valueText : '$valueText $unitText';
  }

  static double? _firstNumeric(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (!row.containsKey(key)) continue;
      final value = row[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static String _formatPermitSummary(Map<String, dynamic> row) {
    final parts = <String>[];
    for (final key in ['permitType', 'permitId', 'issuingAuthority']) {
      final snakeKey = key.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      );
      final value = row[key] ?? row[snakeKey];
      final label = value?.toString().trim() ?? '';
      if (label.isNotEmpty) {
        parts.add(label);
      }
    }
    final protected =
        row['protectedAreaFlag']?.toString().toLowerCase() == 'true';
    if (protected) {
      parts.add('Protected Area');
    }
    return parts.join(' • ');
  }

  static String _organismLabel(dynamic raw) {
    if (raw is OrganismKind) {
      return raw.metadata.displayName;
    }
    if (raw is String && raw.isNotEmpty) {
      final normalized = raw.toLowerCase();
      for (final kind in OrganismKind.values) {
        if (kind.name.toLowerCase() == normalized) {
          return kind.metadata.displayName;
        }
      }
      return raw;
    }
    return raw?.toString() ?? '';
  }

  static String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    final date = DateTime.tryParse(timestamp);
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String _formatSettlementWindow(dynamic start, dynamic end) {
    final startText = _formatTimestamp(start?.toString());
    final endText = _formatTimestamp(end?.toString());
    if (startText.isEmpty && endText.isEmpty) {
      return '';
    }
    if (startText.isEmpty) return endText;
    if (endText.isEmpty) return startText;
    return '$startText → $endText';
  }
}

List<OrganismAlias> _parseAliasEntries(Map<String, dynamic> row) {
  final raw = row['aliasEntries'];
  final entries = <OrganismAlias>[];

  if (raw is Iterable) {
    for (final item in raw) {
      if (item is OrganismAlias) {
        entries.add(item);
      } else if (item is Map<String, dynamic>) {
        entries.add(OrganismAlias.fromJson(item));
      }
    }
  }

  if (entries.isNotEmpty) {
    return List<OrganismAlias>.unmodifiable(entries);
  }

  final aliasLabel = row['aliases']?.toString().trim() ?? '';
  if (aliasLabel.isEmpty) {
    return const <OrganismAlias>[];
  }

  final parsed = aliasLabel
      .split(RegExp(r'[;,]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .map(
        (value) => OrganismAlias(
          sourceSystem: 'custom',
          value: value,
          label: value,
        ),
      )
      .toList(growable: false);
  return List<OrganismAlias>.unmodifiable(parsed);
}

class _HoldingColumnFeatures {
  _HoldingColumnFeatures({
    required this.organismKind,
    required this.hasLineIdentifier,
    required this.hasLineLength,
    required this.hasParentProvenances,
    required this.hasSettlementWindow,
    required this.hasAliases,
    required this.measurementLabel,
    required this.structureLabel,
    required this.showActions,
  });

  factory _HoldingColumnFeatures.fromRows(
    List<Map<String, dynamic>> rows,
    OrganismKind organismKind, {
    bool showActions = false,
  }) {
    bool hasLineId = false;
    bool hasLineLength = false;
    bool hasParents = false;
    bool hasSettlement = false;
    bool hasAliases = false;

    for (final row in rows) {
      final lineId = row['lineIdentifier'] ?? row['lineId'];
      hasLineId = hasLineId || _hasValue(lineId);
      hasLineLength = hasLineLength || _hasValue(row['lineLengthMeters']);
      hasParents = hasParents || _hasValue(row['parentProvenanceIds']);
      hasSettlement =
          hasSettlement ||
          _hasValue(row['settlementWindowStart']) ||
          _hasValue(row['settlementWindowEnd']);
      hasAliases = hasAliases || _hasAliases(row);
    }

    final metadata = organismKind.metadata;
    final measurementUnit =
        MeasurementUnitX.tryParse(metadata.defaultMeasurementUnit) ??
        MeasurementUnit.count;

    return _HoldingColumnFeatures(
      organismKind: organismKind,
      hasLineIdentifier: hasLineId,
      hasLineLength: hasLineLength,
      hasParentProvenances: hasParents,
      hasSettlementWindow: hasSettlement,
      hasAliases: hasAliases,
      measurementLabel: 'Measurement (${measurementUnit.label})',
      structureLabel: _resolveStructureLabel(metadata),
      showActions: showActions,
    );
  }

  final OrganismKind organismKind;
  final bool hasLineIdentifier;
  final bool hasLineLength;
  final bool hasParentProvenances;
  final bool hasSettlementWindow;
  final bool hasAliases;
  final String measurementLabel;
  final String structureLabel;
  final bool showActions;

  List<SpreadsheetColumn> buildColumns() {
    final columns = <SpreadsheetColumn>[
      const SpreadsheetColumn(key: 'holding', title: 'Holding', width: 240),
      const SpreadsheetColumn(key: 'organism', title: 'Organism', width: 140),
      const SpreadsheetColumn(key: 'species', title: 'Species', width: 220),
      const SpreadsheetColumn(
        key: 'lifeStage',
        title: 'Life Stage',
        width: 160,
      ),
      const SpreadsheetColumn(
        key: 'physicalForm',
        title: 'Physical Form',
        width: 160,
      ),
      SpreadsheetColumn(
        key: 'measurement',
        title: measurementLabel,
        width: 170,
        alignment: Alignment.centerRight,
      ),
      const SpreadsheetColumn(key: 'location', title: 'Location', width: 220),
      SpreadsheetColumn(key: 'structure', title: structureLabel, width: 180),
    ];

    if (hasAliases) {
      columns.add(
        const SpreadsheetColumn(
          key: 'aliases',
          title: 'Aliases',
          width: 220,
        ),
      );
    }

    if (hasLineIdentifier) {
      columns.add(
        const SpreadsheetColumn(
          key: 'lineIdentifier',
          title: 'Line ID',
          width: 150,
        ),
      );
    }
    if (hasLineLength) {
      columns.add(
        const SpreadsheetColumn(
          key: 'lineLengthMeters',
          title: 'Line Length (m)',
          width: 150,
          alignment: Alignment.centerRight,
        ),
      );
    }
    if (hasParentProvenances) {
      columns.add(
        const SpreadsheetColumn(
          key: 'parentProvenanceIds',
          title: 'Parent Provenances',
          width: 220,
        ),
      );
    }
    if (hasSettlementWindow) {
      columns.add(
        const SpreadsheetColumn(
          key: 'settlementWindow',
          title: 'Settlement Window',
          width: 200,
        ),
      );
    }

    columns.addAll(const [
      SpreadsheetColumn(key: 'permit', title: 'Permit', width: 240),
      SpreadsheetColumn(key: 'eventDate', title: 'Event Date', width: 150),
      SpreadsheetColumn(key: 'notes', title: 'Notes', width: 220),
    ]);

    if (showActions) {
      columns.add(
        const SpreadsheetColumn(key: 'actions', title: 'Actions', width: 120),
      );
    }

    return columns;
  }

  static bool _hasValue(dynamic raw) {
    if (raw == null) return false;
    if (raw is Iterable) {
      return raw.isNotEmpty;
    }
    final text = raw.toString().trim();
    return text.isNotEmpty;
  }

  static String _resolveStructureLabel(OrganismKindMetadata metadata) {
    for (final id in metadata.supportedStructureTypes) {
      final groupType = GroupType.builtins[id];
      if (groupType != null && groupType.name.isNotEmpty) {
        return groupType.name;
      }
    }
    return 'Structure';
  }

  static bool _hasAliases(Map<String, dynamic> row) {
    final rawEntries = row['aliasEntries'];
    if (rawEntries is Iterable && rawEntries.isNotEmpty) {
      return true;
    }
    final aliasLabel = row['aliases']?.toString().trim() ?? '';
    return aliasLabel.isNotEmpty;
  }
}
