// @tier: community
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_error_reporter.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class CsvOrganismCreator {
  CsvOrganismCreator({
    required OrganismRecordRepository organismRecordRepository,
    required CsvErrorReporter errorReporter,
  })  : _organismRecordRepository = organismRecordRepository,
        _errorReporter = errorReporter;

  final OrganismRecordRepository _organismRecordRepository;
  final CsvErrorReporter _errorReporter;
  final _logger = LoggingService.instance;

  Future<OrganismRecord?> createOrganism({
    required int rowNumber,
    required OrganismRecord organism,
    required Group parentGroup,
    required List<CSVImportError> errors,
    String field = 'organism_creation',
    String? sourceName,
    String Function(DomainError error)? messageBuilder,
  }) async {
    // Validate five-axis constraints before saving
    final validationError = organism.validateFiveAxisConstraints();
    if (validationError != null) {
      _logger.warning(
        'OrganismRecord validation failed for CSV organism: $validationError',
      );
      errors.add(CSVImportError(
        row: rowNumber,
        field: field,
        value: organism.name,
        message: 'Invalid organism record: $validationError',
      ));
      return null;
    }

    // Create organism record
    final createdOrganism = await _errorReporter.guardRow<OrganismRecord>(
      context: 'CsvOrganismCreator.createOrganism',
      operation: () => _organismRecordRepository.createRecord(organism, parentGroup),
      rowNumber: rowNumber,
      field: field,
      value: organism.name,
      errors: errors,
      metadata: {
        'parentGroupId': parentGroup.id,
        'parentGroupPath': parentGroup.urlPath,
        if (sourceName != null) 'sourceName': sourceName,
      },
      messageBuilder: messageBuilder,
    );

    return createdOrganism;
  }
}
