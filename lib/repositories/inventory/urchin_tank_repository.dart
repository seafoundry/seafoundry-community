// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for urchin (echinoid) tank holdings.
class UrchinTankRepository extends HoldingRepository<UrchinTankHolding> {
  UrchinTankRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    required super.eventRepository,
    required super.changeService,
    required super.snapshotService,
    OrganismContext? organismContext,
    super.structureCapacityService,
  }) : super(
         organismContext:
             organismContext ?? OrganismContext.forKind(OrganismKind.echinoid),
         holdingKind: 'urchinTankHolding',
         fromJson: UrchinTankHolding.fromJson,
       );
}
