// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';

/// Repository for oyster spat bag holdings.
class OysterBagRepository extends HoldingRepository<OysterBagHolding> {
  OysterBagRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    required super.eventRepository,
    required super.changeService,
    required super.snapshotService,
    OrganismContext? organismContext,
    StructureCapacityService? structureCapacityService,
  }) : super(
         organismContext:
             organismContext ?? OrganismContext.forKind(OrganismKind.oyster),
         holdingKind: 'oysterBagHolding',
         fromJson: OysterBagHolding.fromJson,
         structureCapacityService:
             structureCapacityService ?? StructureCapacityService.disabled(),
       );
}
