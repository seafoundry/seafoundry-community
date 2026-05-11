import 'dart:convert';

import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/csv/adapters/csv_translation_adapter.dart';
import 'package:seafoundry_app/services/csv/v2/csv_v2_spec.dart';
import 'package:seafoundry_app/services/csv/v2/csv_v2_spec_extensions.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

part 'universal_csv_adapter_v2_mapper.dart';
part 'universal_csv_adapter_v2_parser.dart';
part 'universal_csv_adapter_v2_validator.dart';

/// Adapter that enforces and normalises the SeaFoundry Universal CSV v2 schema.
/// The adapter does not yet translate rows into organism-specific repositories
/// (that work will follow once repositories adopt `OrganismKind`). Instead, it
/// guarantees that canonical column names exist, required metadata is present,
/// and high-level coherence rules are checked so downstream validators can
/// trust the incoming payload.
class UniversalCsvAdapterV2 extends CsvTranslationAdapter {
  const UniversalCsvAdapterV2() : super(id: adapterKey);

  static const String adapterKey = 'universal_csv_v2';
  static const String templateVersion = '2.0.0';
  static const String _templateName = 'provenance universal csv v2';
  static String get templateName => _templateName;

  /// Minimal required fields for CSV import validation.
  /// Uses 5-axis focused validation instead of full field requirements.
  static const List<String> _requiredFields =
      CsvV2SpecExtensions.minimalInventoryInputs;

  static final List<String> _canonicalColumns =
      CsvV2SpecExtensions.inventoryColumns();

  static final Map<String, OrganismKind> _organismLookup =
      Map<String, OrganismKind>.fromEntries(
        OrganismKind.values.map(
          (kind) => MapEntry(kind.name.toLowerCase(), kind),
        ),
      );

  static const Map<CsvV2LifeStage, List<String>> _lifeStageAliases = {
    CsvV2LifeStage.gamete: ['gametes'],
    CsvV2LifeStage.larvae: ['larva', 'larval'],
    CsvV2LifeStage.recruit: ['recruits'],
    CsvV2LifeStage.juvenile: ['juveniles'],
    CsvV2LifeStage.colony: ['colonies'],
    CsvV2LifeStage.fragment: ['fragments', 'frag', 'frags'],
    CsvV2LifeStage.spat: ['spats'],
    CsvV2LifeStage.growOut: ['grow_out', 'grow-out', 'growout'],
    CsvV2LifeStage.seed: ['seeds'],
    CsvV2LifeStage.shoot: ['shoots'],
    CsvV2LifeStage.plot: ['plots'],
    CsvV2LifeStage.spore: ['spores'],
    CsvV2LifeStage.seededTwine: ['seeded_twine', 'seeded twine'],
    CsvV2LifeStage.longline: ['long_line', 'long-line'],
    CsvV2LifeStage.harvest: ['harvested', 'harvesting'],
    CsvV2LifeStage.propagule: ['propagules'],
    CsvV2LifeStage.nursery: ['nurseries'],
    CsvV2LifeStage.sapling: ['saplings'],
    CsvV2LifeStage.adult: ['adults'],
    CsvV2LifeStage.broodstock: ['brood stock'],
    CsvV2LifeStage.zoea: ['zoeae'],
    CsvV2LifeStage.megalopa: ['megalopae'],
    CsvV2LifeStage.fry: ['larval_fry'],
    CsvV2LifeStage.fingerling: ['fingerlings'],
    CsvV2LifeStage.egg: ['eggs'],
  };

  static final Map<String, CsvV2LifeStage> _lifeStageEnumLookup = () {
    final lookup = <String, CsvV2LifeStage>{};
    for (final stage in CsvV2LifeStage.values) {
      lookup[stage.name.toLowerCase()] = stage;
      final aliases = _lifeStageAliases[stage] ?? const [];
      for (final alias in aliases) {
        lookup[alias.toLowerCase()] = stage;
      }
    }
    return lookup;
  }();

  static final Map<OrganismKind, Set<CsvV2LifeStage>> _lifeStageLookup = {
    for (final entry in CsvV2Spec.lifeStages.entries)
      entry.key: entry.value.toSet(),
  };

