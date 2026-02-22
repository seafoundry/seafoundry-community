// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';

/// Form model for a single structure capacity rule.
///
/// Holds the editable state of a rule during admin configuration.
/// Serializable to/from Firestore maps via [toMap] and [fromMap].
@immutable
class StructureCapacityRuleForm extends Equatable {
  StructureCapacityRuleForm({
    String? id,
    required this.containerType,
    required this.scope,
    required this.organismKind,
    required this.maxUnits,
    this.targetGroupType,
    this.lifeStage,
    this.physicalFormId,
    this.unitLabel,
    this.warningThreshold,
    this.message,
  }) : id = id ?? UniqueKey().toString();

  final String id;
  final GroupType containerType;
  final StructureCapacityScope scope;
  final OrganismKind organismKind;
  final GroupType? targetGroupType;
  final LifeStage? lifeStage;

  /// Physical form identifier (replaces deprecated Morphology enum).
  /// Examples: 'fragment', 'spat_bag', 'seeded_line_segment'
  final String? physicalFormId;
  final int maxUnits;
  final double? warningThreshold;
  final String? unitLabel;
  final String? message;

  StructureCapacityRuleForm copyWith({
    String? id,
    GroupType? containerType,
    StructureCapacityScope? scope,
    OrganismKind? organismKind,
    GroupType? targetGroupType,
    LifeStage? lifeStage,
    String? physicalFormId,
    int? maxUnits,
    double? warningThreshold,
    String? unitLabel,
    String? message,
  }) {
    return StructureCapacityRuleForm(
      id: id ?? this.id,
      containerType: containerType ?? this.containerType,
      scope: scope ?? this.scope,
      organismKind: organismKind ?? this.organismKind,
      targetGroupType: targetGroupType ?? this.targetGroupType,
      lifeStage: lifeStage ?? this.lifeStage,
      physicalFormId: physicalFormId ?? this.physicalFormId,
      maxUnits: maxUnits ?? this.maxUnits,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      unitLabel: unitLabel ?? this.unitLabel,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'containerType': containerType.id,
      'scope': scope.name,
      'organism': organismKind.name,
      if (targetGroupType != null) 'targetGroupType': targetGroupType!.id,
      if (lifeStage != null) 'lifeStage': lifeStage!.name,
      if (physicalFormId != null) 'physicalFormId': physicalFormId,
      'maxUnits': maxUnits,
      if (warningThreshold != null) 'warningThreshold': warningThreshold,
      if (unitLabel != null && unitLabel!.trim().isNotEmpty)
        'unitLabel': unitLabel,
      if (message != null && message!.trim().isNotEmpty) 'message': message,
    };
  }

  static StructureCapacityRuleForm? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final container = GroupType.builtins[map['containerType']?.toString()];
    final scopeName = map['scope']?.toString();
    final scope = StructureCapacityScope.values.firstWhere(
      (value) => value.name == scopeName,
      orElse: () => StructureCapacityScope.childStructures,
    );
    final organism =
        OrganismKindX.tryParse(map['organism']?.toString()) ??
        OrganismKind.coral;
    final targetId = map['targetGroupType']?.toString();
    final target = targetId != null ? GroupType.builtins[targetId] : null;
    final lifeStage = LifeStageX.tryParse(map['lifeStage']?.toString());
    final physicalFormId = map['physicalFormId']?.toString();
    final maxUnits = safeInt(map['maxUnits']);
    if (container == null || maxUnits == null) {
      return null;
    }
    final warningThreshold =
        safeDouble(map['warningThreshold']) ??
        double.tryParse(map['warningThreshold']?.toString() ?? '');
    final message = map['message']?.toString();
    final unitLabel = map['unitLabel']?.toString();
    return StructureCapacityRuleForm(
      id: map['id']?.toString(),
      containerType: container,
      scope: scope,
      organismKind: organism,
      targetGroupType: target,
      lifeStage: lifeStage,
      physicalFormId: physicalFormId,
      maxUnits: maxUnits,
      warningThreshold: warningThreshold,
      unitLabel: unitLabel?.isNotEmpty == true ? unitLabel : null,
      message: message?.isNotEmpty == true ? message : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        containerType.id,
        scope,
        organismKind,
        targetGroupType?.id,
        lifeStage,
        physicalFormId,
        maxUnits,
        warningThreshold,
        unitLabel,
        message,
      ];
}
