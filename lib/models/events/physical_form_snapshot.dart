import 'package:equatable/equatable.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/inventory/physical_form_config.dart';
import 'package:seafoundry_community/models/inventory/size_spec.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/life_stage.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

/// Minimal audit snapshot persisted on a [PhysicalFormChangeEvent].
///
/// Audit field set: tagId, physicalForm, lifeStage, sizeSpec.
/// Captures the prior physical-form state plus the contextual life stage
/// and size spec at the time of the form change. Old/new formId are
/// already on the event itself; the parent OrganismRecord owns the rest
/// of the organism state.
class PhysicalFormSnapshot extends Equatable {
  const PhysicalFormSnapshot({
    required this.tagId,
    required this.lifeStage,
    this.physicalForm,
    this.sizeSpec,
  });

  final String tagId;
  final LifeStageSpec lifeStage;
  final PhysicalFormInstance? physicalForm;
  final SizeSpec? sizeSpec;

  factory PhysicalFormSnapshot.fromOrganismRecord(OrganismRecord record) {
    return PhysicalFormSnapshot(
      tagId: record.tagId,
      lifeStage: record.lifeStage,
      physicalForm: record.physicalForm,
      sizeSpec: record.sizeSpec,
    );
  }

  factory PhysicalFormSnapshot.fromJson(Map<String, dynamic> json) {
    final lifeStageJson = safeMapCast(json['lifeStage']);
    final physicalFormJson = safeMapCast(json['physicalForm']);
    final sizeSpecJson = safeMapCast(json['sizeSpec']);
    return PhysicalFormSnapshot(
      tagId: json['tagId']?.toString() ?? Missing.string,
      lifeStage: lifeStageJson != null && lifeStageJson.isNotEmpty
          ? LifeStageSpec.fromJson(lifeStageJson)
          : const LifeStageSpec(stage: LifeStage.unknown),
      physicalForm: physicalFormJson != null && physicalFormJson.isNotEmpty
          ? PhysicalFormInstance.fromJson(physicalFormJson)
          : null,
      sizeSpec: sizeSpecJson != null && sizeSpecJson.isNotEmpty
          ? SizeSpec.fromJson(sizeSpecJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tagId': tagId,
    'lifeStage': lifeStage.toJson(),
    if (physicalForm != null) 'physicalForm': physicalForm!.toJson(),
    if (sizeSpec != null && !sizeSpec!.isEmpty) 'sizeSpec': sizeSpec!.toJson(),
  };

  @override
  List<Object?> get props => [tagId, lifeStage, physicalForm, sizeSpec];
}
