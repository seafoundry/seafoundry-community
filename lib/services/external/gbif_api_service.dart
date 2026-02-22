// @tier: community
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:seafoundry_app/services/logging_service.dart';

/// Data class representing species taxonomy information from GBIF.
class GbifSpeciesInfo {
  const GbifSpeciesInfo({
    required this.key,
    required this.scientificName,
    this.canonicalName,
    this.vernacularName,
    this.kingdom,
    this.phylum,
    this.classRank,
    this.order,
    this.family,
    this.genus,
    this.species,
    this.status,
    this.rank,
  });

  final int key;
  final String scientificName;
  final String? canonicalName;
  final String? vernacularName;
  final String? kingdom;
  final String? phylum;
  final String? classRank;
  final String? order;
  final String? family;
  final String? genus;
  final String? species;
  final String? status;
  final String? rank;

  /// Creates a fact-style text from the taxonomy information.
  String toFactText() {
    final parts = <String>[];

    final name = canonicalName ?? scientificName;

    if (family != null && genus != null) {
      parts.add('$name belongs to the family $family in the genus $genus.');
    } else if (family != null) {
      parts.add('$name belongs to the family $family.');
    } else if (order != null) {
      parts.add('$name belongs to the order $order.');
    }

    if (kingdom != null && phylum != null && parts.isEmpty) {
      parts.add('$name is a member of the $kingdom kingdom, phylum $phylum.');
    }

    if (parts.isEmpty) {
      return 'Scientific name: $scientificName';
    }

    return parts.join(' ');
  }
}

/// Service for fetching species taxonomy information from GBIF API.
///
/// GBIF (Global Biodiversity Information Facility) provides a comprehensive
/// taxonomy database for species identification and classification.
/// https://api.gbif.org/v1/
class GbifApiService {
  GbifApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://api.gbif.org/v1/species';
  static const _timeout = Duration(seconds: 10);

  /// Searches for a species by name and returns the best match.
  ///
  /// Returns null if no match is found or an error occurs.
  Future<GbifSpeciesInfo?> searchSpecies(String name) async {
    try {
      final encodedName = Uri.encodeComponent(name);
      final uri = Uri.parse('$_baseUrl/search?q=$encodedName&limit=5');

      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseBestMatch(data, name);
      }

      if (kDebugMode) {
        LoggingService.instance.warning('GbifApiService: HTTP ${response.statusCode} for "$name"');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('GbifApiService: Error searching "$name": $e');
      }
      return null;
    }
  }

  /// Gets detailed species information by GBIF species key.
  Future<GbifSpeciesInfo?> getSpeciesInfo(int key) async {
    try {
      final uri = Uri.parse('$_baseUrl/$key');

      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseSpeciesInfo(data);
      }

      if (kDebugMode) {
        LoggingService.instance.warning('GbifApiService: HTTP ${response.statusCode} for key $key');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('GbifApiService: Error getting species $key: $e');
      }
      return null;
    }
  }

  GbifSpeciesInfo? _parseBestMatch(Map<String, dynamic> data, String searchName) {
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    // Find the best match - prefer ACCEPTED status and exact name matches
    final searchLower = searchName.toLowerCase();

    Map<String, dynamic>? bestMatch;
    int bestScore = -1;

    for (final result in results) {
      if (result is! Map<String, dynamic>) continue;

      int score = 0;
      final status = (result['status'] as String?)?.toUpperCase();
      final canonical = result['canonicalName'] as String?;
      final scientific = result['scientificName'] as String?;

      // Prefer ACCEPTED status
      if (status == 'ACCEPTED') score += 10;

      // Prefer exact matches
      if (canonical?.toLowerCase() == searchLower) score += 5;
      if (scientific?.toLowerCase() == searchLower) score += 3;

      // Prefer SPECIES rank
      final rank = (result['rank'] as String?)?.toUpperCase();
      if (rank == 'SPECIES') score += 2;

      if (score > bestScore) {
        bestScore = score;
        bestMatch = result;
      }
    }

    if (bestMatch != null) {
      return _parseSpeciesInfo(bestMatch);
    }

    // Fall back to first result
    return _parseSpeciesInfo(results.first as Map<String, dynamic>);
  }

  GbifSpeciesInfo? _parseSpeciesInfo(Map<String, dynamic> data) {
    final key = data['key'] as int?;
    final scientificName = data['scientificName'] as String?;

    if (key == null || scientificName == null) return null;

    return GbifSpeciesInfo(
      key: key,
      scientificName: scientificName,
      canonicalName: data['canonicalName'] as String?,
      vernacularName: data['vernacularName'] as String?,
      kingdom: data['kingdom'] as String?,
      phylum: data['phylum'] as String?,
      classRank: data['class'] as String?,
      order: data['order'] as String?,
      family: data['family'] as String?,
      genus: data['genus'] as String?,
      species: data['species'] as String?,
      status: data['status'] as String?,
      rank: data['rank'] as String?,
    );
  }

  /// Disposes of the HTTP client resources.
  void dispose() {
    _client.close();
  }
}
