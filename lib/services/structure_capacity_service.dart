// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:yaml/yaml.dart';

/// Scope describing what a capacity rule evaluates.
enum StructureCapacityScope { childStructures, occupants }

/// Represents a single capacity rule loaded from defaults or overrides.
///
/// Note: Uses `physicalFormId` (String) instead of the deprecated `Morphology` enum
/// to comply with 5-axis record standards.
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
  /// Physical form identifier (replaces deprecated Morphology enum).
  /// Examples: 'fragment', 'spat_bag', 'seeded_line_segment'
  final String? physicalFormId;
  final int maxUnits;
  final double? warningThreshold;
  final String? unitLabel;
  final String? message;
  final bool isOverride;

  StructureCapacityRule copyWith({bool? isOverride}) {
    return StructureCapacityRule(
      containerType: containerType,
      scope: scope,
      targetGroupType: targetGroupType,
      organismKind: organismKind,
      lifeStage: lifeStage,
      physicalFormId: physicalFormId,
      unitLabel: unitLabel,
      maxUnits: maxUnits,
      warningThreshold: warningThreshold,
      message: message,
      isOverride: isOverride ?? this.isOverride,
    );
  }
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
  /// Physical form identifier (replaces deprecated Morphology enum).
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

  factory StructureCapacityResult.fromRule({
    required StructureCapacityRequest request,
    required StructureCapacityRule rule,
  }) {
    final projected = request.projectedUnits;
    final overCapacity = projected > rule.maxUnits;
    final threshold = rule.warningThreshold ?? 0;
    final warningBoundary = threshold > 0
        ? (rule.maxUnits * threshold).ceil()
        : null;
    final isWarning =
        !overCapacity &&
        warningBoundary != null &&
        projected >= warningBoundary;
    final remaining = rule.maxUnits - projected;
    final warnings = <String>[];
    if (isWarning) {
      warnings.add(
        'Approaching ${rule.unitLabel ?? 'capacity'}: '
        '$projected / ${rule.maxUnits}',
      );
    }
    return StructureCapacityResult._(
      request: request,
      rule: rule,
      projectedUnits: projected,
      isOverCapacity: overCapacity,
      isWarning: isWarning,
      remainingCapacity: remaining >= 0 ? remaining : 0,
      warnings: UnmodifiableListView(warnings),
    );
  }

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

/// Loads capacity rules from YAML/JSON and evaluates capacity checks.
class StructureCapacityService {
  StructureCapacityService({
    Future<String> Function()? defaultConfigLoader,
    FirebaseFirestore? firestore,
  }) : _defaultConfigLoader = defaultConfigLoader,
       _firestore = firestore;

  StructureCapacityService.withRules(List<StructureCapacityRule> rules)
    : _defaultConfigLoader = null,
      _firestore = null,
      _defaultsLoaded = true,
      _defaultRules = List<StructureCapacityRule>.unmodifiable(rules),
      _overrideRules = const [],
      _rulesByContainer = _createLookup(rules, const []);

  StructureCapacityService.disabled()
    : _defaultConfigLoader = null,
      _firestore = null,
      _defaultsLoaded = true,
      _rulesByContainer = const {};

  final Future<String> Function()? _defaultConfigLoader;
  final FirebaseFirestore? _firestore;

  bool _defaultsLoaded = false;
  List<StructureCapacityRule> _defaultRules = const [];
  List<StructureCapacityRule> _overrideRules = const [];
  Map<GroupType, List<StructureCapacityRule>> _rulesByContainer =
      const <GroupType, List<StructureCapacityRule>>{};

  bool get isEnabled => _defaultRules.isNotEmpty || _overrideRules.isNotEmpty;

  Future<void> ensureInitialized() async {
    if (_defaultsLoaded) return;
    if (_defaultConfigLoader == null) {
      _defaultsLoaded = true;
      return;
    }
    try {
      final yaml = await _defaultConfigLoader.call();
      _defaultRules = StructureCapacityRuleParser.parseYaml(
        yaml,
        isOverride: false,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load default structure capacity rules: $error',
        stackTrace,
      );
      _defaultRules = const [];
    } finally {
      _defaultsLoaded = true;
      _rebuildLookup();
    }
  }

