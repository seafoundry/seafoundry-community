// @tier: community
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/historical/provenance_id.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';

/// Centralized helper for displaying clonal IDs without leaking UUIDs.
class ClonalIdDisplayService {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isUuid(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return _uuidPattern.hasMatch(trimmed);
  }

  static bool isHumanReadable(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == Missing.string) return false;
    return !_uuidPattern.hasMatch(trimmed);
  }

  /// Resolve a display-ready clonal ID from a Genet record.
  static String? resolveForGenet(Genet genet) {
    return _resolve(
      raw: genet.clonalId,
      aliases: genet.aliasEntries,
      fallbacks: <String?>[genet.localId, genet.name, genet.provenanceId],
    );
  }

  /// Resolve a display-ready clonal ID from a ProvenanceRecord.
  static String? resolveForProvenanceRecord(ProvenanceRecord record) {
    // ProvenanceRecord doesn't have clonalId or aliasEntries
    // Check metadata for clonalId, use aliasLabels as fallbacks
    final clonalId = record.metadata['clonalId']?.toString();
    return _resolve(
      raw: clonalId,
      aliases: const <OrganismAlias>[], // ProvenanceRecord uses aliasLabels, not aliasEntries
      fallbacks: <String?>[
        ...record.aliasLabels, // Use aliasLabels as fallbacks
        record.localId,
        record.displayName,
        record.provenanceId,
      ],
    );
  }

  /// Resolve a display-ready clonal ID from historical provenance data.
  static String? resolveForProvenanceId(ProvenanceId record) {
    final raw = record.clonalId?.trim();
    if (isHumanReadable(raw)) return raw;
    if (raw == null || raw.isEmpty || raw == Missing.string) return null;

    return _firstHuman([
      ...record.aliases.values,
      ...record.rawAliases,
    ]);
  }

  /// Choose the best display value for a provenance suggestion.
  static String resolveForSuggestion(ProvenanceSuggestion suggestion) {
    final resolved = _firstHuman([
      suggestion.masterClonalId,
      suggestion.aliasValue,
      ...suggestion.otherAliases,
    ]);
    return resolved ?? suggestion.aliasValue;
  }

  /// Prefer the alias value when it is human-readable, otherwise fall back
  /// to the best available human-friendly alias.
  static String resolveAliasDisplay(ProvenanceSuggestion suggestion) {
    final aliasValue = suggestion.aliasValue;
    if (isHumanReadable(aliasValue)) return aliasValue;
    return resolveForSuggestion(suggestion);
  }

  static String? _resolve({
    required String? raw,
    Iterable<OrganismAlias> aliases = const <OrganismAlias>[],
    Iterable<String?> fallbacks = const <String?>[],
  }) {
    final trimmed = raw?.trim();
    if (isHumanReadable(trimmed)) return trimmed;
    if (trimmed == null || trimmed.isEmpty || trimmed == Missing.string) {
      return null;
    }

    return _firstHuman([
      ..._aliasCandidates(aliases),
      ...fallbacks,
    ]);
  }

  static Iterable<String> _aliasCandidates(Iterable<OrganismAlias> aliases) {
    if (aliases.isEmpty) return const <String>[];

    final seen = <String>{};
    final primaries = aliases.where((alias) => alias.isPrimary);
    final rest = aliases.where((alias) => !alias.isPrimary);

    Iterable<String> build(OrganismAlias alias) sync* {
      final label = alias.label?.trim();
      final value = alias.value.trim();
      if (label != null && label.isNotEmpty) {
        final key = label.toLowerCase();
        if (seen.add(key)) yield label;
      }
      if (value.isNotEmpty) {
        final key = value.toLowerCase();
        if (seen.add(key)) yield value;
      }
    }

    return [
      for (final alias in primaries) ...build(alias),
      for (final alias in rest) ...build(alias),
    ];
  }

  static String? _firstHuman(Iterable<String?> candidates) {
    final seen = <String>{};
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      if (isHumanReadable(trimmed)) return trimmed;
    }
    return null;
  }
}
