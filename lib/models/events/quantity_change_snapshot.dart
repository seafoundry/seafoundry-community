import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Minimal audit snapshot persisted on a [QuantityChangeEvent].
///
/// Audit field set: tagId, measurement, lifeStage.
/// Captures the prior population measurement plus life stage so that an
/// auditor reviewing a quantity delta knows which organism kind/stage
/// the count applied to. Old/new measurement (with compound metric
/// fields) are already on the event itself.
class QuantityChangeSnapshot extends Equatable {
  const QuantityChangeSnapshot({
    required this.tagId,
    required this.lifeStage,
    this.measurement,
  });

  final String tagId;
  final LifeStageSpec lifeStage;
  final PopulationMeasurement? measurement;

  factory QuantityChangeSnapshot.fromOrganismRecord(OrganismRecord record) {
    return QuantityChangeSnapshot(
      tagId: record.tagId,
      lifeStage: record.lifeStage,
      measurement: record.measurement,
    );
  }

  factory QuantityChangeSnapshot.fromJson(Map<String, dynamic> json) {
    final lifeStageJson = safeMapCast(json['lifeStage']);
    final measurementJson = safeMapCast(json['measurement']);
    return QuantityChangeSnapshot(
      tagId: json['tagId']?.toString() ?? Missing.string,
      lifeStage: lifeStageJson != null && lifeStageJson.isNotEmpty
          ? LifeStageSpec.fromJson(lifeStageJson)
          : const LifeStageSpec(stage: LifeStage.unknown),
      measurement: measurementJson != null && measurementJson.isNotEmpty
          ? PopulationMeasurement.fromJson(measurementJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tagId': tagId,
    'lifeStage': lifeStage.toJson(),
    if (measurement != null) 'measurement': measurement!.toJson(),
  };

  @override
  List<Object?> get props => [tagId, lifeStage, measurement];
}
