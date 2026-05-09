import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';

/// Utility for validating a single CSV row while collecting structured errors.
class CsvRowValidationContext {
  CsvRowValidationContext({
    required this.rowNumber,
    List<CSVImportError>? sink,
  }) : _sink = sink;

  final int rowNumber;
  final List<CSVImportError>? _sink;
  final List<CSVImportError> _errors = [];

  bool requireField(
    String field,
    String value, {
    String message = 'Field is required',
  }) {
    if (value.trim().isEmpty) {
      addError(field: field, value: value, message: message);
      return false;
    }
    return true;
  }

  bool validateValue(
    String field,
    String value,
    String? Function(String value) validator,
  ) {
    final message = validator(value);
    if (message != null) {
      addError(field: field, value: value, message: message);
      return false;
    }
    return true;
  }

  void addError({
    required String field,
    required String value,
    required String message,
  }) {
    final error = CSVImportError(
      row: rowNumber,
      field: field,
      value: value,
      message: message,
    );
    _errors.add(error);
    _sink?.add(error);
  }

  bool get hasErrors => _errors.isNotEmpty;

  List<CSVImportError> get errors => List.unmodifiable(_errors);
}
