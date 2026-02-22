// @tier: community
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/utils/record_name_derived.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';

class RecordNameSuggester {
  RecordNameSuggester._();

  static const String _adjectivesAssetPath =
      'assets/wordlists/record_name_adjectives.txt';
  static final Random _random = Random();
  static List<String>? _cachedAdjectives;

  static Future<String?> suggestUnique({
    required String organizationId,
    required UniqueNameValidationService validationService,
  }) async {
    final adjectives = await _loadAdjectives();
    if (adjectives.isEmpty) return null;

    final usage = await validationService.getRecordNameUsage(
      organizationId: organizationId,
    );

    return _suggestFromUsage(
      adjectives: adjectives,
      usage: usage,
    );
  }

  /// Suggests a unique recordName derived from the localId base adjective.
  ///
  /// Uses the deterministic adjective derived from [localId] and increments
  /// with a numeric suffix if needed (e.g., "Rare", "Rare1", "Rare2").
  static Future<String?> suggestFromLocalId({
    required String localId,
    required String organizationId,
    required UniqueNameValidationService validationService,
  }) async {
    final derived = RecordNameDerived.fromLocalId(localId);
    if (derived == null || derived.trim().isEmpty) return null;

    final usage = await validationService.getRecordNameUsage(
      organizationId: organizationId,
    );

    return _suggestFromBase(
      base: derived,
      usage: usage,
    );
  }

  static Future<String?> suggestWithUsage({
    required RecordNameUsage usage,
  }) async {
    final adjectives = await _loadAdjectives();
    if (adjectives.isEmpty) return null;
    return _suggestFromUsage(
      adjectives: adjectives,
      usage: usage,
    );
  }

  static String? suggestFallback(String? localId) {
    return RecordNameDerived.fromLocalId(localId);
  }

  /// Suggests a unique recordName for a split organism based on the source.
  ///
  /// Pattern: Extract adjective base from source, find max suffix, return next.
  /// Example: "Crimson" -> "Crimson2", "Crimson3", etc.
  ///
  /// Handles both new format (adjective only: "Crimson", "Crimson2") and
  /// old format (with localId: "crimson-coral-001") for backward compatibility.
  ///
  /// If source has no parseable adjective, falls back to standard suggestion.
  static Future<String?> suggestSplitRecordName({
    required String sourceRecordName,
    required String organizationId,
    required UniqueNameValidationService validationService,
  }) async {
    final normalized = UniqueNameValidationService.normalizeRecordName(
      sourceRecordName,
    );

    // Try new format first: adjective with optional suffix (e.g., "crimson", "crimson2")
    var adjectiveMatch = RegExp(r'^([a-z]+)(\d*)$').firstMatch(normalized);
    String? adjectiveBase;

    if (adjectiveMatch != null) {
      // New format: just adjective with optional suffix
      adjectiveBase = adjectiveMatch.group(1);
    } else {
      // Try old format: adjective-localId (e.g., "crimson-coral-001")
      adjectiveMatch = RegExp(r'^([a-z]+)(\d*)-(.+)$').firstMatch(normalized);
      if (adjectiveMatch != null) {
        adjectiveBase = adjectiveMatch.group(1);
      }
    }

    if (adjectiveBase == null || adjectiveBase.isEmpty) {
      // Source recordName doesn't follow expected pattern
      return null;
    }

    // Get current usage to find max suffix for this adjective (organization-wide)
    final usage = await validationService.getRecordNameUsage(
      organizationId: organizationId,
    );

    final maxSuffix = usage.maxSuffixForAdjective(adjectiveBase);

    // Next suffix: if no existing suffix found (-1), start at 2 (since source is implicitly 1)
    final nextSuffix = maxSuffix < 1 ? 2 : maxSuffix + 1;

    // Validate uniqueness with retry loop
    for (var attempt = 0; attempt < 100; attempt++) {
      final suffix = nextSuffix + attempt;
      final candidate = capitalize(adjectiveBase) + suffix.toString();
      final normalizedCandidate = UniqueNameValidationService.normalizeRecordName(
        candidate,
      );
      if (!usage.activeRecordNames.contains(normalizedCandidate)) {
        return candidate;
      }
    }

    // Exhausted attempts, return best guess
    return capitalize(adjectiveBase) + nextSuffix.toString();
  }

  static Future<List<String>> _loadAdjectives() async {
    if (_cachedAdjectives != null) {
      return _cachedAdjectives!;
    }
    try {
      final raw = await rootBundle.loadString(_adjectivesAssetPath);
      final adjectives = raw
          .split(RegExp(r'\r?\n'))
          .map((entry) => entry.trim().toLowerCase())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
      if (adjectives.isEmpty) {
        _cachedAdjectives = RecordNameDerived.adjectives;
      } else {
        _cachedAdjectives = adjectives;
      }
    } catch (e, stackTrace) {
      LoggingService.instance.debug(
        'Failed to load record name adjectives: $e',
        {'stackTrace': stackTrace.toString()},
      );
      _cachedAdjectives = RecordNameDerived.adjectives;
    }
    return _cachedAdjectives!;
  }

  static String? _suggestFromUsage({
    required List<String> adjectives,
    required RecordNameUsage usage,
  }) {
    final unused = adjectives
        .where((adjective) => !usage.activeAdjectives.contains(adjective))
        .toList(growable: false);
    final pool = unused.isNotEmpty ? unused : adjectives;
    if (pool.isEmpty) return null;

    final base = pool[_random.nextInt(pool.length)];
    final maxSuffix = usage.maxSuffixForAdjective(base);
    var suffix = maxSuffix >= 0 ? maxSuffix + 1 : 0;

    for (var attempt = 0; attempt < 1000; attempt++) {
      final candidate = suffix > 0
          ? capitalize(base) + suffix.toString()
          : capitalize(base);
      final normalizedCandidate = UniqueNameValidationService.normalizeRecordName(
        candidate,
      );
      if (!usage.activeRecordNames.contains(normalizedCandidate)) {
        return candidate;
      }
      suffix += 1;
    }
    return capitalize(base);
  }

  static String _suggestFromBase({
    required String base,
    required RecordNameUsage usage,
  }) {
    final normalizedBase = UniqueNameValidationService.normalizeRecordName(base);
    if (!usage.activeRecordNames.contains(normalizedBase)) {
      return capitalize(normalizedBase);
    }

    final baseAdjective = normalizedBase.replaceAll(RegExp(r'\d+$'), '');
    var suffix = usage.maxSuffixForAdjective(baseAdjective);
    suffix = suffix >= 0 ? suffix + 1 : 1;

    for (var attempt = 0; attempt < 1000; attempt++) {
      final candidate = capitalize(baseAdjective) + suffix.toString();
      final normalizedCandidate = UniqueNameValidationService.normalizeRecordName(
        candidate,
      );
      if (!usage.activeRecordNames.contains(normalizedCandidate)) {
        return candidate;
      }
      suffix += 1;
    }

    return capitalize(baseAdjective) + suffix.toString();
  }
}
