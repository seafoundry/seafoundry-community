// @tier: community
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_error_reporter.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class CsvGenetCreationResult {
  const CsvGenetCreationResult({required this.genet, required this.isNew});

  final Genet genet;
  final bool isNew;
}

class CsvGenetCreator {
  CsvGenetCreator({
    required GenetRepository genetRepository,
    required CsvErrorReporter errorReporter,
    Future<Genet?> Function(String name)? findGenetByNameOverride,
  }) : _genetRepository = genetRepository,
       _errorReporter = errorReporter,
       _findGenetByNameOverride = findGenetByNameOverride;

  final GenetRepository _genetRepository;
  final CsvErrorReporter _errorReporter;
  final Future<Genet?> Function(String name)? _findGenetByNameOverride;

  Future<CsvGenetCreationResult?> ensureGenet({
    required int rowNumber,
    required String genetName,
    String? localGenetId,
    String? provenanceId,
    String? clonalId,
    String? accessionNumber,
    required Species species,
    required ProvenanceType provenanceType,
    LifeStage? lifeStage,
    String? notes,
    bool archived = false,
    OrganismKind organismKind = OrganismKind.coral,
    List<OrganismAlias>? aliases,
    List<String>? parentGameteIds,
    String? donorGenotypeId,
    Map<String, dynamic>? provenanceMetadata,
    required List<CSVImportError> errors,
  }) async {
    final normalizedProvenanceId = provenanceId?.trim();
    final hasProvenanceId =
        normalizedProvenanceId != null && normalizedProvenanceId.isNotEmpty;

    if (hasProvenanceId) {
      final existingByProvenance = await _lookupGenetByProvenanceId(
        normalizedProvenanceId,
      );
      if (existingByProvenance != null) {
        if (_normalizeName(genetName) !=
            _normalizeName(existingByProvenance.name)) {
          errors.add(
            CSVImportError(
              row: rowNumber,
              field: 'provenanceId',
              value: normalizedProvenanceId,
              message:
                  'PID already exists in this organization; using existing genet '
                  '"${existingByProvenance.name}".',
              isWarning: true,
            ),
          );
        }
        return CsvGenetCreationResult(
          genet: existingByProvenance,
          isNew: false,
        );
      }
    }

    final existing = await _lookupGenetByName(genetName);
    if (existing != null) {
      if (hasProvenanceId &&
          existing.provenanceId.trim().toUpperCase() !=
              normalizedProvenanceId.toUpperCase()) {
        errors.add(
          CSVImportError(
            row: rowNumber,
            field: 'provenanceId',
            value: normalizedProvenanceId,
            message:
                'Ignoring PID for existing genet "${existing.name}". '
                'CSV imports do not accept new PIDs.',
            isWarning: true,
          ),
        );
      }
      return CsvGenetCreationResult(genet: existing, isNew: false);
    }

    return _errorReporter.guardRow<CsvGenetCreationResult>(
      context: 'CsvGenetCreator.ensureGenet',
      operation: () async {
        final slug = await _genetRepository.nextSlugForModelType(
          ModelType.genet,
        );
        if (hasProvenanceId) {
          errors.add(
            CSVImportError(
              row: rowNumber,
              field: 'provenanceId',
              value: normalizedProvenanceId,
              message:
                  'PID not found in this organization. A new PID will be '
                  'assigned from the local ID during import.',
              isWarning: true,
            ),
          );
        }

        final created = await _genetRepository.createGenet(
          Genet.partial(
            name: genetName,
            slug: slug,
            localGenetId: localGenetId?.isNotEmpty == true ? localGenetId : null,
            provenanceId: null,
            clonalId: clonalId?.isNotEmpty == true ? clonalId : null,
            accessionNumber:
                accessionNumber?.isNotEmpty == true ? accessionNumber : null,
            speciesId: species.id,
            provenanceTypeId: provenanceType.id,
            notes: notes,
            archived: archived,
            organismKind: organismKind,
            aliases: aliases
                ?.map((alias) => alias.toJson())
                .toList(growable: false),
            provenance: provenanceMetadata,
          ),
        );
        return CsvGenetCreationResult(genet: created, isNew: true);
      },
      rowNumber: rowNumber,
      field: 'genet_creation',
      value: genetName,
      errors: errors,
      metadata: {
        'genetName': genetName,
        'speciesId': species.id,
        'provenanceType': provenanceType.name,
        if (lifeStage != null) 'lifeStage': lifeStage.name,
        if (localGenetId != null && localGenetId.isNotEmpty) 'localGenetId': localGenetId,
      },
    );
  }

  Future<Genet?> _lookupGenetByProvenanceId(String provenanceId) async {
    try {
      return _genetRepository.getRecordByProvenanceId(
        provenanceId,
        includeArchived: true,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'CsvGenetCreator: error looking up genet by provenanceId "$provenanceId"',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Genet?> _lookupGenetByName(String name) async {
    final override = _findGenetByNameOverride;
    if (override != null) {
      return override(name);
    }
    try {
      return _genetRepository.getRecordByName(
        name,
        includeArchived: true,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'CsvGenetCreator: error looking up genet by name "$name"',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  static String _normalizeName(String value) =>
      value.trim().toLowerCase();
}
