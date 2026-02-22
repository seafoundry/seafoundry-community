// @tier: community
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Shared helpers for holding constructors that need to install default
/// physical form identifiers and resolve nullable life stages.
class HoldingConstructorHelper {
  const HoldingConstructorHelper._();

  static LifeStage resolveLifeStage(
    LifeStage? stage, {
    required LifeStage fallback,
  }) {
    return stage ?? fallback;
  }

  static HoldingConstructorDefaults prepare({
    required OrganismKind organismKind,
    required PopulationMeasurement measurement,
    required String recordName,
    required String? localId,
    LifeStage? requestedLifeStage,
    required LifeStage fallbackLifeStage,
    PhysicalFormInstance? fallbackPhysicalForm,
    Map<String, dynamic>? metadata,
    OrganismRecord? organismRecord,
    HoldingAttributes? attributes,
  }) {
    final normalizedRecordName = recordName.trim();
    if (normalizedRecordName.isEmpty) {
      throw ArgumentError('recordName is required for holdings.');
    }
    final resolvedLocalId = _resolveLocalId(
      localId: localId,
      organismRecord: organismRecord,
    );
    final resolvedLifeStage = resolveLifeStage(
      requestedLifeStage,
      fallback: fallbackLifeStage,
    );
    final resolvedRecord =
        (organismRecord ??
                OrganismRecord.partial(
                  organismKind: organismKind,
                  recordName: normalizedRecordName,
                  localId: resolvedLocalId,
                  lifeStage: LifeStageSpec(stage: resolvedLifeStage),
                  measurement: measurement,
                  aliases: const <OrganismAlias>[],
                ))
            .copyWith(
              organismKind: organismKind,
              recordName: normalizedRecordName,
              localId: resolvedLocalId,
              lifeStage: LifeStageSpec(stage: resolvedLifeStage),
              measurement: measurement,
              physicalForm:
                  organismRecord?.physicalForm ?? fallbackPhysicalForm,
            );
    final speciesId = attributes?.speciesId?.trim();
    final normalizedRecord =
        speciesId != null && speciesId.isNotEmpty
            ? resolvedRecord.copyWith(speciesId: speciesId)
            : resolvedRecord;

    return HoldingConstructorDefaults(
      lifeStage: resolvedLifeStage,
      metadata: metadata ?? const <String, dynamic>{},
      organismRecord: normalizedRecord,
    );
  }

  static String _resolveLocalId({
    required String? localId,
    required OrganismRecord? organismRecord,
  }) {
    final trimmed = localId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    final recordLocalId = organismRecord?.localId?.trim();
    if (recordLocalId != null && recordLocalId.isNotEmpty) {
      return recordLocalId;
    }
    throw ArgumentError('localId is required for holdings.');
  }
}

class HoldingConstructorDefaults {
  const HoldingConstructorDefaults({
    required this.lifeStage,
    required this.metadata,
    required this.organismRecord,
  });

  final LifeStage lifeStage;
  final Map<String, dynamic> metadata;
  final OrganismRecord organismRecord;
}
