// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';

abstract class InventoryEvent extends Event with SnapshotEvent {
  InventoryEvent({
    required super.id,
    required super.eventTypeId,
    required super.recordId,
    required super.recordModelType,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
    required this.snapshot,
  });

  InventoryEvent.fromJson(super.json)
    : snapshot = SnapshotEvent.snapshotFromJson(json),
      super.fromJson();

  InventoryEvent.partial({
    super.json,
    super.id,
    super.eventTypeId,
    super.recordId,
    super.recordModelType,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.urlPath,
    super.internalPath,
    super.slug,

    super.metadata,

    super.base,
    InventoryRecord? snapshot,
  }) : snapshot =
           snapshot ??
           SnapshotEvent.snapshotFromJson(json ?? {}),
       super.partial();

  @override
  final InventoryRecord snapshot;

  @override
  List<Object?> get props => super.props + [snapshot];

  @override
  Map<String, dynamic> toJson() {
    return {'snapshotData': snapshot.toJson(), ...super.toJson()};
  }

  @override
  bool validate() {
    return super.validate() && snapshot.validate();
  }
}
