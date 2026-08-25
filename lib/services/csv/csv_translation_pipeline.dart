import 'package:flutter/foundation.dart';
import 'package:seafoundry_community/constants/csv_schema.dart';
import 'package:seafoundry_community/services/csv/adapters/csv_translation_adapter.dart';
import 'package:seafoundry_community/services/csv/adapters/csv_translation_adapter_registry.dart';
import 'package:seafoundry_community/services/csv/csv_template_registry.dart';
import 'package:seafoundry_community/services/species_registry.dart';

/// Central pipeline that hands parsed CSV rows to the registered translation
/// adapters. Responsibilities:
/// 1. Verify the requested template has a registered schema (fast failure).
/// 2. Build a [CsvTranslationContext] shared by import/export adapters.
/// 3. Resolve the adapter chain via [CsvTranslationAdapterRegistry].
/// 4. Delegate translation without duplicating adapter-selection logic.
class CsvTranslationPipeline {
  CsvTranslationPipeline._({
    CsvTemplateRegistry? registry,
    CsvTranslationAdapterRegistry? adapterRegistry,
  }) : _registry = registry ?? CsvTemplateRegistry.instance,
       _adapterRegistry =
           adapterRegistry ?? CsvTranslationAdapterRegistry.instance;

  final CsvTemplateRegistry _registry;
  final CsvTranslationAdapterRegistry _adapterRegistry;

  static final CsvTranslationPipeline instance = CsvTranslationPipeline._();

  @visibleForTesting
  factory CsvTranslationPipeline.debug({
    CsvTemplateRegistry? registry,
    CsvTranslationAdapterRegistry? adapterRegistry,
  }) {
    return CsvTranslationPipeline._(
      registry: registry,
      adapterRegistry: adapterRegistry,
    );
  }

  /// Hands parsed import rows to the adapter registered for the supplied
  /// metadata/template combination. Throws if the template kind or adapter
  /// cannot be resolved.
  CsvTranslationResult<String> translateImportRows({
    required CsvTemplateKind kind,
    required Map<String, String> metadata,
    required List<Map<String, String>> rows,
    int rowOffset = 2,
    String? sourceName,
    SpeciesRegistry? speciesRegistry,
  }) {
    final context = _buildContext(
      kind: kind,
      metadata: metadata,
      direction: CsvTranslationDirection.import,
      rowOffset: rowOffset,
      sourceName: sourceName,
      speciesRegistry: speciesRegistry,
    );
    final adapter = _adapterRegistry.adapterFor(context);
    return adapter.translateImport(context, rows);
  }

  /// Routes hydrated rows through the export adapter and returns the adapter's
  /// translated payload (usually a list of string maps). Throws when the
  /// template is unknown or the adapter registry cannot satisfy the request.
  CsvTranslationResult<dynamic> translateExportRows({
    required CsvTemplateKind kind,
    required Map<String, String> metadata,
    required List<Map<String, dynamic>> rows,
    SpeciesRegistry? speciesRegistry,
  }) {
    final context = _buildContext(
      kind: kind,
      metadata: metadata,
      direction: CsvTranslationDirection.export,
      speciesRegistry: speciesRegistry,
    );
    final adapter = _adapterRegistry.adapterFor(context);
    return adapter.translateExport(context, rows);
  }

  /// Ensures the schema is registered before constructing a translation
  /// context. This keeps both directions in sync and gives us a single place
  /// to document the metadata we pass to adapters.
  CsvTranslationContext _buildContext({
    required CsvTemplateKind kind,
    required Map<String, String> metadata,
    required CsvTranslationDirection direction,
    int rowOffset = 2,
    String? sourceName,
    SpeciesRegistry? speciesRegistry,
  }) {
    _registry.schemaFor(kind);
    return CsvTranslationContext(
      kind: kind,
      metadata: metadata,
      direction: direction,
      rowOffset: rowOffset,
      sourceName: sourceName,
      speciesRegistry: speciesRegistry ?? SpeciesRegistry.globalInstance,
    );
  }
}
