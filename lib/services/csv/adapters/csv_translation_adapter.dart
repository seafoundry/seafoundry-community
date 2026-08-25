import 'package:seafoundry_community/constants/csv_schema.dart';
import 'package:seafoundry_community/services/species_registry.dart';

/// Identifies which direction a translation adapter is operating on.
enum CsvTranslationDirection { import, export }

/// Severity for adapter-detected issues. Errors usually block the row while
/// warnings document automatic corrections.
enum CsvTranslationIssueSeverity { warning, error }

class CsvTranslationIssue {
  const CsvTranslationIssue({
    required this.rowNumber,
    required this.field,
    required this.value,
    required this.message,
    this.severity = CsvTranslationIssueSeverity.error,
  });

  final int rowNumber;
  final String field;
  final String value;
  final String message;
  final CsvTranslationIssueSeverity severity;

  bool get isWarning => severity == CsvTranslationIssueSeverity.warning;
  bool get isError => severity == CsvTranslationIssueSeverity.error;

  String toCsvLine() {
    final cells = <String>[
      rowNumber.toString(),
      field,
      value,
      message,
      severity.name,
    ];
    return cells.map(_escapeCsvCell).join(',');
  }

  static String _escapeCsvCell(String input) {
    if (input.contains(',') || input.contains('"') || input.contains('\n')) {
      return '"${input.replaceAll('"', '""')}"';
    }
    return input;
  }
}

/// Context information shared with adapters so they know which org/template
/// they are translating and what metadata rows were provided.
class CsvTranslationContext {
  const CsvTranslationContext({
    required this.kind,
    required this.metadata,
    required this.direction,
    this.rowOffset = 2,
    this.sourceName,
    this.speciesRegistry,
  });

  final CsvTemplateKind kind;
  final Map<String, String> metadata;
  final CsvTranslationDirection direction;
  final int rowOffset;
  final String? sourceName;
  final SpeciesRegistry? speciesRegistry;

  String? get adapterId =>
      (metadata['provenanceTranslationAdapter'] ??
              metadata['sfTranslationAdapter'])
          ?.toLowerCase()
          .trim();

  String? get orgDomain => metadata['orgDomain']?.toLowerCase().trim();
}

/// Result container produced by adapters. It captures the translated rows along
/// with any blocking or warning issues the adapter noticed.
class CsvTranslationResult<T> {
  const CsvTranslationResult({
    required this.rows,
    this.issues = const <CsvTranslationIssue>[],
    this.adapterId,
    this.blockedRowCount = 0,
  });

  final List<Map<String, T>> rows;
  final List<CsvTranslationIssue> issues;
  final String? adapterId;
  final int blockedRowCount;

  bool get hasIssues => issues.isNotEmpty;

  bool get hasBlockingIssues =>
      issues.any((issue) => issue.severity == CsvTranslationIssueSeverity.error);

  /// Builds a CSV payload that mirrors the UI error-report downloads.
  String? buildIssueCsv() {
    if (issues.isEmpty) return null;
    final buffer = StringBuffer('Row,Field,Value,Message,Severity\n');
    for (final issue in issues) {
      buffer.writeln(issue.toCsvLine());
    }
    return buffer.toString().trimRight();
  }
}

/// Base adapter class. Concrete adapters override [supports] plus at least one
/// of the translation methods to transform rows.
abstract class CsvTranslationAdapter {
  const CsvTranslationAdapter({required this.id});

  final String id;

  bool supports(CsvTranslationContext context);

  CsvTranslationResult<String> translateImport(
    CsvTranslationContext context,
    List<Map<String, String>> rows,
  ) {
    return CsvTranslationResult<String>(
      rows: rows
          .map((row) => Map<String, String>.from(row))
          .toList(growable: false),
      adapterId: id,
    );
  }

  CsvTranslationResult<dynamic> translateExport(
    CsvTranslationContext context,
    List<Map<String, dynamic>> rows,
  ) {
    return CsvTranslationResult<dynamic>(
      rows: rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      adapterId: id,
    );
  }
}