  static final Set<String> _measurementUnits = {
    for (final unit in CsvV2MeasurementUnit.values) unit.value.toLowerCase(),
  };

  static const Set<CsvTemplateKind> _inventoryKinds = {
    CsvTemplateKind.inventory,
    CsvTemplateKind.inventoryMinimal,
    CsvTemplateKind.inventoryCoral,
  };

  @override
  bool supports(CsvTranslationContext context) {
    if (!_inventoryKinds.contains(context.kind)) {
      return false;
    }

    final requestedAdapter = context.adapterId;
    final adapterMetadata = _metadataValue(context.metadata, _adapterKeys);
    if (requestedAdapter != null && requestedAdapter != id) {
      return false;
    }

    final template = _metadataValue(
      context.metadata,
      _templateKeys,
    )?.trim().toLowerCase();
    final version = _metadataValue(
      context.metadata,
      _versionKeys,
    )?.trim().toLowerCase();

    final matchesTemplate =
        template == _templateName ||
        _inventoryKinds.any((kind) => kind.name == template);
    final isV2Version =
        version?.startsWith('2.') == true || adapterMetadata == id;
    final adapterRequested = adapterMetadata == id || requestedAdapter == id;

    if (context.direction == CsvTranslationDirection.import) {
      return matchesTemplate || isV2Version || adapterRequested;
    }

    if (context.direction == CsvTranslationDirection.export) {
      return matchesTemplate || adapterRequested || isV2Version;
    }

    return false;
  }

  @override
  CsvTranslationResult<String> translateImport(
    CsvTranslationContext context,
    List<Map<String, String>> rows,
  ) {
    final speciesLookup = _CsvSpeciesLookup.fromContext(context);
    final translatedRows = <Map<String, String>>[];
    final issues = <CsvTranslationIssue>[];
    var blocked = 0;

    for (var i = 0; i < rows.length; i++) {
      final normalized = _canonicalizeRow(rows[i]);
      final rowNumber = context.rowOffset + i;
      final rowIssues = <CsvTranslationIssue>[];
      rowIssues.addAll(validateRow(normalized, rowNumber));

      Map<String, String>? translation;
      if (!rowIssues.any((issue) => issue.isError)) {
        translation = translateImportRow(
          normalized,
          rowNumber: rowNumber,
          issues: rowIssues,
          speciesLookup: speciesLookup,
        );
      }

      issues.addAll(rowIssues);
      if (rowIssues.any((issue) => issue.isError) || translation == null) {
        blocked++;
        continue;
      }
      translatedRows.add(translation);
    }

    return CsvTranslationResult<String>(
      rows: translatedRows,
      issues: issues,
      adapterId: id,
      blockedRowCount: blocked,
    );
  }

  @override
  CsvTranslationResult<dynamic> translateExport(
    CsvTranslationContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final speciesLookup = _CsvSpeciesLookup.fromContext(context);
    final translatedRows = <Map<String, String>>[];
    final issues = <CsvTranslationIssue>[];
    var blocked = 0;

    for (var i = 0; i < rows.length; i++) {
      final rowNumber = context.rowOffset + i;
      final translation = translateExportRow(
        rows[i],
        rowNumber: rowNumber,
        issues: issues,
        speciesLookup: speciesLookup,
      );
      if (translation == null) {
        blocked++;
        continue;
      }
      translatedRows.add(translation);
    }

    return CsvTranslationResult<dynamic>(
      rows: translatedRows,
      issues: issues,
      adapterId: id,
      blockedRowCount: blocked,
    );
  }

  Map<String, String> _canonicalizeRow(Map<String, String> row) {
    final normalized = <String, String>{};
    row.forEach((key, value) {
      final trimmedKey = key.trim();
      if (trimmedKey.isEmpty) return;
      normalized[trimmedKey] = value.trim();
    });

    final canonical = Map<String, String>.from(normalized);
    for (final column in _canonicalColumns) {
      canonical.putIfAbsent(column, () => '');
    }
    // Ensure metric columns exist even if template omitted them
    for (final column in CsvV2SpecExtensions.inventoryMetricColumns) {
      canonical.putIfAbsent(column, () => '');
    }
    return canonical;
  }

