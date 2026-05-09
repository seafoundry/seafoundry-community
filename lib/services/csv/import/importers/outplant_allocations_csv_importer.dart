// @tier: community
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/validation_service.dart';

class OutplantAllocationsCsvImporter {
  OutplantAllocationsCsvImporter({
    required EventRepository eventRepository,
    required OrganismRecordRepository organismRecordRepository,
  }) : _eventRepository = eventRepository,
       _organismRecordRepository = organismRecordRepository;

  final EventRepository _eventRepository;
  final OrganismRecordRepository _organismRecordRepository;

  Future<CSVImportResult> import({
    required List<Map<String, String>> rows,
    bool validateOnly = false,
    Map<String, String>? metadata,
    CsvTranslationSummary? translationSummary,
    int? totalRowCount,
  }) async {
    final errors = <CSVImportError>[];
    final groupedAllocations = <String, List<_OutplantAllocationRow>>{};
    int successCount = 0;
    var unknownRecordCounter = 0;
    final provenanceCache = <String, _ProvenanceResolution>{};
    final organismCache = <String, OrganismRecord?>{};

    const requiredFields = <String>{
      'eventId',
      'allocationIndex',
      'organismId',
      'quantity',
      'sourcePath',
    };

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 2;
      final rowErrors = <CSVImportError>[];

      String read(String key) => (row[key] ?? '').trim();

      String readRecordName() {
        final explicit = read('recordName');
        if (explicit.isNotEmpty) return explicit;
        unknownRecordCounter += 1;
        return 'Unknown $unknownRecordCounter';
      }

      for (final field in requiredFields) {
        final value = read(field);
        if (value.isEmpty) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: field,
              value: value,
              message: 'Field is required',
            ),
          );
        }
      }

      final organismIdValue = read('organismId');
      if (organismIdValue.isNotEmpty &&
          CsvColumnNames.isLegacyProvenanceIdFormat(organismIdValue)) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'organismId',
            value: organismIdValue,
            message: 'organism_id must use a Firestore document ID. '
                'Legacy SF- provenance IDs are not supported.',
          ),
        );
      }
      if (CsvColumnNames.isProvenanceIdFormat(organismIdValue)) {
        final formatError = ValidationService.provenanceId(organismIdValue);
        if (formatError != null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'organismId',
              value: organismIdValue,
              message: formatError,
            ),
          );
        }
      }

      final quantityStr = read('quantity');
      final quantity = int.tryParse(quantityStr);
      if (quantity == null || quantity <= 0) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'quantity',
            value: quantityStr,
            message: 'Quantity must be a positive integer',
          ),
        );
      }

      final allocationIndexStr = read('allocationIndex');
      final allocationIndex = int.tryParse(allocationIndexStr);
      if (allocationIndex == null || allocationIndex < 0) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'allocationIndex',
            value: allocationIndexStr,
            message: 'Allocation index must be zero-based integer',
          ),
        );
      }

      if (rowErrors.isNotEmpty) {
        errors.addAll(rowErrors);
        continue;
      }

      String resolvedOrganismId = organismIdValue;
      if (CsvColumnNames.isProvenanceIdFormat(organismIdValue)) {
        final cachedResolution = provenanceCache[organismIdValue];
        if (cachedResolution != null) {
          if (cachedResolution.organismId == null) {
            rowErrors.add(
              CSVImportError(
                row: rowNum,
                field: 'organismId',
                value: organismIdValue,
                message: cachedResolution.errorMessage ??
                    'Unable to resolve organism for provenance ID.',
              ),
            );
          } else {
            resolvedOrganismId = cachedResolution.organismId!;
          }
        } else {
          final matches = await _organismRecordRepository
              .getByGenetProvenanceId(organismIdValue);
          if (matches.isEmpty) {
            final resolution = _ProvenanceResolution(
              errorMessage:
                  'No organism found for provenance ID "$organismIdValue". '
                  'Provide organism_id with a Firestore document ID.',
            );
            provenanceCache[organismIdValue] = resolution;
            rowErrors.add(
              CSVImportError(
                row: rowNum,
                field: 'organismId',
                value: organismIdValue,
                message: resolution.errorMessage!,
              ),
            );
          } else if (matches.length > 1) {
            final resolution = _ProvenanceResolution(
              errorMessage:
                  'Multiple organisms match provenance ID "$organismIdValue". '
                  'Provide organism_id with a Firestore document ID.',
            );
            provenanceCache[organismIdValue] = resolution;
            rowErrors.add(
              CSVImportError(
                row: rowNum,
                field: 'organismId',
                value: organismIdValue,
                message: resolution.errorMessage!,
              ),
            );
          } else {
            final resolvedId = matches.single.id;
            provenanceCache[organismIdValue] =
                _ProvenanceResolution(organismId: resolvedId);
            resolvedOrganismId = resolvedId;
          }
        }
      }

      if (rowErrors.isNotEmpty) {
        errors.addAll(rowErrors);
        continue;
      }

      if (!organismCache.containsKey(resolvedOrganismId)) {
        final organism = await _organismRecordRepository.getRecordForId(
          resolvedOrganismId,
        );
        organismCache[resolvedOrganismId] = organism;
        if (organism == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'organismId',
              value: resolvedOrganismId,
              message: 'Unknown organism_id. Outplant allocations must '
                  'reference an existing inventory record.',
            ),
          );
        }
      } else if (organismCache[resolvedOrganismId] == null) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'organismId',
            value: resolvedOrganismId,
            message: 'Unknown organism_id. Outplant allocations must '
                'reference an existing inventory record.',
          ),
        );
      }

      if (rowErrors.isNotEmpty) {
        errors.addAll(rowErrors);
        continue;
      }

      final allocation = _OutplantAllocationRow(
        rowNumber: rowNum,
        eventId: read('eventId'),
        allocationIndex: allocationIndex!,
        organismId: resolvedOrganismId,
        recordName: readRecordName(),
        quantity: quantity!,
        sourcePath: read('sourcePath'),
        outplantTagId: read('outplantTagId'),
        tagName: read('tagName'),
        tagPath: read('tagPath'),
      );

      groupedAllocations.putIfAbsent(allocation.eventId, () => []);
      groupedAllocations[allocation.eventId]!.add(allocation);
      successCount++;
    }

    final updatedEvents = <OutplantEvent>[];

    if (!validateOnly && errors.isEmpty) {
      final eventCache = <String, OutplantEvent?>{};
      for (final entry in groupedAllocations.entries) {
        final eventId = entry.key;
        final existingEvent = await _lookupOutplantEvent(eventId, eventCache);
        if (existingEvent == null) {
          errors.add(
            CSVImportError(
              row: entry.value.first.rowNumber,
              field: 'eventId',
              value: eventId,
              message: 'Unknown outplant event identifier',
            ),
          );
          continue;
        }

        final sortedAllocations = List<_OutplantAllocationRow>.from(entry.value)
          ..sort((a, b) => a.allocationIndex.compareTo(b.allocationIndex));

        final replacement = <OutplantAllocation>[];
        for (var index = 0; index < sortedAllocations.length; index++) {
          final allocation = sortedAllocations[index];
          final previous = index < existingEvent.allocations.length
              ? existingEvent.allocations[index]
              : null;
          final organism = organismCache[allocation.organismId];

          replacement.add(
            OutplantAllocation(
              organismId: allocation.organismId,
              recordName: allocation.recordName,
              speciesId: organism?.speciesId ?? previous?.speciesId ?? '',
              genetId: organism != null
                  ? GenetIdResolver.resolve(organism)
                  : previous?.genetId,
              outplantTagId: allocation.outplantTagId?.isEmpty ?? true
                  ? null
                  : allocation.outplantTagId,
              tagName: allocation.tagName?.isEmpty ?? true
                  ? null
                  : allocation.tagName,
              tagPath: allocation.tagPath?.isEmpty ?? true
                  ? null
                  : allocation.tagPath,
              quantity: allocation.quantity,
              sourcePath: allocation.sourcePath,
              snapshot: previous?.snapshot,
            ),
          );
        }

        final now = DateTime.now().toIso8601String();
        final updatedEvent = existingEvent.copyWith(
          allocations: replacement,
          updatedAt: now,
        );

        await _eventRepository.updateRecord(updatedEvent);
        updatedEvents.add(updatedEvent);
      }
    }

    return CSVImportResult(
      totalRows: totalRowCount ?? rows.length,
      successfulImports: successCount,
      errors: errors,
      importedGenets: const [],
      importedOrganisms: const [],
      updatedOutplantEvents: updatedEvents,
      translationSummary: translationSummary,
    );
  }

  Future<OutplantEvent?> _lookupOutplantEvent(
    String eventId,
    Map<String, OutplantEvent?> cache,
  ) async {
    if (cache.containsKey(eventId)) return cache[eventId];
    final record = await _eventRepository.getRecordForId(eventId);
    final outplant = record is OutplantEvent ? record : null;
    cache[eventId] = outplant;
    return outplant;
  }
}

class _OutplantAllocationRow {
  const _OutplantAllocationRow({
    required this.rowNumber,
    required this.eventId,
    required this.allocationIndex,
    required this.organismId,
    required this.recordName,
    required this.quantity,
    required this.sourcePath,
    this.outplantTagId,
    this.tagName,
    this.tagPath,
  });

  final int rowNumber;
  final String eventId;
  final int allocationIndex;
  final String organismId;
  final String recordName;
  final int quantity;
  final String sourcePath;
  final String? outplantTagId;
  final String? tagName;
  final String? tagPath;
}

class _ProvenanceResolution {
  const _ProvenanceResolution({this.organismId, this.errorMessage});

  final String? organismId;
  final String? errorMessage;
}
