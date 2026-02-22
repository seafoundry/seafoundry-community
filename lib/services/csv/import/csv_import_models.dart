// @tier: community
import 'dart:typed_data';

import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/services/csv/adapters/csv_translation_adapter.dart';

/// Result of a CSV import operation.
class CSVImportResult {
  const CSVImportResult({
    required this.totalRows,
    required this.successfulImports,
    required this.errors,
    required this.importedGenets,
    required this.importedOrganisms,
    this.updatedOrganisms = const [],
    this.updatedOutplantEvents = const [],
    this.createdMonitoringEvents = const [],
    this.updatedMonitoringEvents = const [],
    this.translationSummary,
  });

  final int totalRows;
  final int successfulImports;
  final List<CSVImportError> errors;
  final List<Genet> importedGenets;
  final List<OrganismRecord> importedOrganisms;
  final List<OrganismRecord> updatedOrganisms;
  final List<OutplantEvent> updatedOutplantEvents;
  final List<MonitoringEventRecord> createdMonitoringEvents;
  final List<MonitoringEventRecord> updatedMonitoringEvents;
  final CsvTranslationSummary? translationSummary;

  /// Returns true if there are any blocking errors (excludes warnings).
  bool get hasErrors => errors.any((e) => e.isBlockingError);

  /// Returns true if there are any warnings (non-blocking errors).
  bool get hasWarnings => errors.any((e) => e.isWarning);

  /// Returns all blocking errors (excludes warnings).
  List<CSVImportError> get blockingErrors =>
      errors.where((e) => e.isBlockingError).toList(growable: false);

  /// Returns all warnings (non-blocking errors).
  List<CSVImportError> get warnings =>
      errors.where((e) => e.isWarning).toList(growable: false);
  double get successRate => totalRows > 0 ? successfulImports / totalRows : 0;

  String get summary {
    return 'Imported $successfulImports of $totalRows rows '
        '(${(successRate * 100).toStringAsFixed(1)}% success)';
  }

  CSVImportResult copyWith({
    int? totalRows,
    int? successfulImports,
    List<CSVImportError>? errors,
    List<Genet>? importedGenets,
    List<OrganismRecord>? importedOrganisms,
    List<OrganismRecord>? updatedOrganisms,
    List<OutplantEvent>? updatedOutplantEvents,
    List<MonitoringEventRecord>? createdMonitoringEvents,
    List<MonitoringEventRecord>? updatedMonitoringEvents,
    CsvTranslationSummary? translationSummary,
  }) {
    return CSVImportResult(
      totalRows: totalRows ?? this.totalRows,
      successfulImports: successfulImports ?? this.successfulImports,
      errors: errors ?? this.errors,
      importedGenets: importedGenets ?? this.importedGenets,
      importedOrganisms: importedOrganisms ?? this.importedOrganisms,
      updatedOrganisms: updatedOrganisms ?? this.updatedOrganisms,
      updatedOutplantEvents:
          updatedOutplantEvents ?? this.updatedOutplantEvents,
      createdMonitoringEvents:
          createdMonitoringEvents ?? this.createdMonitoringEvents,
      updatedMonitoringEvents:
          updatedMonitoringEvents ?? this.updatedMonitoringEvents,
      translationSummary: translationSummary ?? this.translationSummary,
    );
  }
}

/// Captures the outcome of a CSV validation along with the source bytes so
/// callers can re-run the import without prompting for a new file.
class CSVImportSession {
  CSVImportSession({
    required this.bytes,
    required this.result,
    required this.importType,
    required this.metadata,
    required this.fileName,
  });

  final Uint8List bytes;
  final CSVImportResult result;
  final CSVImportType importType;
  final Map<String, String> metadata;
  final String fileName;
}

/// Error that occurred during CSV import.
class CSVImportError {
  const CSVImportError({
    required this.row,
    required this.field,
    required this.value,
    required this.message,
    this.isWarning = false,
  });

  final int row;
  final String field;
  final String value;
  final String message;

  /// If true, this is a non-blocking warning (e.g., fallback used).
  /// Warnings are recorded for user visibility but don't block import.
  final bool isWarning;

  /// Returns true if this is a blocking error (not a warning).
  bool get isBlockingError => !isWarning;

  @override
  String toString() => 'Row $row: $field "$value" - $message';
}

class CsvTranslationSummary {
  const CsvTranslationSummary({
    required this.totalIssues,
    required this.warningCount,
    required this.errorCount,
    required this.blockedRowCount,
    required this.issues,
    this.adapterId,
    this.issueCsv,
  });

