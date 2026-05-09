// @tier: community
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/constants/genetics_csv_keys.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_organism_creator.dart';
import 'package:seafoundry_app/services/csv/import/csv_error_reporter.dart';
import 'package:seafoundry_app/services/csv/import/csv_genet_creator.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/csv_validation_service.dart';
import 'package:seafoundry_app/services/error_reporter.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/validation_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';

class GeneticsCsvImporter {
  GeneticsCsvImporter({
    required GenetRepository genetRepository,
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
    required ErrorReporter errorReporter,
  }) : _genetRepository = genetRepository,
       _organismRecordRepository = organismRecordRepository,
       _groupRepository = groupRepository,
       _errorReporter = errorReporter {
    _csvErrorReporter = CsvErrorReporter(_errorReporter);
    _genetCreator = CsvGenetCreator(
      genetRepository: _genetRepository,
      errorReporter: _csvErrorReporter,
    );
    _organismCreator = CsvOrganismCreator(
      organismRecordRepository: _organismRecordRepository,
      errorReporter: _csvErrorReporter,
    );
  }

  final GenetRepository _genetRepository;
  final OrganismRecordRepository _organismRecordRepository;
  final GroupRepository _groupRepository;
  final ErrorReporter _errorReporter;
  late final CsvErrorReporter _csvErrorReporter;
  late final CsvGenetCreator _genetCreator;
  late final CsvOrganismCreator _organismCreator;

