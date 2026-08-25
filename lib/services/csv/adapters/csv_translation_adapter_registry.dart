import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/services/csv/adapters/csv_translation_adapter.dart';
import 'package:seafoundry_community/services/csv/adapters/genetics_csv_translation_adapter.dart';
import 'package:seafoundry_community/services/csv/adapters/passthrough_csv_adapter.dart';
import 'package:seafoundry_community/services/csv/adapters/universal_csv_adapter_v2.dart';

/// Maintains the ordered list of adapters the translation pipeline can use.
/// Specific adapters should be registered ahead of the fallback passthrough
/// implementation so they get the first opportunity to claim a CSV payload.
class CsvTranslationAdapterRegistry {
  CsvTranslationAdapterRegistry._({List<CsvTranslationAdapter>? adapters})
    : _adapters = List<CsvTranslationAdapter>.from(
        adapters ??
            const [
              GeneticsCsvTranslationAdapter(),
              UniversalCsvAdapterV2(),
              PassthroughCsvAdapter(),
            ],
      );

  final List<CsvTranslationAdapter> _adapters;
  final Set<String> _installedOrgDomains = <String>{};

  static final CsvTranslationAdapterRegistry instance =
      CsvTranslationAdapterRegistry._();

  static final Map<String, List<CsvTranslationAdapter>> _orgAdapterOverrides =
      <String, List<CsvTranslationAdapter>>{};

  UnmodifiableListView<CsvTranslationAdapter> get adapters =>
      UnmodifiableListView<CsvTranslationAdapter>(_adapters);

  @visibleForTesting
  static CsvTranslationAdapterRegistry createForTesting({
    List<CsvTranslationAdapter>? adapters,
  }) {
    return CsvTranslationAdapterRegistry._(adapters: adapters);
  }

  CsvTranslationAdapter adapterFor(CsvTranslationContext context) {
    for (final adapter in _adapters) {
      if (adapter.supports(context)) {
        return adapter;
      }
    }
    return const PassthroughCsvAdapter();
  }

  void registerAdapter(CsvTranslationAdapter adapter, {bool prepend = true}) {
    if (prepend) {
      _adapters.insert(0, adapter);
    } else {
      _adapters.add(adapter);
    }
  }

  /// Hook invoked at startup to allow organization-specific adapter wiring.
  /// Registered adapters are promoted ahead of the default pipeline so partner
  /// translators get the first chance to claim CSV payloads.
  void installAdaptersForOrganization(Organization organization) {
    final domain = organization.domain.trim().toLowerCase();
    if (domain.isEmpty || !_installedOrgDomains.add(domain)) {
      return;
    }

    final overrides = _orgAdapterOverrides[domain];
    if (overrides == null || overrides.isEmpty) {
      return;
    }

    for (final adapter in overrides.reversed) {
      _insertOrPromoteAdapter(adapter);
    }
  }

  void _insertOrPromoteAdapter(CsvTranslationAdapter adapter) {
    final existingIndex = _adapters.indexWhere(
      (entry) => entry.id == adapter.id,
    );
    if (existingIndex != -1) {
      final existing = _adapters.removeAt(existingIndex);
      _adapters.insert(0, existing);
      return;
    }
    _adapters.insert(0, adapter);
  }
}
