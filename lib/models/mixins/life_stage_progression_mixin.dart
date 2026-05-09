import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Captures a transition between two life stages so repositories/UI can render
/// graduation history or enforce timing rules.
class LifeStageTransition extends Equatable {
  const LifeStageTransition({
    required this.fromStage,
    required this.toStage,
    this.occurredAt,
    this.notes,
    this.recordedBy,
    this.sizeSnapshot,
  });

  factory LifeStageTransition.fromJson(Map<String, dynamic> json) {
    final fromStageMap = safeMapCast(json['fromStage']);
    final toStageMap = safeMapCast(json['toStage']);
    final sizeSnapshotMap = safeMapCast(json['sizeSnapshot']);
    return LifeStageTransition(
      fromStage: _parseStage(fromStageMap),
      toStage: _parseStage(toStageMap),
      occurredAt: _parseDate(json['occurredAt']),
      notes: json['notes']?.toString(),
      recordedBy: json['recordedBy']?.toString(),
      sizeSnapshot: sizeSnapshotMap != null
          ? SizeSpec.fromJson(deepNormalizeMap(sizeSnapshotMap))
          : null,
    );
  }

  final LifeStageSpec fromStage;
  final LifeStageSpec toStage;
  final DateTime? occurredAt;
  final String? notes;
  final String? recordedBy;
  final SizeSpec? sizeSnapshot;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fromStage': fromStage.toJson(),
    'toStage': toStage.toJson(),
    if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
    if (notes != null) 'notes': notes,
    if (recordedBy != null) 'recordedBy': recordedBy,
    if (sizeSnapshot != null) 'sizeSnapshot': sizeSnapshot!.toJson(),
  };

  @override
  List<Object?> get props => [
    fromStage,
    toStage,
    occurredAt,
    notes,
    recordedBy,
    sizeSnapshot,
  ];
}

LifeStageSpec _parseStage(Map<String, dynamic>? json) {
  if (json == null || json.isEmpty) {
    return const LifeStageSpec(stage: LifeStage.unknown);
  }
  return LifeStageSpec.fromJson(json);
}

/// Provides reusable logic for life-stage progression rules (ordering checks,
/// minimum intervals, physical form validation).
mixin LifeStageProgressionMixin {
  LifeStageSpec get lifecycleStageSpec;
  OrganismKind get lifecycleOrganismKind;
  List<LifeStageTransition> get lifeStageHistory;

  /// Override when a record stores organism-specific timing requirements.
  Duration? get customMinimumStageInterval => null;

  LifeStage get lifecycleStage => lifecycleStageSpec.stage;

  bool canProgressTo(LifeStage targetStage) =>
      progressionRequirements(targetStage).isEmpty;

  /// Returns the remaining duration before progressing to another stage is
  /// allowed. When null, no timing constraint applies.
  Duration? timeUntilNextStage({DateTime? asOf, Duration? minimumInterval}) {
    final lastTransition = lifeStageHistory.isNotEmpty
        ? lifeStageHistory.last.occurredAt
        : null;
    final interval =
        minimumInterval ?? customMinimumStageInterval ?? _defaultInterval();
    if (lastTransition == null || interval == null) {
      return null;
    }
    final now = asOf ?? DateTime.now().toUtc();
    final elapsed = now.difference(lastTransition);
    if (elapsed >= interval) return Duration.zero;
    return interval - elapsed;
  }

  /// Human-readable requirements (if any) that block a transition.
  List<String> progressionRequirements(LifeStage targetStage) {
    final requirements = <String>[];
    final currentIndex = _stageOrder.indexOf(lifecycleStage);
    final targetIndex = _stageOrder.indexOf(targetStage);
    if (targetIndex == -1) {
      requirements.add('Unknown target life stage: ${targetStage.name}.');
      return requirements;
    }
    // Allow any transition from unknown (specifying the actual stage)
    // But prevent regression from known stages
    if (lifecycleStage != LifeStage.unknown && targetIndex < currentIndex) {
      requirements.add(
        'Cannot regress from ${lifecycleStage.displayName} to '
        '${targetStage.displayName}.',
      );
    }
    final interval = timeUntilNextStage();
    if (interval != null && interval > Duration.zero) {
      final remainingDays = interval.inHours >= 24
          ? '${(interval.inHours / 24).ceil()} days'
          : '${interval.inHours} hours';
      requirements.add('Ready in $remainingDays based on progression cadence.');
    }
    return requirements;
  }

  /// Convenience helper to tack on a new transition record (callers are
  /// responsible for persisting the resulting list).
  List<LifeStageTransition> appendLifeStageTransition(
    LifeStageSpec nextStage, {
    DateTime? occurredAt,
    String? notes,
    String? recordedBy,
    SizeSpec? sizeSnapshot,
  }) {
    return [
      ...lifeStageHistory,
      LifeStageTransition(
        fromStage: lifecycleStageSpec,
        toStage: nextStage,
        occurredAt: occurredAt ?? DateTime.now().toUtc(),
        notes: notes,
        recordedBy: recordedBy,
        sizeSnapshot: sizeSnapshot,
      ),
    ];
  }

  Duration? _defaultInterval() =>
      _defaultStageIntervals[lifecycleStage] ?? const Duration(days: 0);
}

const List<LifeStage> _stageOrder = [
  LifeStage.unknown, // Special: can transition to any known stage
  LifeStage.gamete,
  LifeStage.embryo,
  LifeStage.larva,
  LifeStage.juvenile,
  LifeStage.adult,
  LifeStage.broodstock,
];

const Map<LifeStage, Duration> _defaultStageIntervals = {
  LifeStage.unknown: Duration.zero, // Can immediately transition when stage is specified
  LifeStage.gamete: Duration(hours: 12),
  LifeStage.embryo: Duration(days: 2),
  LifeStage.larva: Duration(days: 7),
  LifeStage.juvenile: Duration(days: 90),
  LifeStage.adult: Duration(days: 365),
  LifeStage.broodstock: Duration.zero,
};

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}