  Future<CSVImportResult> import({
    required List<Map<String, String>> rows,
    bool validateOnly = false,
    CsvTranslationSummary? translationSummary,
    int? totalRowCount,
  }) {
    return PerformanceAnalyzer.measure(
      'CSVImportService.importGenetics',
      () async {
        final errors = <CSVImportError>[];
        final importedGenets = <Genet>[];
        final importedOrganisms = <OrganismRecord>[];
        final groupCache = <String, Group?>{};
        final formConfigCache = <String, PhysicalFormConfig?>{};
        int successCount = 0;

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          final lookup = _RowLookup(row);
          final rowNum = i + 2; // Header offset + 1-based indexing

          final validation = CsvRowValidationContext(
            rowNumber: rowNum,
            sink: errors,
          );

          final organismKindRaw = lookup.valueFor(GeneticsCsvKeys.organismKindKeys);
          final organismKind = _parseOrganismKind(organismKindRaw);
          if (organismKind == null) {
            validation.addError(
              field: 'organismKind',
              value: organismKindRaw ?? '',
              message: 'Unknown organism kind. Use "coral".',
            );
            continue;
          }

          final speciesCodeRaw = lookup.valueFor(GeneticsCsvKeys.speciesKeys) ?? '';
          final species = _resolveSpecies(speciesCodeRaw);
          if (species == null) {
            validation.addError(
              field: 'Species ID',
              value: speciesCodeRaw,
              message: 'Unknown species code',
            );
            continue;
          }

          final provenanceTypeRaw = lookup.valueFor(GeneticsCsvKeys.provenanceTypeKeys) ?? '';
          final provenanceData = _parseProvenanceType(provenanceTypeRaw);
          final genetName = lookup.valueFor(GeneticsCsvKeys.nameKeys) ?? '';
          if (!validation.validateValue(
            'Genet Name',
            genetName,
            ValidationService.genetName,
          )) {
            continue;
          }

          final genetNotesRaw = lookup.valueFor(GeneticsCsvKeys.genetNotesKeys) ?? '';
          final genetNotes = genetNotesRaw.isNotEmpty ? genetNotesRaw : null;
          final rawClonalId = lookup.valueFor(GeneticsCsvKeys.clonalIdKeys) ?? '';
          final rawAccessionNumber =
              lookup.valueFor(GeneticsCsvKeys.accessionNumberKeys) ?? '';
          final rawLocalId = lookup.valueFor(GeneticsCsvKeys.localIdKeys) ?? '';
          final rawProvenanceId = lookup.valueFor(GeneticsCsvKeys.provenanceIdKeys) ?? '';
          String? localId = rawLocalId.trim().isEmpty ? null : rawLocalId.trim();
          String? provenanceId =
              rawProvenanceId.trim().isEmpty ? null : rawProvenanceId.trim();
          // Phase 2, Team Delta (2D.4): Removed fallback that promoted
          // localId / genetId to provenanceId. genetId is always a Firestore
          // doc ID; provenanceId is always a lineage ID (PID- format).
          // Users must supply an explicit provenanceId column.
          final archivedRaw = lookup.valueFor(GeneticsCsvKeys.archivedKeys) ?? '';
          bool? archivedFlag;
          if (archivedRaw.isNotEmpty) {
            archivedFlag = _parseBooleanFlag(archivedRaw);
            if (archivedFlag == null) {
              validation.addError(
                field: 'archived',
                value: archivedRaw,
                message: 'Archived must be true or false.',
              );
              continue;
            }
          }

          await _errorReporter.guard<void>(
            'GeneticsCsvImporter.importRow',
            () async {
              if (!validateOnly) {
                final aliasEntries = _parseAliasEntries(lookup);
                final parentGameteIds = _parseIdList(
                  lookup.valueFor(GeneticsCsvKeys.parentGameteKeys),
                );
                final donorGenotypeId = lookup.valueFor(GeneticsCsvKeys.donorGenotypeKeys);
                final provenanceMetadata = _buildProvenanceMetadata(
                  lookup,
                  donorGenotypeId,
                );

                final clonalId =
                    rawClonalId.trim().isEmpty ? null : rawClonalId.trim();
                final accessionNumber = rawAccessionNumber.trim().isEmpty
                    ? null
                    : rawAccessionNumber.trim();

                final genetResult = await _genetCreator.ensureGenet(
                  rowNumber: rowNum,
                  genetName: genetName,
                  localId: localId,
                  provenanceId: provenanceId,
                  clonalId: clonalId,
                  accessionNumber: accessionNumber,
                  species: species,
                  provenanceType: provenanceData.provenanceType,
                  lifeStage: provenanceData.lifeStage,
                  notes: genetNotes,
                  archived: archivedFlag ?? false,
                  organismKind: organismKind,
                  aliases: aliasEntries,
                  parentGameteIds: parentGameteIds,
                  donorGenotypeId: donorGenotypeId,
                  provenanceMetadata: provenanceMetadata,
                  errors: errors,
                );
                if (genetResult == null) {
                  return;
                }

                final genet = genetResult.genet;
                if (!validateOnly && archivedFlag != null) {
                  if (archivedFlag) {
                    await _genetRepository.archiveGenet(genet.id);
                  } else {
                    await _genetRepository.restoreGenet(genet.id);
                  }
                }
                if (genetResult.isNew) {
                  importedGenets.add(genet);
                }

                var recordName = (row['Record Name'] ?? '').trim();
                final organismLocalId =
                    (localId != null && localId.trim().isNotEmpty)
                        ? localId.trim()
                        : (genet.localId?.trim().isNotEmpty == true
                              ? genet.localId!.trim()
                              : null);
                if (organismLocalId == null) {
                  validation.addError(
                    field: 'Local ID',
                    value: localId ?? '',
                    message:
                        'Local ID is required for coral organism rows.',
                  );
                  return;
                }

                if (recordName.isEmpty) {
                  recordName = organismLocalId;
                }
                if (recordName.isEmpty) {
                  validation.addError(
                    field: 'Record Name',
                    value: recordName,
                    message:
                        'Record Name is required for coral organism rows.',
                  );
                  return;
                }

                if (!validation.validateValue(
                  'Record Name',
                  recordName,
                  ValidationService.recordName,
                )) {
                  return;
                }

                final quantityStr = (row['Quantity'] ?? '1').trim();
                if (!validation.validateValue(
                  'Quantity',
                  quantityStr,
                  ValidationService.quantity,
                )) {
                  return;
                }
                final quantity = int.tryParse(quantityStr);
                if (quantity == null) {
                  validation.addError(
                    field: 'Quantity',
                    value: quantityStr,
                    message: 'Invalid number format',
                  );
                  return;
                }

                final sizeStr = (row['Size'] ?? '0').trim();
                double? size;
                if (sizeStr.isNotEmpty && sizeStr != '0') {
                  if (!validation.validateValue(
                    'Size',
                    sizeStr,
                    ValidationService.coralSize,
                  )) {
                    return;
                  }
                  size = double.tryParse(sizeStr);
                  if (size == null) {
                    validation.addError(
                      field: 'Size',
                      value: sizeStr,
                      message: 'Invalid number format',
                    );
                    return;
                  }
                }

                final parentGroupPath = _resolveGroupPath(row);
                Group? parentGroup;
                if (parentGroupPath != null && parentGroupPath.isNotEmpty) {
                  parentGroup = await _lookupGroup(
                    parentGroupPath,
                    groupCache,
                  );
                  if (parentGroup == null) {
                    validation.addError(
                      field: 'Group Path',
                      value: parentGroupPath,
                      message: 'Parent group not found. Verify the URL path.',
                    );
                    return;
                  }
                } else {
                  validation.addError(
                    field: 'Group Path',
                    value: parentGroupPath ?? '',
                    message:
                        'Parent group path required when creating organisms.',
                  );
                  return;
                }

                final physicalFormId = _resolvePhysicalFormId(row);
                if (physicalFormId == null) {
                  final rawType = _readPhysicalFormValue(row) ?? '';
                  validation.addError(
                    field: 'Physical Form',
                    value: rawType,
                    message:
                        'Unable to determine physical form. Provide a valid physical form name or ID.',
                  );
                  return;
                }
                var sizeBandId = _resolveSizeBandId(row);
                var formConfig = formConfigCache[physicalFormId];
                if (!formConfigCache.containsKey(physicalFormId)) {
                  formConfig = PhysicalFormRegistry.instance
                      .getFormConfig(
                    organismKind,
                    provenanceData.lifeStage ?? LifeStage.juvenile,
                    physicalFormId,
                  );
                  formConfigCache[physicalFormId] = formConfig;
                }
                if (sizeBandId == null || sizeBandId.isEmpty) {
                  sizeBandId = formConfig?.defaultSizeBand?.id;
                }
                if (sizeBandId == null || sizeBandId.isEmpty) {
                  validation.addError(
                    field: 'sizeBandId',
                    value: '',
                    message:
                        'Missing sizeBandId and no default size band is configured for this physical form.',
                  );
                  return;
                }

                final organismNotesRaw =
                    (row['Coral Notes'] ?? row['Notes'] ?? '').trim();
                final organismNotes = organismNotesRaw.isNotEmpty
                    ? organismNotesRaw
                    : null;

                final Group group = parentGroup;

                // Create OrganismRecord with metadata for coral fields
                final foreignKeyMetadata = <String, dynamic>{
                  if (genet.localId != null) 'localId': genet.localId,
                  'provenanceId': genet.provenanceId,
                  'displayName': genet.displayName,
                };
                final foreignKeys = <String, ForeignKeyReference>{
                  'genetId': ForeignKeyReference(
                    id: genet.id,
                    metadata: foreignKeyMetadata,
                  ),
                };

                final sizeSpec = size != null
                    ? SizeSpec(
                        measuredDimension: size,
                        dimensionUnit: MeasurementUnit.centimeter,
                      )
                    : null;

                final organismPartial = OrganismRecord.partial(
                  organismKind: organismKind,
                  speciesId: species.id,
                  recordName: recordName,
                  localId: organismLocalId,
                  measurement: PopulationMeasurement(
                    value: quantity.toDouble(),
                    unit: MeasurementUnit.count,
                  ),
                  lifeStage: LifeStageSpec(stage: LifeStage.juvenile),
                  physicalForm: PhysicalFormInstance(
                    formId: physicalFormId,
                    sizeBandId: sizeBandId,
                  ),
                  sizeSpec: sizeSpec,
                  foreignKeys: foreignKeys,
                  metadata: {
                    'physicalFormId': physicalFormId,
                    if (size != null) 'actualSizeCm': size,
                    if (organismNotes != null) 'notes': organismNotes,
                  },
                );

                final organism = await _organismCreator.createOrganism(
                  rowNumber: rowNum,
                  organism: organismPartial,
                  parentGroup: group,
                  errors: errors,
                  messageBuilder: (error) => _describeRecordCreationFailure(
                    error,
                    parentGroup: group,
                    recordName: recordName,
                  ),
                );
                if (organism == null) {
                  return;
                }
                importedOrganisms.add(organism);
              }

              successCount++;
            },
            category: AppErrorCategory.data,
            metadata: {
              'row': rowNum,
              'mode': validateOnly ? 'validate' : 'import',
            },
          );
        }

        return CSVImportResult(
          totalRows: totalRowCount ?? rows.length,
          successfulImports: successCount,
          errors: errors,
          importedGenets: importedGenets,
          importedOrganisms: importedOrganisms,
          translationSummary: translationSummary,
        );
      },
      metadata: {
        'totalRows': totalRowCount ?? rows.length,
        'validateOnly': validateOnly,
      },
    );
  }

  Species? _resolveSpecies(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return SpeciesRegistry.globalById(normalized.toLowerCase());
  }

  /// Parse provenance type strings using canonical ProvenanceTypeX.tryParse
  _ProvenanceData _parseProvenanceType(String provenanceTypeRaw) {
    final normalized = provenanceTypeRaw.trim();

    // Handle empty/default case
    if (normalized.isEmpty) {
      return const _ProvenanceData(provenanceType: ProvenanceType.wild);
    }

    // Use canonical parsing from ProvenanceTypeX which handles all aliases
    final provenanceType = ProvenanceTypeX.tryParse(normalized);
    if (provenanceType != null) {
      return _ProvenanceData(
        provenanceType: provenanceType,
        lifeStage: provenanceType.defaultLifeStage,
      );
    }

    // Default to wild for unknown values
    return const _ProvenanceData(provenanceType: ProvenanceType.wild);
  }

  Future<Group?> _lookupGroup(String urlPath, Map<String, Group?> cache) async {
    if (cache.containsKey(urlPath)) return cache[urlPath];
    final snapshot = await _groupRepository.collectionRef
        .where('urlPath', isEqualTo: urlPath)
        .limit(1)
        .get();
    Group? group;
    if (snapshot.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(snapshot.docs.first.data());
      data['id'] = snapshot.docs.first.id;
      group = Group.fromJson(data);
    }
    cache[urlPath] = group;
    return group;
  }

  String? _resolveGroupPath(Map<String, String> row) {
    const candidateKeys = [
      'groupId',
    ];

    for (final key in candidateKeys) {
      final value = row[key];
      if (value != null) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return null;
  }

  /// Resolves a physical form ID from the row using the
  /// `physicalFormId` (preferred) or `physicalForm` columns.
  String? _resolvePhysicalFormId(Map<String, String> row) {
    return _readPhysicalFormValue(row);
  }

  String? _resolveSizeBandId(Map<String, String> row) {
    const candidateKeys = ['sizeBandId', 'sizeBand'];
    for (final key in candidateKeys) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _readPhysicalFormValue(Map<String, String> row) {
    const candidateKeys = [
      // Inventory-centric physical form id (preferred)
      'physicalFormId',
      'physicalForm',
    ];

    for (final key in candidateKeys) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _describeRecordCreationFailure(
    DomainError error, {
    required Group parentGroup,
    required String recordName,
  }) {
    final location = _formatGroupLocation(parentGroup);
    final baseMessage = 'Failed to create record "$recordName" in $location';
    final underlying = error.originalError ?? error;

    if (underlying is FirebaseException) {
      final code = underlying.code;
      final message = (underlying.message ?? '').trim();
      switch (code) {
        case 'permission-denied':
          return '$baseMessage: permission denied. Verify that your account has inventory write access.';
        case 'already-exists':
        case 'duplicate':
          return '$baseMessage: a record with the same identifier already exists.';
        case 'not-found':
          return '$baseMessage: the parent group could not be found. Refresh your data and retry.';
        case 'deadline-exceeded':
        case 'unavailable':
          return '$baseMessage: the service was temporarily unavailable. Try again shortly.';
        case 'invalid-argument':
          if (message.isNotEmpty) {
            return '$baseMessage: $message';
          }
          return '$baseMessage: one or more required fields are invalid.';
        default:
          if (message.isNotEmpty) {
            return '$baseMessage: $message';
          }
          return '$baseMessage: unexpected Firebase error ($code).';
      }
    }

    if (underlying is FormatException || underlying is StateError) {
      return '$baseMessage: ${underlying.toString()}';
    }

    if (error.message.isNotEmpty) {
      return '$baseMessage: ${error.message}';
    }

    if (error.technicalDetails != null &&
        error.technicalDetails!.trim().isNotEmpty) {
      return '$baseMessage: ${error.technicalDetails}';
    }

    return '$baseMessage: ${underlying.toString()}';
  }

  String _formatGroupLocation(Group group) {
    final segments = <String>[];
    final name = group.name.trim();
    if (name.isNotEmpty) {
      segments.add(name);
    }

    final urlPath = group.urlPath.trim();
    if (urlPath.isNotEmpty) {
      segments.add(urlPath);
    }

    final id = group.id.trim();
    if (id.isNotEmpty) {
      segments.add('#$id');
    }

    if (segments.isEmpty) {
      return 'the selected parent group';
    }

    return segments.join(' · ');
  }

  bool? _parseBooleanFlag(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'n') {
      return false;
    }
    return null;
  }
}

OrganismKind? _parseOrganismKind(String? raw) {
  if (raw == null || raw.isEmpty) {
    return OrganismKind.coral;
  }
  final normalized = raw.trim().toLowerCase();
  for (final kind in OrganismKind.values) {
    if (kind.name.toLowerCase() == normalized) {
      return kind;
    }
  }
  return null;
}

List<OrganismAlias>? _parseAliasEntries(_RowLookup lookup) {
  final structuredRaw = lookup.valueFor(const [
    'aliasEntries',
    'aliasEntriesJson',
  ]);
  final structured = _decodeAliasEntries(structuredRaw);
  if (structured != null && structured.isNotEmpty) {
    return structured;
  }

  final labelsRaw = lookup.valueFor(const [
    'aliases',
    'aliasLabels',
  ]);
  if (labelsRaw == null || labelsRaw.isEmpty) return null;
  final labels = _splitMultiValue(labelsRaw);
  if (labels.isEmpty) return null;
  final parsed = OrganismAlias.listFromJson(labels);
  return parsed.isEmpty ? null : parsed;
}

List<OrganismAlias>? _decodeAliasEntries(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed == '[]') return null;
  if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Iterable) {
      final parsed = OrganismAlias.listFromJson(decoded);
      return parsed.isEmpty ? null : parsed;
    }
    if (decoded is Map<String, dynamic>) {
      final parsed = OrganismAlias.listFromJson([decoded]);
      return parsed.isEmpty ? null : parsed;
    }
  } catch (e) {
    LoggingService.instance.debug(
      'Failed to JSON-decode alias entries, falling through to string parsing',
      e,
    );
  }
  return null;
}