  /// Returns the holding kind for a given organism and life stage combination,
  /// or null if the combination should be treated as standard inventory.
  String? holdingKindFor(OrganismKind organism, CsvV2LifeStage? lifeStage) {
    // Dedicated gamete/larval batch holding types removed in sexual propagation
    // simplification. All life stages now use standard organism records.
    return null;
  }

  OrganismKind? parseOrganismKind(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return _organismLookup[value.trim().toLowerCase()];
  }

  CsvV2LifeStage? parseLifeStage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return _lifeStageEnumLookup[value.trim().toLowerCase()];
  }

  static const List<String> _versionKeys = [
    'provenanceCsvVersion',
    'sfCsvVersion',
  ];

  static const List<String> _templateKeys = [
    'provenanceCsvTemplate',
    'sfCsvTemplate',
  ];

  static const List<String> _adapterKeys = [
    'provenanceTranslationAdapter',
    'sfTranslationAdapter',
  ];

  static String? _metadataValue(
    Map<String, String> metadata,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = metadata[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  Map<String, String?> _aliasColumnsForExport(Map<String, dynamic> row) {
    final aliasJson = _coerceAliasJson(
      row['aliasesJson'] ?? row['aliases'] ?? row['aliasEntries'],
    );
    final aliasLabels = _coerceAliasLabels(
      row['aliases'] ?? row['aliasLabels'],
      aliasJson,
    );
    return {'aliasesJson': aliasJson ?? '', 'aliases': aliasLabels ?? ''};
  }

  Map<String, String?> _aliasColumnsForImport(Map<String, String> row) {
    var aliasJson = row['aliasesJson']?.trim();
    final aliasLabels = row['aliases']?.trim();
    if ((aliasJson == null || aliasJson.isEmpty) &&
        aliasLabels != null &&
        aliasLabels.isNotEmpty) {
      final entries = aliasLabels
          .split(RegExp(r'[;,]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .map(
            (value) => {
              'sourceSystem': 'custom',
              'value': value,
              'label': value,
            },
          )
          .toList(growable: false);
      if (entries.isNotEmpty) {
        aliasJson = jsonEncode(entries);
      }
    }
    return {'aliasesJson': aliasJson ?? '', 'aliases': aliasLabels ?? ''};
  }

  String? _coerceAliasJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is Iterable || raw is Map) {
      return jsonEncode(raw);
    }
    return null;
  }

  String? _coerceAliasLabels(dynamic raw, String? aliasJson) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    if (aliasJson != null && aliasJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(aliasJson);
        if (decoded is Iterable) {
          final labels = decoded
              .map((entry) {
                if (entry is Map<String, dynamic>) {
                  return (entry['label'] ?? entry['value'])?.toString();
                }
                if (entry is Map) {
                  return (entry['label'] ?? entry['value'])?.toString();
                }
                return entry?.toString();
              })
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
          if (labels.isNotEmpty) {
            return labels.join('; ');
          }
        }
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to parse alias labels from JSON: $aliasJson',
          e,
          stackTrace,
        );
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Helper classes and functions shared across parts
// ---------------------------------------------------------------------------

class _GeometryTranslation {
  const _GeometryTranslation({
    this.centerLat,
    this.centerLng,
    this.outplantPointsCsv,
  });

  final String? centerLat;
  final String? centerLng;
  final String? outplantPointsCsv;
}

class _Coordinate {
  const _Coordinate({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

class _ExportMeasurement {
  const _ExportMeasurement({required this.value, required this.unit});

  final String value;
  final String unit;

  static _ExportMeasurement fromRow(Map<String, dynamic> row) {
    final quantityValue = row['quantityValue'];
    final measurementUnit = row['measurementUnit'];
    if (quantityValue != null && measurementUnit != null) {
      final value = quantityValue.toString();
      final unit = measurementUnit.toString();
      if (value.isNotEmpty && unit.isNotEmpty) {
        return _ExportMeasurement(value: value, unit: unit);
      }
    }

    final quantity = row['quantityValue'] ?? '0';
    return _ExportMeasurement(value: quantity.toString(), unit: 'count');
  }
}

class _ExportGeometry {
  const _ExportGeometry({this.format, this.wkt});

  final String? format;
  final String? wkt;
}

_ExportGeometry _exportGeometry(Map<String, dynamic> row) {
  final pointsCsv = _string(row['outplantPointsCsv']);
  if (pointsCsv != null && pointsCsv.isNotEmpty) {
    final points = <_Coordinate>[];
    for (final segment in pointsCsv.split(';')) {
      final cleaned = segment.trim();
      if (cleaned.isEmpty) continue;
      final parts = cleaned.split(',');
      if (parts.length != 2) continue;
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) continue;
      points.add(_Coordinate(latitude: lat, longitude: lng));
    }
    if (points.isNotEmpty) {
      final wkt = points.length == 1
          ? 'POINT(${points.first.longitude} ${points.first.latitude})'
          : 'MULTIPOINT(${points.map((point) => '(${point.longitude} ${point.latitude})').join(', ')})';
      return _ExportGeometry(format: 'WKT', wkt: wkt);
    }
  }

  final lat = double.tryParse(_string(row['siteCenterLat']) ?? '');
  final lng = double.tryParse(_string(row['siteCenterLng']) ?? '');
  if (lat != null && lng != null) {
    return _ExportGeometry(format: 'WKT', wkt: 'POINT($lng $lat)');
  }

  return const _ExportGeometry();
}

String _resolveEventDate(Map<String, dynamic> row) {
  final candidates = [row['lastEventAt'], row['updatedAt'], row['createdAt']];
  for (final candidate in candidates) {
    if (candidate == null) continue;
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate;
    }
    if (candidate is DateTime) {
      return candidate.toUtc().toIso8601String();
    }
  }
  return DateTime.now().toUtc().toIso8601String();
}

String? _string(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

ProvenanceLifeStageSelection _provenanceSelectionFromImportRow({
  required Map<String, String> row,
  CsvV2LifeStage? csvStage,
  String? existingLifeStageId,
  String? existingProvenanceType,
}) {
  final sources = <Map<String, dynamic>>[..._canonicalSourcesFromRow(row)];
  void appendValue(String key, String? value) {
    final normalized = _string(value);
    if (normalized != null && normalized.isNotEmpty) {
      sources.add({key: normalized});
    }
  }

  appendValue('lifeStageId', existingLifeStageId);
  appendValue('provenanceType', existingProvenanceType);

  final hasExplicitLifeStage =
      (_string(row['lifeStageId'])?.isNotEmpty ?? false);
  final csvLifeStage = _lifeStageFromCsvStage(csvStage);
  if (!hasExplicitLifeStage) {
    if (csvLifeStage != null) {
      appendValue('lifeStageId', csvLifeStage.id);
    }
  }

  var selection = ProvenanceLifeStageSelection.fromCanonicalSources(
    sources: sources,
    fallbackProvenanceKind: _resolvedProvenanceKind(row, fallback: 'genet'),
  );
  if (!hasExplicitLifeStage) {
    final overrideStage = csvLifeStage;
    if (overrideStage != null) {
      selection = selection.copyWith(lifeStage: overrideStage);
    }
  }
  return selection;
}

ProvenanceLifeStageSelection _provenanceSelectionFromExportRow(
  Map<dynamic, dynamic> row, {
  String? existingLifeStageId,
  String? existingProvenanceType,
}) {
  final sources = <Map<String, dynamic>>[..._canonicalSourcesFromRow(row)];
  void appendValue(String key, String? value) {
    final normalized = _string(value);
    if (normalized != null && normalized.isNotEmpty) {
      sources.add({key: normalized});
    }
  }

  appendValue('lifeStageId', existingLifeStageId);
  appendValue('provenanceType', existingProvenanceType);

  var selection = ProvenanceLifeStageSelection.fromCanonicalSources(
    sources: sources,
    fallbackProvenanceKind: _resolvedProvenanceKind(row, fallback: 'genet'),
  );
  return selection;
}

const List<String> _metadataSourceKeys = <String>[
  'metadata',
  'metadata_raw',
  'metadataRaw',
  'provenanceMetadata',
  'provenance_metadata',
];

List<Map<String, dynamic>> _canonicalSourcesFromRow(Map<dynamic, dynamic> row) {
  final sources = <Map<String, dynamic>>[];
  for (final key in _metadataSourceKeys) {
    final metadata = _coerceMetadataMap(row[key]);
    if (metadata != null && metadata.isNotEmpty) {
      sources.add(metadata);
    }
  }

  final inline = <String, dynamic>{};
  void capture(String canonicalKey, List<String> candidates) {
    for (final candidate in candidates) {
      final value = _string(row[candidate]);
      if (value != null && value.isNotEmpty) {
        inline[canonicalKey] = value;
        break;
      }
    }
  }

  capture('provenanceType', const [
    'provenanceType',
    'provenance_type',
    'provenanceTypeId',
    'provenance_type_id',
  ]);
  capture('provenanceKind', const [
    'provenanceKind',
    'provenance_kind',
    'lineageKind',
    'lineage_kind',
  ]);
  capture('lifeStageId', const ['lifeStageId', 'life_stage_id']);
  capture('lifeStage', const [
    'lifeStage',
    'life_stage',
    'lifeStageLabel',
    'life_stage_label',
    'lifeStageName',
    'life_stage_name',
  ]);

  if (inline.isNotEmpty) {
    sources.add(inline);
  }
  return sources;
}

void _applyMetadataOverrides({
  required Map<dynamic, dynamic> row,
  required Map<String, String> target,
}) {
  final metadata = _firstMetadataSource(row);
  if (metadata == null || metadata.isEmpty) return;

  final metadataLifeStageId = _string(metadata['lifeStageId']);
  final overrideLifeStage = LifeStageX.tryParse(metadataLifeStageId);
  if (overrideLifeStage != null) {
    target['lifeStageId'] = overrideLifeStage.id;
    target['lifeStage'] = overrideLifeStage.name;
    target['lifeStageLabel'] = overrideLifeStage.displayName;
  }

  final metadataProvenanceTypeId =
      _string(metadata['provenanceTypeId']) ??
      _string(metadata['provenanceType']);
  final overrideProvenanceType = ProvenanceTypeX.tryParse(
    metadataProvenanceTypeId,
  );
  if (overrideProvenanceType != null) {
    target['provenanceType'] = overrideProvenanceType.metadata.id;
    target['provenanceTypeLabel'] = overrideProvenanceType.metadata.displayName;
    target['provenanceKind'] =
        overrideProvenanceType.metadata.defaultProvenanceKind.name;
  }
}

Map<String, dynamic>? _firstMetadataSource(Map<dynamic, dynamic> row) {
  for (final key in _metadataSourceKeys) {
    final metadata = _coerceMetadataMap(row[key]);
    if (metadata != null && metadata.isNotEmpty) {
      return metadata;
    }
  }
  return null;
}

Map<String, dynamic>? _coerceMetadataMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    value.forEach((key, entryValue) {
      if (key == null) return;
      final keyString = key.toString().trim();
      if (keyString.isEmpty) return;
      result[keyString] = entryValue;
    });
    return result;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final decoded = jsonDecode(trimmed);
        return _coerceMetadataMap(decoded);
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to decode metadata JSON: $trimmed',
          e,
          stackTrace,
        );
        return null;
      }
    }
  }
  return null;
}

