import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/services/csv/csv_template_registry.dart';

/// Guards CSV imports against stale template versions. Templates list their
/// canonical version in [CsvSchemas]; this service simply compares the value
/// embedded in the file with the version we currently ship.
class CsvVersioningService {
  CsvVersioningService({CsvTemplateRegistry? registry})
    : _registry = registry ?? CsvTemplateRegistry.instance;

  final CsvTemplateRegistry _registry;

  void enforceSupportedVersion(CsvTemplateKind kind, String version) {
    final schema = _registry.schemaFor(kind);
    final normalized = version.trim();
    if (_matchesSchemaVersion(schema.version, normalized)) {
      return;
    }

    if (kind == CsvTemplateKind.inventory &&
        _isSupportedInventoryVersion(normalized)) {
      return;
    }

    throw FormatException(
      'Unsupported ${kind.name} CSV version "$version". '
      'Expected ${schema.version}. Please re-export the latest template.',
    );
  }

  bool _matchesSchemaVersion(String schemaVersion, String provided) {
    return provided == schemaVersion;
  }

  bool _isSupportedInventoryVersion(String version) {
    return version.startsWith('1.') || version.startsWith('2.');
  }
}
