// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for crab pond holdings.
class CrabPondRepository extends HoldingRepository<CrabPondHolding> {
  CrabPondRepository({
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
             organismContext ?? OrganismContext.forKind(OrganismKind.crab),
         holdingKind: 'crabPondHolding',
         fromJson: CrabPondHolding.fromJson,
       );
}
