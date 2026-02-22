// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for mangrove plot holdings.
class MangrovePlotRepository extends HoldingRepository<MangrovePlotHolding> {
  MangrovePlotRepository({
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
              organismContext ?? OrganismContext.forKind(OrganismKind.mangrove),
          holdingKind: 'mangrovePlotHolding',
          fromJson: MangrovePlotHolding.fromJson,
        );
}
