// @tier: community
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Scope describing what a capacity rule evaluates.
enum StructureCapacityScope { childStructures, occupants }

/// Represents a single capacity rule.
///
/// Retained for type compatibility with [StructureCapacityResult.rule].
/// In the community tier the service is always disabled, so no rules are
/// loaded and this class is never instantiated at runtime.
class StructureCapacityRule {
  const StructureCapacityRule({
    required this.containerType,
    required this.scope,
    required this.maxUnits,
    this.targetGroupType,
    this.organismKind,
    this.lifeStage,
    this.physicalFormId,
    this.unitLabel,
    this.warningThreshold,
    this.message,
    this.isOverride = false,
  });

  final GroupType containerType;
  final StructureCapacityScope scope;
  final GroupType? targetGroupType;
  final OrganismKind? organismKind;
  final LifeStage? lifeStage;
  final String? physicalFormId;
  final int maxUnits;
  final double? warningThreshold;
  final String? unitLabel;
  final String? message;
  final bool isOverride;
}

/// Request describing the attempted change against a structure.
class StructureCapacityRequest {
  StructureCapacityRequest._({
    required this.scope,
    required this.containerType,
    required this.organismKind,
    required this.currentUnits,
    required this.deltaUnits,
    this.targetGroupType,
    this.lifeStage,
    this.physicalFormId,
  }) : projectedUnits = currentUnits + deltaUnits;

  factory StructureCapacityRequest.forChildStructures({
    required GroupType containerType,
    required GroupType targetGroupType,
    required OrganismKind organismKind,
    required int currentUnits,
    required int deltaUnits,
  }) => StructureCapacityRequest._(
    scope: StructureCapacityScope.childStructures,
    containerType: containerType,
    organismKind: organismKind,
    currentUnits: currentUnits,
    deltaUnits: deltaUnits,
    targetGroupType: targetGroupType,
  );

  factory StructureCapacityRequest.forOccupants({
    required GroupType containerType,
    required OrganismKind organismKind,
    required int currentUnits,
    required int deltaUnits,
    LifeStage? lifeStage,
    String? physicalFormId,
  }) => StructureCapacityRequest._(
    scope: StructureCapacityScope.occupants,
    containerType: containerType,
    organismKind: organismKind,
    currentUnits: currentUnits,
    deltaUnits: deltaUnits,
    lifeStage: lifeStage,
    physicalFormId: physicalFormId,
  );

  final StructureCapacityScope scope;
  final GroupType containerType;
  final GroupType? targetGroupType;
  final OrganismKind organismKind;
  final LifeStage? lifeStage;
  final String? physicalFormId;
  final int currentUnits;
  final int deltaUnits;
  final int projectedUnits;
}

/// Result of evaluating a capacity request.
class StructureCapacityResult {
  StructureCapacityResult._({
    required this.request,
    required this.rule,
    required this.projectedUnits,
    required this.isOverCapacity,
    required this.isWarning,
    required this.remainingCapacity,
    required this.warnings,
  });

  factory StructureCapacityResult.unbounded(StructureCapacityRequest request) =>
      StructureCapacityResult._(
        request: request,
        rule: null,
        projectedUnits: request.projectedUnits,
        isOverCapacity: false,
        isWarning: false,
        remainingCapacity: null,
        warnings: const [],
      );

  final StructureCapacityRequest request;
  final StructureCapacityRule? rule;
  final int projectedUnits;
  final bool isOverCapacity;
  final bool isWarning;
  final int? remainingCapacity;
  final List<String> warnings;

  bool get hasRule => rule != null;

  String get blockingMessage {
    if (rule?.message != null) {
      return rule!.message!;
    }
    final unitLabel = rule?.unitLabel ?? 'units';
    if (request.scope == StructureCapacityScope.childStructures) {
      final childName = request.targetGroupType?.name ?? unitLabel;
      return '${request.containerType.name} structures can host up to '
          '${rule?.maxUnits ?? 0} $childName. Please move or archive existing '
          'records before adding more.';
    }
    return '${request.containerType.name} structures are limited to '
        '${rule?.maxUnits ?? 0} $unitLabel for '
        '${request.organismKind.metadata.displayName} workflows.';
  }
}

/// Evaluates structure capacity checks.
///
/// In the community tier this service is always constructed via [disabled()]
/// and [isEnabled] always returns false. Every call to [evaluate()] returns
/// an unbounded (no-op) result.
class StructureCapacityService {
  StructureCapacityService.disabled()
    : _defaultsLoaded = true,
      _rulesByContainer = const {};

  bool _defaultsLoaded = false;
  final Map<GroupType, List<StructureCapacityRule>> _rulesByContainer;

  bool get isEnabled => _rulesByContainer.isNotEmpty;

  Future<void> ensureInitialized() async {
    if (_defaultsLoaded) return;
    _defaultsLoaded = true;
  }

  StructureCapacityResult evaluate(StructureCapacityRequest request) {
    if (!isEnabled) {
      return StructureCapacityResult.unbounded(request);
    }
    return StructureCapacityResult.unbounded(request);
  }
}
