// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Target counts for a specific species within a deliverable.
///
/// Contains a point-in-time snapshot of the species name to preserve
/// the historical record of what species was targeted at the time the
/// deliverable was created, even if the species is later renamed or deleted.
class SpeciesTarget extends Equatable {
  final String speciesId;

  /// Point-in-time snapshot of species name when target was created.
  /// Intentionally denormalized for historical audit purposes.
  final String speciesNameSnapshot;
  final int targetCount;
  final int? genetTargetCount;

  const SpeciesTarget({
    required this.speciesId,
    required this.speciesNameSnapshot,
    required this.targetCount,
    this.genetTargetCount,
  });

  factory SpeciesTarget.fromJson(Map<String, dynamic> json) {
    return SpeciesTarget(
      speciesId: json['speciesId'] ?? '',
      // Support both old 'speciesName' and new 'speciesNameSnapshot' keys
      speciesNameSnapshot: json['speciesNameSnapshot'] ?? json['speciesName'] ?? '',
      targetCount: safeInt(json['targetCount']) ?? 0,
      genetTargetCount: safeInt(json['genetTargetCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speciesId': speciesId,
      'speciesNameSnapshot': speciesNameSnapshot,
      'targetCount': targetCount,
      if (genetTargetCount != null) 'genetTargetCount': genetTargetCount,
    };
  }

  SpeciesTarget copyWith({
    String? speciesId,
    String? speciesNameSnapshot,
    int? targetCount,
    int? genetTargetCount,
  }) {
    return SpeciesTarget(
      speciesId: speciesId ?? this.speciesId,
      speciesNameSnapshot: speciesNameSnapshot ?? this.speciesNameSnapshot,
      targetCount: targetCount ?? this.targetCount,
      genetTargetCount: genetTargetCount ?? this.genetTargetCount,
    );
  }

  @override
  List<Object?> get props =>
      [speciesId, speciesNameSnapshot, targetCount, genetTargetCount];
}
