import 'package:seafoundry_app/constants/csv_schema.dart';

/// Registry that exposes the canonical schema for each CSV template. Keeping
/// this logic centralized makes it easy for the import/export services to stay
/// in sync.
class CsvTemplateRegistry {
  CsvTemplateRegistry._()
    : _schemas = {
        for (final schema in CsvSchemas.all) schema.kind: schema,
      };

  final Map<CsvTemplateKind, CsvSchema> _schemas;

  static final CsvTemplateRegistry instance = CsvTemplateRegistry._();

  CsvSchema schemaFor(CsvTemplateKind kind) {
    final schema = _schemas[kind];
    if (schema == null) {
      throw ArgumentError('Unsupported CSV template: $kind');
    }
    return schema;
  }
}