  final int totalIssues;
  final int warningCount;
  final int errorCount;
  final int blockedRowCount;
  final List<CsvTranslationIssue> issues;
  final String? adapterId;
  final String? issueCsv;

  bool get hasIssues => totalIssues > 0 || blockedRowCount > 0;
  bool get hasBlockingIssues => errorCount > 0 || blockedRowCount > 0;
  bool get hasWarnings => warningCount > 0;
  bool get canDownloadIssues => issueCsv != null && issueCsv!.isNotEmpty;

  List<CsvTranslationIssue> get blockingIssues =>
      issues.where((issue) => issue.isError).toList(growable: false);

  List<CsvTranslationIssue> get warningIssues =>
      issues.where((issue) => issue.isWarning).toList(growable: false);

  factory CsvTranslationSummary.fromResult(
    CsvTranslationResult<String> result,
  ) {
    final warningCount = result.issues
        .where((issue) => issue.severity == CsvTranslationIssueSeverity.warning)
        .length;
    final errorCount = result.issues
        .where((issue) => issue.severity == CsvTranslationIssueSeverity.error)
        .length;
    return CsvTranslationSummary(
      totalIssues: result.issues.length,
      warningCount: warningCount,
      errorCount: errorCount,
      blockedRowCount: result.blockedRowCount,
      issues: List<CsvTranslationIssue>.unmodifiable(result.issues),
      adapterId: result.adapterId,
      issueCsv: result.buildIssueCsv(),
    );
  }
}

/// Types of CSV imports supported.
enum CSVImportType { genetics, inventory, outplanting, monitoring }

/// Types of conflicts that can occur during CSV import.
enum ConflictType {
  /// Same localId, different species (A1).
  speciesMismatch,

  /// Same localId, different provenance (A2).
  provenanceMismatch,

  /// Same localId, same core data - duplicate row (A3).
  duplicate,

  /// Duplicate rows within the same import file (B1).
  intraFileDuplicate,

  /// Reference to non-existent parent record (C1).
  missingParent,
}

/// Extension for conflict type descriptions.
extension ConflictTypeExtension on ConflictType {
  /// Human-readable description of the conflict.
  String get description {
    switch (this) {
      case ConflictType.speciesMismatch:
        return 'Local ID exists with different species';
      case ConflictType.provenanceMismatch:
        return 'Local ID exists with different provenance';
      case ConflictType.duplicate:
        return 'Duplicate record (skipped)';
      case ConflictType.intraFileDuplicate:
        return 'Duplicate row in import file';
      case ConflictType.missingParent:
        return 'Referenced parent does not exist';
    }
  }

  /// Whether this conflict type blocks the import.
  bool get isBlocking {
    switch (this) {
      case ConflictType.speciesMismatch:
      case ConflictType.provenanceMismatch:
      case ConflictType.intraFileDuplicate:
      case ConflictType.missingParent:
        return true;
      case ConflictType.duplicate:
        return false; // Duplicates are skipped, not errors
    }
  }
}

/// A detected conflict during import validation.
class ImportConflict {
  const ImportConflict({
    required this.type,
    required this.rowNumber,
    required this.localId,
    required this.message,
    this.existingValue,
    this.importValue,
  });

  final ConflictType type;
  final int rowNumber;
  final String localId;
  final String message;
  final String? existingValue;
  final String? importValue;

  /// Converts to CSVImportError for unified error reporting.
  CSVImportError toImportError() {
    return CSVImportError(
      row: rowNumber,
      field: 'localId',
      value: localId,
      message: message,
      isWarning: !type.isBlocking,
    );
  }
}

/// Extension for user-friendly names for CSV import types.
extension CSVImportTypeExtension on CSVImportType {
  String get displayName {
    switch (this) {
      case CSVImportType.genetics:
        return 'Genetics Data';
      case CSVImportType.inventory:
        return 'Inventory Data';
      case CSVImportType.outplanting:
        return 'Outplanting Data';
      case CSVImportType.monitoring:
        return 'Monitoring Data';
    }
  }

  String get description {
    switch (this) {
      case CSVImportType.genetics:
        return 'Import genet records with canonical provenance type, life stage, physical form/size spec metadata, and alias sets.';
      case CSVImportType.inventory:
        return 'Import organism holdings with canonical five-axis data (provenance type, life stage, physical form, size spec) plus location, permit, and geometry context.';
      case CSVImportType.outplanting:
        return 'Import outplanting records and allocation details that include organism kind, provenance/life-stage metadata, and geometry/permit information.';
      case CSVImportType.monitoring:
        return 'Import monitoring observations with provenance-aware organism metadata in addition to cover, bleaching, and disease metrics.';
    }
  }
}
