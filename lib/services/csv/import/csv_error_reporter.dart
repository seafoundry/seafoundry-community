import 'package:seafoundry_community/errors/domain_errors.dart';
import 'package:seafoundry_community/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_community/services/error_reporter.dart';

/// Helper that converts [DomainError]s thrown during CSV processing into
/// [CSVImportError] records while preserving the centralized [ErrorReporter]
/// instrumentation.
class CsvErrorReporter {
  CsvErrorReporter(this._errorReporter);

  final ErrorReporter _errorReporter;

  Future<T?> guardRow<T>({
    required String context,
    required Future<T> Function() operation,
    required int rowNumber,
    required String field,
    String? value,
    required List<CSVImportError> errors,
    Map<String, Object?>? metadata,
    AppErrorCategory category = AppErrorCategory.data,
    AppErrorSeverity severity = AppErrorSeverity.high,
    String Function(DomainError error)? messageBuilder,
  }) {
    return _errorReporter.guard<T?>(
      context,
      operation,
      category: category,
      severity: severity,
      metadata: metadata,
      onError: (error) {
        errors.add(
          CSVImportError(
            row: rowNumber,
            field: field,
            value: value ?? '',
            message: messageBuilder != null
                ? messageBuilder(error)
                : error.message,
          ),
        );
        return null;
      },
    );
  }
}
