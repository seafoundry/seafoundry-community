// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for seagrass sprig/module holdings.
class SeagrassModuleRepository
    extends HoldingRepository<SeagrassModuleHolding> {
  SeagrassModuleRepository({
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
             organismContext ?? OrganismContext.forKind(OrganismKind.seagrass),
         holdingKind: 'seagrassModuleHolding',
         fromJson: SeagrassModuleHolding.fromJson,
       );
}
