import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/external/gbif_api_service.dart';
import 'package:seafoundry_app/services/external/wikipedia_api_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// A fact about a species from external sources.
class SpeciesFact {
  const SpeciesFact({
    required this.speciesName,
    required this.text,
    required this.source,
    this.imageUrl,
  });

  final String speciesName;
  final String text;
  final SpeciesFactSource source;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'speciesName': speciesName,
        'text': text,
        'source': source.name,
        'imageUrl': imageUrl,
      };

  factory SpeciesFact.fromJson(Map<String, dynamic> json) => SpeciesFact(
        speciesName: json['speciesName'] as String,
        text: json['text'] as String,
        source: SpeciesFactSource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => SpeciesFactSource.unknown,
        ),
        imageUrl: json['imageUrl'] as String?,
      );
}

enum SpeciesFactSource {
  wikipedia,
  gbif,
  unknown,
}

/// Service that orchestrates fetching species information from external APIs.
///
/// Provides caching (24-hour TTL) to reduce API calls and gracefully falls
/// back when APIs are unavailable.
class SpeciesInfoService {
  SpeciesInfoService({
    WikipediaApiService? wikipedia,
    GbifApiService? gbif,
  })  : _wikipedia = wikipedia ?? WikipediaApiService(),
        _gbif = gbif ?? GbifApiService();

  final WikipediaApiService _wikipedia;
  final GbifApiService _gbif;

  // In-memory cache to avoid repeated disk I/O
  final Map<String, _CacheEntry> _memoryCache = {};

  static const _cacheKeyPrefix = 'species_fact_';
  static const _cacheTtl = Duration(hours: 24);

  /// Gets a fact for the given species, using cache when available.
  ///
  /// Tries Wikipedia first for richer content, then falls back to GBIF
  /// for taxonomy information. Returns null if no fact could be found.
  Future<SpeciesFact?> getFactForSpecies(
    String speciesName, {
    String? commonName,
  }) async {
    final cacheKey = _cacheKeyPrefix + speciesName.toLowerCase().replaceAll(' ', '_');

    // 1. Check memory cache
    final memoryCached = _memoryCache[cacheKey];
    if (memoryCached != null && !memoryCached.isExpired) {
      return memoryCached.fact;
    }

    // 2. Check persisted cache
    final persistedFact = await _getCachedFact(cacheKey);
    if (persistedFact != null) {
      _memoryCache[cacheKey] = _CacheEntry(
        fact: persistedFact,
        expiresAt: DateTime.now().add(_cacheTtl),
      );
      return persistedFact;
    }

    // 3. Fetch from external APIs
    final fact = await _fetchFact(speciesName, commonName: commonName);
    if (fact != null) {
      await _cacheFact(cacheKey, fact);
      _memoryCache[cacheKey] = _CacheEntry(
        fact: fact,
        expiresAt: DateTime.now().add(_cacheTtl),
      );
    }

    return fact;
  }

  Future<SpeciesFact?> _fetchFact(String speciesName, {String? commonName}) async {
    // Try Wikipedia first (usually has richer content)
    try {
      final wikiSummary = await _wikipedia.getSummary(
        speciesName,
        commonName: commonName,
      );
      if (wikiSummary != null) {
        return SpeciesFact(
          speciesName: speciesName,
          text: wikiSummary.toFactText(),
          source: SpeciesFactSource.wikipedia,
          imageUrl: wikiSummary.thumbnailUrl,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('SpeciesInfoService: Wikipedia fetch failed: $e');
      }
    }

    // Fall back to GBIF for taxonomy info
    try {
      final gbifInfo = await _gbif.searchSpecies(speciesName);
      if (gbifInfo != null) {
        return SpeciesFact(
          speciesName: speciesName,
          text: gbifInfo.toFactText(),
          source: SpeciesFactSource.gbif,
          imageUrl: null,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('SpeciesInfoService: GBIF fetch failed: $e');
      }
    }

    return null;
  }

  static const _cacheFileName = 'species_facts_cache.json';
  Map<String, dynamic>? _persistedCache;

  Future<Map<String, dynamic>> _loadPersistedCache() async {
    if (_persistedCache != null) return _persistedCache!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        _persistedCache = jsonDecode(content) as Map<String, dynamic>;
      } else {
        _persistedCache = {};
      }
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('SpeciesInfoService: Failed to load cache file: $e');
      }
      _persistedCache = {};
    }
    return _persistedCache!;
  }

  Future<void> _savePersistedCache() async {
    if (_persistedCache == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      await file.writeAsString(jsonEncode(_persistedCache));
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('SpeciesInfoService: Failed to save cache file: $e');
      }
    }
  }

  Future<SpeciesFact?> _getCachedFact(String key) async {
    try {
      final cache = await _loadPersistedCache();
      final entry = cache[key];
      if (entry == null) return null;

      // Check if cache has expired
      final expiryMs = safeInt(entry['expiry']);
      if (expiryMs == null || DateTime.now().millisecondsSinceEpoch > expiryMs) {
        cache.remove(key);
        await _savePersistedCache();
        return null;
      }

      // Get the cached fact data
      final factData = entry['fact'] as Map<String, dynamic>?;
      if (factData == null) return null;

      return SpeciesFact.fromJson(factData);
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('SpeciesInfoService: Cache read error: $e');
      }
      return null;
    }
  }

  Future<void> _cacheFact(String key, SpeciesFact fact) async {
    try {
      final cache = await _loadPersistedCache();

      // Store fact with expiry timestamp
      cache[key] = {
        'expiry': DateTime.now().add(_cacheTtl).millisecondsSinceEpoch,
        'fact': fact.toJson(),
      };

      await _savePersistedCache();
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('SpeciesInfoService: Cache write error: $e');
      }
    }
  }

  /// Clears all cached facts.
  void clearCache() {
    _memoryCache.clear();
  }

  /// Disposes of resources.
  void dispose() {
    _wikipedia.dispose();
    _gbif.dispose();
    _memoryCache.clear();
  }
}

class _CacheEntry {
  _CacheEntry({required this.fact, required this.expiresAt});

  final SpeciesFact? fact;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
