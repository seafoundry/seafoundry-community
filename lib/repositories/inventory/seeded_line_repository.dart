// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Repository for kelp seeded-line holdings (batch inventory for longlines,
/// rafts, and dropper rigs). Uses the neutral holding storage under
/// `organizations/{org}/holdings`.
class SeededLineRepository extends HoldingRepository<SeededLineBatch> {
  SeededLineRepository({
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
             organismContext ?? OrganismContext.forKind(OrganismKind.kelp),
         holdingKind: 'seededLineBatch',
         fromJson: SeededLineBatch.fromJson,
       );
}
