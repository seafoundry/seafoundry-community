import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';

/// Which field a provenance match originated from.
enum ProvenanceMatchField { clonalId, accessionNumber, alias, provenanceId }

/// Private sentinel class for distinguishing "not provided" from "explicitly null"
/// in copyWith. Using a dedicated class prevents accidental collision with
/// const Object() singletons in other files.
class _Sentinel {
  const _Sentinel();
}

/// Shared state for provenance alias search, used by both genet creation
/// and organism creation flows. Tracks independent matches from clonalId
/// and accessionNumber fields with conflict detection.
class ProvenanceSearchState extends Equatable {
  const ProvenanceSearchState({
    this.clonalIdMatch,
    this.accessionMatch,
    this.aliasMatch,
    this.provenanceIdMatch,
    this.clonalIdSuggestions = const [],
    this.accessionSuggestions = const [],
    this.aliasSuggestions = const [],
    this.provenanceIdSuggestions = const [],
    this.isSearchingClonalId = false,
    this.isSearchingAccession = false,
    this.isSearchingAlias = false,
    this.isSearchingProvenanceId = false,
    this.activeField,
  });

  final ProvenanceSuggestion? clonalIdMatch;
  final ProvenanceSuggestion? accessionMatch;
  final ProvenanceSuggestion? aliasMatch;
  final ProvenanceSuggestion? provenanceIdMatch;
  final List<ProvenanceSuggestion> clonalIdSuggestions;
  final List<ProvenanceSuggestion> accessionSuggestions;
  final List<ProvenanceSuggestion> aliasSuggestions;
  final List<ProvenanceSuggestion> provenanceIdSuggestions;
  final bool isSearchingClonalId;
  final bool isSearchingAccession;
  final bool isSearchingAlias;
  final bool isSearchingProvenanceId;
  final ProvenanceMatchField? activeField;

  /// True when both fields matched different PIDs -- blocks submit.
  bool get hasConflict {
    final matches = _matches;
    if (matches.length <= 1) return false;
    final firstPid = matches.first.provenanceId;
    return matches.any((m) => m.provenanceId != firstPid);
  }

  /// The resolved PID (null if conflict or no matches).
  String? get resolvedProvenanceId {
    if (hasConflict) return null;
    final activeMatch = _matchFor(activeField);
    return activeMatch?.provenanceId ??
        clonalIdMatch?.provenanceId ??
        accessionMatch?.provenanceId ??
        aliasMatch?.provenanceId ??
        provenanceIdMatch?.provenanceId;
  }

  ProvenanceSuggestion? get resolvedMatch {
    if (hasConflict) return null;
    return _matchFor(activeField) ??
        clonalIdMatch ??
        accessionMatch ??
        aliasMatch ??
        provenanceIdMatch;
  }

  /// Human-readable conflict message for UI display.
  String? get conflictMessage {
    if (!hasConflict) return null;
    return 'Multiple provenance selections are active. '
        'Clear all but one to resolve.';
  }

  static const _Sentinel _sentinel = _Sentinel();

  ProvenanceSearchState copyWith({
    Object? clonalIdMatch = _sentinel,
    Object? accessionMatch = _sentinel,
    Object? aliasMatch = _sentinel,
    Object? provenanceIdMatch = _sentinel,
    List<ProvenanceSuggestion>? clonalIdSuggestions,
    List<ProvenanceSuggestion>? accessionSuggestions,
    List<ProvenanceSuggestion>? aliasSuggestions,
    List<ProvenanceSuggestion>? provenanceIdSuggestions,
    bool? isSearchingClonalId,
    bool? isSearchingAccession,
    bool? isSearchingAlias,
    bool? isSearchingProvenanceId,
    Object? activeField = _sentinel,
  }) {
    return ProvenanceSearchState(
      clonalIdMatch: clonalIdMatch == _sentinel
          ? this.clonalIdMatch
          : clonalIdMatch as ProvenanceSuggestion?,
      accessionMatch: accessionMatch == _sentinel
          ? this.accessionMatch
          : accessionMatch as ProvenanceSuggestion?,
      aliasMatch: aliasMatch == _sentinel
          ? this.aliasMatch
          : aliasMatch as ProvenanceSuggestion?,
      provenanceIdMatch: provenanceIdMatch == _sentinel
          ? this.provenanceIdMatch
          : provenanceIdMatch as ProvenanceSuggestion?,
      clonalIdSuggestions: clonalIdSuggestions ?? this.clonalIdSuggestions,
      accessionSuggestions: accessionSuggestions ?? this.accessionSuggestions,
      aliasSuggestions: aliasSuggestions ?? this.aliasSuggestions,
      provenanceIdSuggestions:
          provenanceIdSuggestions ?? this.provenanceIdSuggestions,
      isSearchingClonalId: isSearchingClonalId ?? this.isSearchingClonalId,
      isSearchingAccession: isSearchingAccession ?? this.isSearchingAccession,
      isSearchingAlias: isSearchingAlias ?? this.isSearchingAlias,
      isSearchingProvenanceId:
          isSearchingProvenanceId ?? this.isSearchingProvenanceId,
      activeField: activeField == _sentinel
          ? this.activeField
          : activeField as ProvenanceMatchField?,
    );
  }

  @override
  List<Object?> get props => [
    clonalIdMatch,
    accessionMatch,
    aliasMatch,
    provenanceIdMatch,
    clonalIdSuggestions,
    accessionSuggestions,
    aliasSuggestions,
    provenanceIdSuggestions,
    isSearchingClonalId,
    isSearchingAccession,
    isSearchingAlias,
    isSearchingProvenanceId,
    activeField,
  ];

  List<ProvenanceSuggestion> get _matches => [
    clonalIdMatch,
    accessionMatch,
    aliasMatch,
    provenanceIdMatch,
  ].whereType<ProvenanceSuggestion>().toList();

  ProvenanceSuggestion? _matchFor(ProvenanceMatchField? field) {
    return switch (field) {
      ProvenanceMatchField.clonalId => clonalIdMatch,
      ProvenanceMatchField.accessionNumber => accessionMatch,
      ProvenanceMatchField.alias => aliasMatch,
      ProvenanceMatchField.provenanceId => provenanceIdMatch,
      null => null,
    };
  }
}
