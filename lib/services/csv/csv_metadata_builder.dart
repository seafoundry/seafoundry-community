import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/services/csv/csv_template_registry.dart';

/// Utility that produces the metadata rows that appear at the top of every CSV
  /// export/import file. Metadata rows follow the same "key,value" structure used
  /// across the app (provenance_csv_version, generated_at, etc.).
class CsvMetadataBuilder {
  CsvMetadataBuilder({CsvTemplateRegistry? registry})
    : _registry = registry ?? CsvTemplateRegistry.instance;

  final CsvTemplateRegistry _registry;

  List<List<String>> buildMetadataRows({
    required CsvTemplateKind kind,
    required String orgDomain,
    DateTime? generatedAt,
    String? versionOverride,
    Map<String, String> extraMetadata = const <String, String>{},
  }) {
    final schema = _registry.schemaFor(kind);
    final version = versionOverride ?? schema.version;
    final timestamp = (generatedAt ?? DateTime.now().toUtc()).toIso8601String();

    final rows = <List<String>>[
      ['provenanceCsvVersion', version],
      ['provenanceCsvTemplate', kind.name],
      ['generatedAt', timestamp],
      ['orgDomain', orgDomain],
    ];

    extraMetadata.forEach((key, value) {
      rows.add([key, value]);
    });

    return rows;
  }
}
