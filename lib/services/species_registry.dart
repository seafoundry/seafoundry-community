// @tier: community
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/taxonomy/species_record.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';

/// Synchronous view of the taxonomy species registry that widgets/cubits can
/// consult without depending on a baked-in coral list. Hydrates itself from
/// [TaxonomyService] (when provided) and exposes
/// alphabetical lists plus helper lookups that rebuild listening widgets when
/// new taxonomy data arrives.
class SpeciesRegistry extends ChangeNotifier {
  SpeciesRegistry({TaxonomyService? taxonomyService, Iterable<Species>? seed})
    : _taxonomyService = taxonomyService,
      _speciesById = _seedMap(seed ?? Species.registry.values) {
    _global ??= this;
  }

  final TaxonomyService? _taxonomyService;
  Map<String, Species> _speciesById;
  bool _hydrated = false;
  static SpeciesRegistry? _global;

  static SpeciesRegistry? get globalInstance => _global;

  /// Returns true once taxonomy data has successfully replaced the builtin map.
  bool get isHydrated => _hydrated;

  /// Alphabetically sorted list of known species.
  List<Species> get all {
    final list = _speciesById.values.toList(growable: false);
    list.sort((a, b) => a.name.compareTo(b.name));
    return List<Species>.unmodifiable(list);
  }

  /// Lookup helper by canonical ID.
  Species? byId(String? id) {
    if (id == null) return null;
    return _speciesById[id.trim().toLowerCase()];
  }

  /// Lookup helper by display code.
  Species? byCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      return null;
    }
    final normalized = code.trim().toLowerCase();
    try {
      return _speciesById.values.firstWhere(
        (species) => species.code.toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  UnmodifiableMapView<String, Species> get asMap =>
      UnmodifiableMapView(_speciesById);

  /// Hydrates the registry from Firestore taxonomy data.
  Future<void> refresh() async {
    final service = _taxonomyService;
    if (service == null) return;
    try {
      final records = await service.listSpecies();
      if (records.isEmpty) return;
      _replaceWithRecords(records);
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'SpeciesRegistry refresh failed',
        error,
        stackTrace,
      );
    }
  }

  /// Installs [registry] as the global lookup source for code paths that cannot
  /// easily receive DI (legacy cubits, background services, etc.).
  static void installGlobal(SpeciesRegistry registry) {
    _global = registry;
    final seededSpecies = registry._speciesById.values;
    if (seededSpecies.isEmpty) {
      Species.reset();
    } else {
      Species.replaceWithSeed(seededSpecies);
    }
  }

  /// Lightweight global lookup used by legacy call sites during the migration.
  /// Falls back to the builtin coral list when the registry has not been
  /// configured yet to maintain offline compatibility.
  static Species? globalById(String? id, {bool allowFallback = true}) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) {
      return allowFallback ? Species.fallback(normalized) : null;
    }
    final registry = _ensureGlobal();
    final species = registry.byId(normalized) ?? registry.byCode(normalized);
    if (species != null) {
      return species;
    }
    final legacyResolved = _resolveLegacyIdentifier(registry, normalized);
    if (legacyResolved != null) {
      return legacyResolved;
    }
    return allowFallback ? Species.fallback(normalized) : null;
  }

  static List<Species> globalAll() {
    final registry = _ensureGlobal();
    return registry.all;
  }

  static UnmodifiableMapView<String, Species> globalMap() {
    final registry = _ensureGlobal();
    return registry.asMap;
  }

  /// Normalizes any species identifier (id, legacy id, or code) to the
  /// canonical registry id. Falls back to a trimmed lowercase value when the
  /// registry cannot resolve the identifier.
  static String? normalizeId(String? rawId) {
    final trimmed = rawId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final resolved = globalById(trimmed, allowFallback: false);
    if (resolved != null) {
      return resolved.id.trim().toLowerCase();
    }
    return trimmed.toLowerCase();
  }

  /// Normalizes a list of identifiers to canonical ids, removing empties.
  static Set<String> normalizeIds(Iterable<String> rawIds) {
    final normalized = <String>{};
    for (final rawId in rawIds) {
      final resolved = normalizeId(rawId);
      if (resolved != null && resolved.isNotEmpty) {
        normalized.add(resolved);
      }
    }
    return normalized;
  }

  void _replaceWithRecords(Iterable<SpeciesRecord> records) {
    final mapped = <String, Species>{};
    for (final record in records) {
      final normalizedId = record.id.trim().toLowerCase();
      if (normalizedId.isEmpty) continue;
      mapped[normalizedId] = Species(
        id: normalizedId,
        species: record.species,
        genus: record.genus,
        morphology: record.morphology,
        tags: record.tags,
        codeOverride: record.code.isEmpty ? null : record.code,
      );
    }

    if (mapped.isEmpty) {
      return;
    }

    _speciesById = mapped;
    _hydrated = true;
    Species.replaceAll(records);
    notifyListeners();
  }

  static Map<String, Species> _seedMap(Iterable<Species> species) {
    final map = <String, Species>{};
    for (final entry in species) {
      map[entry.id.toLowerCase()] = entry;
    }
    return map;
  }

  Future<void> ensureHydrated() async {
    if (_hydrated || _taxonomyService == null) {
      return;
    }
    await refresh();
  }

  static Future<void> ensureGlobalHydrated() async {
    final registry = _global;
    if (registry == null) return;
    await registry.ensureHydrated();
  }

  static SpeciesRegistry _ensureGlobal() {
    if (_global != null) {
      return _global!;
    }
    final seeded = SpeciesRegistry();
    installGlobal(seeded);
    return seeded;
  }

  static Species? _resolveLegacyIdentifier(
    SpeciesRegistry registry,
    String normalized,
  ) {
    if (!normalized.toLowerCase().startsWith('species_')) {
      return null;
    }
    // First, try direct lookup in case legacy ID is registered as an alias
    // TaxonomyService populates aliases into byCode map
    final directMatch = registry.byCode(normalized);
    if (directMatch != null) {
      return directMatch;
    }
    // Fallback: compute code from legacy ID structure
    final fallback = Species.fallback(normalized);
    if (fallback.code.trim().isEmpty) {
      return null;
    }
    return registry.byCode(fallback.code);
  }
}
