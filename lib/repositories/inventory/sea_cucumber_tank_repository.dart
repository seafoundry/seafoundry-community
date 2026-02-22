// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for sea cucumber tank holdings.
class SeaCucumberTankRepository extends HoldingRepository<SeaCucumberTankHolding> {
  SeaCucumberTankRepository({
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
             organismContext ?? OrganismContext.forKind(OrganismKind.seaCucumber),
         holdingKind: 'seaCucumberTankHolding',
         fromJson: SeaCucumberTankHolding.fromJson,
       );
}
