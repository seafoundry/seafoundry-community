import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';

import '../types/event_type.dart';
import '../types/model_type.dart';

class CreateEvent extends InventoryEvent {
  CreateEvent({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.recordModelType,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    super.base,
    required super.snapshot,
  }) : super(eventTypeId: '');

  CreateEvent.fromJson(super.json) : super.fromJson();

  CreateEvent.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.recordId,
    super.recordModelType,
    super.urlPath,
    super.internalPath,
    super.slug,

    super.metadata,

    super.base,
  }) : super.partial();

  @override
  String get eventTypeId => EventType.create.id;

  @override
  bool validate() {
    return super.validate() && true;
  }

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson()};
  }

  @override
  CreateEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? eventTypeId,
    ModelType? recordModelType,
    InventoryRecord? snapshot,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) => CreateEvent(
    id: id ?? this.id,
    createdById: createdById ?? this.createdById,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    recordId: recordId ?? this.recordId,
    recordModelType: recordModelType ?? this.recordModelType,
    urlPath: urlPath ?? this.urlPath,
    internalPath: internalPath ?? this.internalPath,
    slug: slug ?? this.slug,
    metadata: metadata ?? this.metadata,
    base: resolveBaseParams(permitMetadata: permitMetadata, geometry: geometry),
    snapshot: snapshot ?? this.snapshot,
  );
}
