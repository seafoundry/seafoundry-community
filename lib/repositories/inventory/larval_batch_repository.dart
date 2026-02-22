// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for larval batch holdings (post-spawn culture prior to settlement).
class LarvalBatchRepository extends HoldingRepository<LarvalBatch> {
  LarvalBatchRepository({
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
         holdingKind: 'larvalBatch',
         fromJson: LarvalBatch.fromJson,
       );
}