void _applyNormalizedProvenanceType(Map<String, String> translation) {
  final normalizedProvenanceType = _normalizeProvenanceType(
    explicitType: translation['provenanceType'],
  );
  if (normalizedProvenanceType != null) {
    translation['provenanceType'] = normalizedProvenanceType;
  }
}

String? _normalizeProvenanceType({dynamic explicitType}) {
  final explicit = ProvenanceTypeX.tryParse(_string(explicitType));
  if (explicit != null) {
    return explicit.id;
  }
  return null;
}

String? _normalizeLifeStageId({
  dynamic explicitId,
  dynamic label,
  CsvV2LifeStage? csvStage,
}) {
  final explicitStage = LifeStageX.tryParse(_string(explicitId));
  if (explicitStage != null) {
    return explicitStage.id;
  }
  final labelStage = LifeStageX.tryParse(_string(label));
  if (labelStage != null) {
    return labelStage.id;
  }
  final csvDerivedStage = _lifeStageFromCsvStage(csvStage);
  if (csvDerivedStage != null) {
    return csvDerivedStage.id;
  }
  return null;
}

LifeStage? _lifeStageFromCsvStage(CsvV2LifeStage? stage) {
  if (stage == null) return null;
  switch (stage) {
    case CsvV2LifeStage.gamete:
    case CsvV2LifeStage.spore:
    case CsvV2LifeStage.egg:
      return LifeStage.gamete;
    case CsvV2LifeStage.larvae:
    case CsvV2LifeStage.zoea:
    case CsvV2LifeStage.megalopa:
    case CsvV2LifeStage.fry:
    case CsvV2LifeStage.fingerling:
      return LifeStage.larva;
    case CsvV2LifeStage.recruit:
    case CsvV2LifeStage.juvenile:
    case CsvV2LifeStage.fragment:
    case CsvV2LifeStage.spat:
    case CsvV2LifeStage.growOut:
    case CsvV2LifeStage.seed:
    case CsvV2LifeStage.shoot:
    case CsvV2LifeStage.seededTwine:
    case CsvV2LifeStage.longline:
    case CsvV2LifeStage.nursery:
    case CsvV2LifeStage.sapling:
    case CsvV2LifeStage.propagule:
    case CsvV2LifeStage.plot:
      return LifeStage.juvenile;
    case CsvV2LifeStage.colony:
    case CsvV2LifeStage.reef:
    case CsvV2LifeStage.harvest:
    case CsvV2LifeStage.adult:
      return LifeStage.adult;
    case CsvV2LifeStage.broodstock:
      return LifeStage.broodstock;
  }
}

