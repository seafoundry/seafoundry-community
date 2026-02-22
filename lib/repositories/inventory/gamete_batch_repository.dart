// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for gamete batch holdings (coral/oyster spawn collections).
class GameteBatchRepository extends HoldingRepository<GameteBatch> {
  GameteBatchRepository({
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
             organismContext ?? OrganismContext.forKind(OrganismKind.coral),
         holdingKind: 'gameteBatch',
         fromJson: GameteBatch.fromJson,
       );
}
