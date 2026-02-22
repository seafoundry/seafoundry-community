// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/taxonomy/species_record.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_kind.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Provides cached access to the canonical species + provenance collections stored
/// in Firestore so repositories, CSV adapters, and dialogs can resolve taxonomy
/// metadata without hard-coding coral-only enums.
class TaxonomyService {
  TaxonomyService({
    required FirebaseFirestore firestore,
    Duration cacheTtl = const Duration(minutes: 30),
    FirestoreCollectionResolver? resolver,
  }) : _firestore = firestore,
       _cacheTtl = cacheTtl,
       _resolver = resolver ?? FirestoreCollectionResolver.instance;

  static const String speciesCollectionPath = 'taxonomy_species';
  static const String provenanceCollectionPath = 'taxonomy_provenances';
  static const String _legacyLineageCollectionPath = 'taxonomy_lineages';

  final FirebaseFirestore _firestore;
  final Duration _cacheTtl;
  final FirestoreCollectionResolver _resolver;

  Map<String, SpeciesRecord>? _speciesById;
  Map<String, SpeciesRecord>? _speciesByCode;
  DateTime? _speciesExpiry;

  Map<String, ProvenanceRecord>? _provenancesById;
  DateTime? _provenanceExpiry;

  /// Returns every species (optionally filtered by organism kind).
  Future<List<SpeciesRecord>> listSpecies({OrganismKind? organismKind}) async {
    await _ensureSpeciesCache();
    final records = _speciesById!.values;
    if (organismKind == null) {
      return records.toList(growable: false);
    }
    return records
        .where((record) => record.organismKind == organismKind)
        .toList(growable: false);
  }

  /// Resolves a species by canonical ID.
  Future<SpeciesRecord?> getSpeciesById(String id) async {
    await _ensureSpeciesCache();
    return _speciesById![id.toLowerCase()];
  }

  /// Resolves a species by any known code/alias (case-insensitive).
  Future<SpeciesRecord?> getSpeciesByCode(String code) async {
    if (code.trim().isEmpty) return null;
    await _ensureSpeciesCache();
    final normalized = code.trim().toLowerCase();
    return _speciesByCode![normalized];
  }

  /// Fetches all provenance records for the requested organism/species.
  Future<List<ProvenanceRecord>> listProvenances({
    OrganismKind? organismKind,
    String? speciesId,
    ProvenanceKind? provenanceKind,
  }) async {
    await _ensureProvenanceCache();
    Iterable<ProvenanceRecord> records = _provenancesById!.values;
    if (organismKind != null) {
      records = records.where((record) => record.organismKind == organismKind);
    }
    if (speciesId != null && speciesId.trim().isNotEmpty) {
      final normalizedSpecies = speciesId.trim().toLowerCase();
      records = records.where(
        (record) => record.speciesId.toLowerCase() == normalizedSpecies,
      );
    }
    if (provenanceKind != null) {
      records = records.where(
        (record) => record.provenanceKind == provenanceKind,
      );
    }
    return records.toList(growable: false);
  }

  /// Returns a provenance record by ID, populating the cache if needed.
  Future<ProvenanceRecord?> getProvenance(String id) async {
    await _ensureProvenanceCache();
    return _provenancesById![id];
  }

  Future<void> _ensureSpeciesCache() async {
    final now = DateTime.now();
    if (_speciesById != null &&
        _speciesExpiry != null &&
        now.isBefore(_speciesExpiry!)) {
      return;
    }

    final snapshot = await _resolver
        .collection(_firestore, speciesCollectionPath)
        .get();
    final byId = <String, SpeciesRecord>{};
    final byCode = <String, SpeciesRecord>{};

    for (final doc in snapshot.docs) {
      if (!(doc.data().containsKey('genus') &&
          doc.data().containsKey('species'))) {
        continue;
      }
      final record = SpeciesRecord.fromJson(doc.data(), id: doc.id);
      final codeKey = record.code.toLowerCase();

      // Deduplicate by code: prefer canonical (shorter) IDs over legacy format
      // e.g., prefer 'acer' over 'species_acropora_cervicornis'
      final existing = byCode[codeKey];
      if (existing != null) {
        // Keep the record with the shorter ID (canonical format)
        if (record.id.length < existing.id.length) {
          // Remove old entry from byId and replace with new canonical record
          byId.remove(existing.id.toLowerCase());
          byId[record.id.toLowerCase()] = record;
          byCode[codeKey] = record;
          for (final alias in record.aliases) {
            byCode[alias.toLowerCase()] = record;
          }
        }
        // Otherwise keep existing (it's already canonical or equal length)
        continue;
      }

      byId[record.id.toLowerCase()] = record;
      byCode[codeKey] = record;
      for (final alias in record.aliases) {
        byCode[alias.toLowerCase()] = record;
      }
    }

    _speciesById = byId;
    _speciesByCode = byCode;
    _speciesExpiry = now.add(_cacheTtl);
  }

  Future<void> _ensureProvenanceCache() async {
    final now = DateTime.now();
    if (_provenancesById != null &&
        _provenanceExpiry != null &&
        now.isBefore(_provenanceExpiry!)) {
      return;
    }

    QuerySnapshot<Map<String, dynamic>> snapshot = await _resolver
        .collection(_firestore, provenanceCollectionPath)
        .get();
    if (snapshot.docs.isEmpty) {
      snapshot = await _resolver
          .collection(_firestore, _legacyLineageCollectionPath)
          .get();
    }
    final byId = <String, ProvenanceRecord>{};

    if (snapshot.docs.isNotEmpty) {
      for (final doc in snapshot.docs) {
        final record = ProvenanceRecord.fromJson(doc.data(), id: doc.id);
        byId[record.id] = record;
      }
    }

    _provenancesById = byId;
    _provenanceExpiry = now.add(_cacheTtl);
  }

  /// Clears all in-memory caches (useful in tests).
  @visibleForTesting
  void clearCache() {
    _speciesById = null;
    _speciesByCode = null;
    _speciesExpiry = null;
    _provenancesById = null;
    _provenanceExpiry = null;
  }

  /// Public hook for invalidating cached taxonomy data.
  void invalidateCache() => clearCache();
}
