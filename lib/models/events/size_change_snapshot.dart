import 'package:equatable/equatable.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/inventory/physical_form_config.dart';
import 'package:seafoundry_community/models/inventory/size_spec.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/life_stage.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

/// Minimal audit snapshot persisted on a [SizeChangeEvent].
///
/// Audit field set: tagId, sizeSpec, physicalForm, lifeStage.
/// Captures the prior size-spec plus its physical-form context (size
/// bands and dimension/density modes are interpreted relative to the
/// physical form) and life stage. Old/new SizeSpec are already on the
/// event itself.
class SizeChangeSnapshot extends Equatable {
  const SizeChangeSnapshot({
    required this.tagId,
    required this.lifeStage,
    this.sizeSpec,
    this.physicalForm,
  });

  final String tagId;
  final LifeStageSpec lifeStage;
  final SizeSpec? sizeSpec;
  final PhysicalFormInstance? physicalForm;

  factory SizeChangeSnapshot.fromOrganismRecord(OrganismRecord record) {
    return SizeChangeSnapshot(
      tagId: record.tagId,
      lifeStage: record.lifeStage,
      sizeSpec: record.sizeSpec,
      physicalForm: record.physicalForm,
    );
  }

  factory SizeChangeSnapshot.fromJson(Map<String, dynamic> json) {
    final lifeStageJson = safeMapCast(json['lifeStage']);
    final sizeSpecJson = safeMapCast(json['sizeSpec']);
    final physicalFormJson = safeMapCast(json['physicalForm']);
    return SizeChangeSnapshot(
      tagId: json['tagId']?.toString() ?? Missing.string,
      lifeStage: lifeStageJson != null && lifeStageJson.isNotEmpty
          ? LifeStageSpec.fromJson(lifeStageJson)
          : const LifeStageSpec(stage: LifeStage.unknown),
      sizeSpec: sizeSpecJson != null && sizeSpecJson.isNotEmpty
          ? SizeSpec.fromJson(sizeSpecJson)
          : null,
      physicalForm: physicalFormJson != null && physicalFormJson.isNotEmpty
          ? PhysicalFormInstance.fromJson(physicalFormJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tagId': tagId,
    'lifeStage': lifeStage.toJson(),
    if (sizeSpec != null && !sizeSpec!.isEmpty) 'sizeSpec': sizeSpec!.toJson(),
    if (physicalForm != null) 'physicalForm': physicalForm!.toJson(),
  };

  @override
  List<Object?> get props => [tagId, lifeStage, sizeSpec, physicalForm];
}
