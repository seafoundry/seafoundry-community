// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/services/organism_record_change_service.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';

/// Factory for creating generic [HoldingRepository] instances.
///
/// Use the [create] method when you need a repository for a holding type
/// that does not have a dedicated subclass. For named types (e.g.
/// [OysterBagRepository], [SeededLineRepository]), call their constructors
/// directly -- the convenience wrappers have been removed.
class HoldingRepositoryFactory {
  HoldingRepositoryFactory._();

  /// Creates a repository for the specified holding type.
  ///
  /// This is the core factory method that instantiates a properly-configured
  /// [HoldingRepository] with the required dependencies and type-specific
  /// configuration (organism kind, holding kind string, and fromJson function).
  static HoldingRepository<T> create<T extends HoldingRecord>({
    required Organization organization,
    required User user,
    required FirebaseFirestore firestore,
    required EventRepository eventRepository,
    required OrganismRecordChangeService changeService,
    required SnapshotService snapshotService,
    required OrganismKind organismKind,
    required String holdingKind,
    required T Function(Map<String, dynamic>) fromJson,
    OrganismContext? organismContext,
    StructureCapacityService? structureCapacityService,
  }) {
    return _ConcreteHoldingRepository<T>(
      organization: organization,
      user: user,
      firestore: firestore,
      eventRepository: eventRepository,
      changeService: changeService,
      snapshotService: snapshotService,
      organismContext: organismContext ?? OrganismContext.forKind(organismKind),
      holdingKind: holdingKind,
      fromJson: fromJson,
      structureCapacityService:
          structureCapacityService ?? StructureCapacityService.disabled(),
    );
  }
}

/// Concrete implementation of HoldingRepository for factory instantiation.
/// This allows the factory to instantiate repositories without requiring
/// individual subclass definitions for each holding type.
class _ConcreteHoldingRepository<T extends HoldingRecord>
    extends HoldingRepository<T> {
  _ConcreteHoldingRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    required super.eventRepository,
    required super.changeService,
    required super.snapshotService,
    required super.organismContext,
    required super.holdingKind,
    required super.fromJson,
    super.structureCapacityService,
  });
}
