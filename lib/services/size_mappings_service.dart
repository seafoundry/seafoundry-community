import 'dart:collection';

import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:yaml/yaml.dart';

class SizeBand {
  const SizeBand({required this.code, required this.unit, this.min, this.max});

  final String code;
  final String unit;
  final double? min;
  final double? max;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'unit': unit,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };

  factory SizeBand.fromJson(Map<String, dynamic> json) {
    return SizeBand(
      code: json['code']?.toString() ?? 'UNKNOWN',
      unit: json['unit']?.toString() ?? 'count',
      min: safeDouble(json['min']),
      max: safeDouble(json['max']),
    );
  }
}

/// Loads and serves per-organism/per-physical-form size band definitions. Admin
/// tooling can override the defaults by creating a new instance with merged
/// data; dialogs can then call [bandsFor] to populate dropdowns.
class SizeMappingsService {
  SizeMappingsService._(this._bands);

  factory SizeMappingsService.empty() =>
      SizeMappingsService._(<OrganismKind, Map<String, List<SizeBand>>>{});

  final Map<OrganismKind, Map<String, List<SizeBand>>> _bands;

  // ---------------------------------------------------------------------------
  // Hardcoded defaults (previously loaded from size_mappings.defaults.yaml)
  // ---------------------------------------------------------------------------

  static final SizeMappingsService _defaults = SizeMappingsService._({
    OrganismKind.coral: UnmodifiableMapView(<String, List<SizeBand>>{
      'fragment': List<SizeBand>.unmodifiable(const [
        SizeBand(code: 'XS', unit: 'cm', max: 5),
        SizeBand(code: 'S', unit: 'cm', min: 5, max: 10),
        SizeBand(code: 'M', unit: 'cm', min: 10, max: 20),
        SizeBand(code: 'L', unit: 'cm', min: 20),
      ]),
      'microfragment': List<SizeBand>.unmodifiable(const [
        SizeBand(code: 'XS', unit: 'cm', max: 1),
        SizeBand(code: 'S', unit: 'cm', min: 1, max: 2),
      ]),
      'settlement_substrate': List<SizeBand>.unmodifiable(const [
        SizeBand(code: 'Standard', unit: 'cm', min: 2, max: 10),
      ]),
    }),
  });

  /// Returns the hardcoded default size mappings.
  static SizeMappingsService defaults() => _defaults;

  Map<OrganismKind, Map<String, List<SizeBand>>> get bands {
    final entries = <OrganismKind, Map<String, List<SizeBand>>>{};
    for (final entry in _bands.entries) {
      entries[entry.key] = Map<String, List<SizeBand>>.unmodifiable(
        entry.value,
      );
    }
    return UnmodifiableMapView(entries);
  }

  List<SizeBand> bandsFor({
    required OrganismKind organismKind,
    required String physicalFormId,
  }) {
    final perOrganism = _bands[organismKind];
    if (perOrganism == null) return const <SizeBand>[];
    final formKey = _normalizeFormId(physicalFormId);
    if (formKey.isEmpty) return const <SizeBand>[];
    return perOrganism[formKey] ?? const <SizeBand>[];
  }

  List<SizeBand> bandsForInstance({
    required OrganismKind organismKind,
    required PhysicalFormInstance form,
  }) {
    return bandsFor(
      organismKind: organismKind,
      physicalFormId: form.formId,
    );
  }

  SizeMappingsService merge(SizeMappingsService overrides) {
    final merged = <OrganismKind, Map<String, List<SizeBand>>>{};
    for (final entry in _bands.entries) {
      merged[entry.key] = Map<String, List<SizeBand>>.from(entry.value);
    }
    overrides._bands.forEach((kind, formMap) {
      merged.putIfAbsent(kind, () => <String, List<SizeBand>>{});
      merged[kind]!.addAll(formMap);
    });
    return SizeMappingsService._(merged);
  }

  static SizeMappingsService fromYaml(String yaml) {
    final document = loadYaml(yaml);
    if (document is! YamlMap) {
      return SizeMappingsService.empty();
    }
    final map = <OrganismKind, Map<String, List<SizeBand>>>{};
    document.forEach((dynamic organismKey, dynamic value) {
      final kind = OrganismKindX.tryParse(organismKey?.toString());
      if (kind == null || value is! YamlMap) return;
      final perPhysicalForm = <String, List<SizeBand>>{};
      value.forEach((dynamic formKey, dynamic bandsNode) {
        final formId = _normalizeFormId(formKey?.toString());
        if (formId.isEmpty) return;
        final bands = <SizeBand>[];
        if (bandsNode is YamlList) {
          for (final entry in bandsNode) {
            if (entry is YamlMap) {
              bands.add(
                SizeBand.fromJson(
                  Map<String, dynamic>.from(
                    entry.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                ),
              );
            }
          }
        }
        if (bands.isNotEmpty) {
          perPhysicalForm[formId] = List<SizeBand>.unmodifiable(bands);
        }
      });
      if (perPhysicalForm.isNotEmpty) {
        map[kind] = UnmodifiableMapView(perPhysicalForm);
      }
    });
    return SizeMappingsService._(map);
  }

  static String _normalizeFormId(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final snakeCased = trimmed.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    );
    return snakeCased
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .toLowerCase();
  }
}
