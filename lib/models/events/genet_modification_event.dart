import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class GenetModificationEvent extends Event {
  final Map<String, dynamic> changes;

  GenetModificationEvent({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    super.base,
    required super.recordId,
    required super.recordModelType,
    required this.changes,
  }) : super(eventTypeId: EventType.genetModification.id);

  GenetModificationEvent.fromJson(super.json)
    : changes = Map<String, dynamic>.from(json['changes'] ?? const {}),
      super.fromJson();

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'changes': changes};

  @override
  GenetModificationEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? eventTypeId,
    String? recordId,
    ModelType? recordModelType,
    String? urlPath,
    String? internalPath,
    String? slug,
    Map<String, dynamic>? changes,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
  }) {
    return GenetModificationEvent(
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
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: clearGeometry ? null : geometry,
      ).copyWith(clearGeometry: clearGeometry ? true : null),
      changes: changes ?? Map<String, dynamic>.from(this.changes),
    );
  }
}
