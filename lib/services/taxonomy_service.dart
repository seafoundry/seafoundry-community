// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/models/taxonomy/species_record.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Provides cached access to the canonical species collection stored
/// in Firestore so repositories, CSV adapters, and dialogs can resolve taxonomy
/// metadata without hard-coding coral-only enums.
class TaxonomyService {
  TaxonomyService({
    required FirebaseFirestore firestore,
    Duration cacheTtl = const Duration(minutes: 30),
  }) : _firestore = firestore,
       _cacheTtl = cacheTtl;

  static const String speciesCollectionPath = 'taxonomy_species';

  final FirebaseFirestore _firestore;
  final Duration _cacheTtl;

  Map<String, SpeciesRecord>? _speciesById;
  DateTime? _speciesExpiry;

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

  Future<void> _ensureSpeciesCache() async {
    final now = DateTime.now();
    if (_speciesById != null &&
        _speciesExpiry != null &&
        now.isBefore(_speciesExpiry!)) {
      return;
    }

    final snapshot = await _firestore
        .collection( speciesCollectionPath)
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
    _speciesExpiry = now.add(_cacheTtl);
  }

  /// Clears all in-memory caches (useful in tests).
  @visibleForTesting
  void clearCache() {
    _speciesById = null;
    _speciesExpiry = null;
  }
}
