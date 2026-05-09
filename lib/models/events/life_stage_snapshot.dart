import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Minimal audit snapshot persisted on a [LifeStageTransitionEvent].
///
/// Audit field set: tagId, lifeStage, physicalForm, measurement.
/// These capture the prior identity/state that is meaningful when reviewing a
/// stage transition. Heavier OrganismRecord state (aliases, history,
/// foreignKeys, geometry, provenance) is intentionally omitted: events
/// already carry old/new lifeStage on the event itself, and the parent
/// OrganismRecord remains the system of record for the rest.
class LifeStageSnapshot extends Equatable {
  const LifeStageSnapshot({
    required this.tagId,
    required this.lifeStage,
    this.physicalForm,
    this.measurement,
  });

  final String tagId;
  final LifeStageSpec lifeStage;
  final PhysicalFormInstance? physicalForm;
  final PopulationMeasurement? measurement;

  factory LifeStageSnapshot.fromOrganismRecord(OrganismRecord record) {
    return LifeStageSnapshot(
      tagId: record.tagId,
      lifeStage: record.lifeStage,
      physicalForm: record.physicalForm,
      measurement: record.measurement,
    );
  }

  factory LifeStageSnapshot.fromJson(Map<String, dynamic> json) {
    final lifeStageJson = safeMapCast(json['lifeStage']);
    final physicalFormJson = safeMapCast(json['physicalForm']);
    final measurementJson = safeMapCast(json['measurement']);
    return LifeStageSnapshot(
      tagId: json['tagId']?.toString() ?? Missing.string,
      lifeStage: lifeStageJson != null && lifeStageJson.isNotEmpty
          ? LifeStageSpec.fromJson(lifeStageJson)
          : const LifeStageSpec(stage: LifeStage.unknown),
      physicalForm: physicalFormJson != null && physicalFormJson.isNotEmpty
          ? PhysicalFormInstance.fromJson(physicalFormJson)
          : null,
      measurement: measurementJson != null && measurementJson.isNotEmpty
          ? PopulationMeasurement.fromJson(measurementJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tagId': tagId,
    'lifeStage': lifeStage.toJson(),
    if (physicalForm != null) 'physicalForm': physicalForm!.toJson(),
    if (measurement != null) 'measurement': measurement!.toJson(),
  };

  @override
  List<Object?> get props => [tagId, lifeStage, physicalForm, measurement];
}