String _resolvedProvenanceKind(
  Map<dynamic, dynamic> source, {
  String fallback = '',
}) {
  return _string(source['provenanceKind']) ??
      _string(source['provenance_kind']) ??
      _string(source['lineageKind']) ??
      _string(source['lineage_kind']) ??
      fallback;
}

class _CsvSpeciesLookup {
  _CsvSpeciesLookup(this._speciesById, this._speciesList);

  factory _CsvSpeciesLookup.fromContext(CsvTranslationContext context) {
    final registry = context.speciesRegistry ?? SpeciesRegistry.globalInstance;
    final snapshot = registry?.asMap ?? SpeciesRegistry.globalMap();
    return _CsvSpeciesLookup(
      snapshot,
      List<Species>.unmodifiable(snapshot.values),
    );
  }

  final Map<String, Species> _speciesById;
  final List<Species> _speciesList;

  Species? byId(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    return _speciesById[id.trim().toLowerCase()];
  }

  Species? byCode(String code) {
    if (code.trim().isEmpty) return null;
    final normalized = code.trim().toLowerCase();
    for (final species in _speciesList) {
      if (species.code.toLowerCase() == normalized ||
          species.id.toLowerCase() == normalized) {
        return species;
      }
    }
    return null;
  }

  Species? byScientific(String scientific) {
    final normalized = scientific.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final species in _speciesList) {
      final canonical =
          '${species.genus.toLowerCase()} ${species.species.toLowerCase()}';
      final shorthand =
          '${species.genus[0].toLowerCase()}. ${species.species.toLowerCase()}';
      if (canonical == normalized || shorthand == normalized) {
        return species;
      }
    }
    return null;
  }
}

String _protectedAreaFlag(dynamic value) => _boolString(value);

String _boolString(dynamic value) {
  if (value == null) return 'false';
  if (value is bool) return value ? 'true' : 'false';
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return 'false';
  return (normalized == 'true' || normalized == '1' || normalized == 'yes')
      ? 'true'
      : 'false';
}
