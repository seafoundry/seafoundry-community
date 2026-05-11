import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/services/csv/csv_versioning_service.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';

void validateCsvVersion({
  required CSVImportType importType,
  required Map<String, String> metadata,
  required CsvVersioningService versioningService,
}) {
  final version = _metadataValue(metadata, _versionKeys);
  if (version == null || version.isEmpty) {
    throw const FormatException(
      'Missing provenanceCsvVersion metadata (legacy sfCsvVersion also accepted). '
      'Please re-export the latest template and try again.',
    );
  }

  final templateKind = resolveTemplateKind(importType, metadata);
  versioningService.enforceSupportedVersion(templateKind, version);
}

CsvTemplateKind resolveTemplateKind(
  CSVImportType type,
  Map<String, String> metadata,
) {
  final templateName = _metadataValue(metadata, _templateKeys);
  if (templateName != null && templateName.isNotEmpty) {
    for (final kind in CsvTemplateKind.values) {
      if (kind.name == templateName) {
        return kind;
      }
    }
  }
  return templateKindForImportType(type);
}

const List<String> _versionKeys = [
  'provenanceCsvVersion',
  'sfCsvVersion',
];

const List<String> _templateKeys = [
  'provenanceCsvTemplate',
  'sfCsvTemplate',
];

String? _metadataValue(Map<String, String> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

CsvTemplateKind templateKindForImportType(CSVImportType type) {
  switch (type) {
    case CSVImportType.genetics:
      return CsvTemplateKind.genetics;
    case CSVImportType.inventory:
      return CsvTemplateKind.inventory;
    case CSVImportType.outplanting:
      return CsvTemplateKind.outplantConsolidated;
  }
}