  Future<void> refreshOverrides({required String organizationId}) async {
    if (_firestore == null) return;
    final snapshot = await FirestoreCollectionResolver.instance
        .subcollection(_firestore, 'organizations', organizationId, 'config')
        .doc('structure_capacity')
        .get();

    if (!snapshot.exists) {
      _overrideRules = const [];
      _rebuildLookup();
      return;
    }
    final data = snapshot.data();
    List<StructureCapacityRule> overrides = const [];
    try {
      if (data?['yaml'] is String) {
        overrides = StructureCapacityRuleParser.parseYaml(
          data!['yaml'] as String,
          isOverride: true,
        );
      } else if (data?['rules'] is List) {
        final rawList = (data!['rules'] as List)
            .map<Map<String, dynamic>>((entry) {
              if (entry is Map<String, dynamic>) {
                return entry;
              }
              if (entry is Map) {
                return entry.map(
                  (key, value) => MapEntry(key.toString(), value),
                );
              }
              throw const FormatException(
                'Rule entries must be objects (maps).',
              );
            })
            .toList(growable: false);
        overrides = StructureCapacityRuleParser.parseRuleList(
          rawList,
          isOverride: true,
        );
      } else {
        overrides = const [];
      }
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Failed to parse structure capacity overrides for $organizationId: '
        '$error',
        stackTrace,
      );
      return;
    }
    _overrideRules = overrides;
    _rebuildLookup();
  }

  StructureCapacityResult evaluate(StructureCapacityRequest request) {
    if (!isEnabled) {
      return StructureCapacityResult.unbounded(request);
    }
    final rules = _rulesByContainer[request.containerType];
    if (rules == null || rules.isEmpty) {
      return StructureCapacityResult.unbounded(request);
    }
    final rule = _selectRule(rules, request);
    if (rule == null) {
      return StructureCapacityResult.unbounded(request);
    }
    return StructureCapacityResult.fromRule(request: request, rule: rule);
  }

  void _rebuildLookup() {
    _rulesByContainer = _createLookup(_defaultRules, _overrideRules);
  }

  static Map<GroupType, List<StructureCapacityRule>> _createLookup(
    Iterable<StructureCapacityRule> defaults,
    Iterable<StructureCapacityRule> overrides,
  ) {
    final map = <GroupType, List<StructureCapacityRule>>{};
    void addRule(StructureCapacityRule rule) {
      map.putIfAbsent(rule.containerType, () => <StructureCapacityRule>[]);
      map[rule.containerType]!.add(rule);
    }

    for (final rule in defaults) {
      addRule(rule);
    }
    for (final rule in overrides) {
      addRule(rule.copyWith(isOverride: true));
    }

    return UnmodifiableMapView({
      for (final entry in map.entries)
        entry.key: List<StructureCapacityRule>.unmodifiable(entry.value),
    });
  }

  StructureCapacityRule? _selectRule(
    List<StructureCapacityRule> candidates,
    StructureCapacityRequest request,
  ) {
    StructureCapacityRule? selected;
    var highestScore = -1;
    for (final rule in candidates.where((r) => r.scope == request.scope)) {
      var score = 0;
      if (rule.targetGroupType != null) {
        if (rule.targetGroupType == request.targetGroupType) {
          score += 8;
        } else {
          continue;
        }
      }
      if (rule.organismKind != null) {
        if (rule.organismKind == request.organismKind) {
          score += 4;
        } else {
          continue;
        }
      }
      if (rule.lifeStage != null) {
        if (rule.lifeStage == request.lifeStage) {
          score += 2;
        } else {
          continue;
        }
      }
      if (rule.physicalFormId != null) {
        if (rule.physicalFormId == request.physicalFormId) {
          score += 1;
        } else {
          continue;
        }
      }
      if (rule.isOverride) {
        score += 32;
      }
      if (score > highestScore) {
        highestScore = score;
        selected = rule;
      }
    }
    return selected;
  }
}

/// Helper class to parse YAML/JSON payloads into capacity rules.
class StructureCapacityRuleParser {
  static List<StructureCapacityRule> parseYaml(
    String yamlSource, {
    required bool isOverride,
  }) {
    final document = loadYaml(yamlSource);
    if (document is! YamlMap) return const [];
    final rules = <StructureCapacityRule>[];
    document.nodes.forEach((keyNode, valueNode) {
      final groupTypeId = keyNode.value?.toString();
      final container = GroupType.builtins[groupTypeId];
      if (container == null) {
        return;
      }
      final value = valueNode.value;
      if (value is! Map || value['metrics'] is! List) {
        return;
      }
      for (final entry in value['metrics'] as List) {
        if (entry is Map) {
          final rule = _ruleFromMap(
            entry.map((k, v) => MapEntry(k.toString(), v)),
            container,
            isOverride,
          );
          if (rule != null) {
            rules.add(rule);
          }
        }
      }
    });
    return rules;
  }

  static List<StructureCapacityRule> parseRuleList(
    List<Map<String, dynamic>> data, {
    required bool isOverride,
  }) {
    final rules = <StructureCapacityRule>[];
    for (final entry in data) {
      final containerId = entry['containerType']?.toString();
      final container = GroupType.builtins[containerId];
      if (container == null) continue;
      final rule = _ruleFromMap(entry, container, isOverride);
      if (rule != null) rules.add(rule);
    }
    return rules;
  }

  static StructureCapacityRule? _ruleFromMap(
    Map<String, dynamic> map,
    GroupType container,
    bool isOverride,
  ) {
    final scopeRaw = map['scope']?.toString();
    final scope = StructureCapacityScope.values.firstWhereOrNull(
      (value) => value.name.toLowerCase() == scopeRaw?.toLowerCase(),
    );
    if (scope == null) return null;

    final maxUnitsRaw = map['maxUnits'];
    if (maxUnitsRaw == null) return null;
    final maxUnits = maxUnitsRaw is num
        ? maxUnitsRaw.toInt()
        : int.tryParse(maxUnitsRaw.toString());
    if (maxUnits == null || maxUnits <= 0) return null;

    final organism = OrganismKindX.tryParse(map['organism']?.toString());
    final lifeStage = LifeStageX.tryParse(map['lifeStage']?.toString());
    final physicalFormId = map['physicalFormId']?.toString();
    final targetId = map['targetGroupType']?.toString();
    final target = targetId != null ? GroupType.builtins[targetId] : null;
    final warning = safeDouble(map['warningThreshold']) ??
        double.tryParse(map['warningThreshold']?.toString() ?? '');

    return StructureCapacityRule(
      containerType: container,
      scope: scope,
      targetGroupType: target,
      organismKind: organism,
      lifeStage: lifeStage,
      physicalFormId: physicalFormId,
      unitLabel: map['unitLabel']?.toString(),
      message: map['message']?.toString(),
      maxUnits: maxUnits,
      warningThreshold: warning,
      isOverride: isOverride,
    );
  }
}