List<String>? _parseIdList(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final values = _splitMultiValue(raw);
  return values.isEmpty ? null : values;
}

Map<String, dynamic>? _buildProvenanceMetadata(
  _RowLookup lookup,
  String? donorGenotypeId,
) {
  final habitat = lookup.valueFor([
    'provenance.habitatType',
    'provenanceHabitatType',
    'habitatType',
  ]);
  final collectionDate = lookup.valueFor([
    'provenance.collectionDate',
    'provenanceCollectionDate',
    'collectionDate',
  ]);
  final provenanceNotes = lookup.valueFor([
    'provenance.notes',
    'provenanceNotes',
  ]);
  final metadataSummary = lookup.valueFor(['metadata', 'Metadata']);

  final map = <String, dynamic>{};
  if (habitat != null) map['habitatType'] = habitat;
  if (collectionDate != null) map['collectionDate'] = collectionDate;
  if (provenanceNotes != null) map['notes'] = provenanceNotes;
  if (metadataSummary != null &&
      metadataSummary.isNotEmpty &&
      metadataSummary != provenanceNotes) {
    map['summary'] = metadataSummary;
  }
  return map.isEmpty ? null : map;
}

List<String> _splitMultiValue(String raw) {
  return raw
      .split(RegExp(r'[;,]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

class _RowLookup {
  _RowLookup(this.row)
    : _lowercase = {
        for (final entry in row.entries)
          if (entry.key.isNotEmpty) entry.key.toLowerCase(): entry.value,
      };

  final Map<String, String> row;
  final Map<String, String> _lowercase;

  String? valueFor(List<String> keys) {
    for (final key in keys) {
      final direct = row[key];
      if (direct != null && direct.trim().isNotEmpty) {
        return direct.trim();
      }
      final lowered = _lowercase[key.toLowerCase()];
      if (lowered != null && lowered.trim().isNotEmpty) {
        return lowered.trim();
      }
    }
    return null;
  }
}

/// Helper class to hold parsed provenance data from CSV
class _ProvenanceData {
  const _ProvenanceData({
    required this.provenanceType,
    this.lifeStage,
  });

  final ProvenanceType provenanceType;
  final LifeStage? lifeStage;
}
