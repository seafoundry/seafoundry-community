// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Generic husbandry event used for outplant-specific maintenance actions such
/// as acquiring orthomosaics or recording site preparation work.
class OutplantActionEvent extends HusbandryEvent {
  OutplantActionEvent({
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
    super.missionId,
    super.metadata,
    super.base,
    required super.eventTypeId,
    super.imageUrl,
    super.comment,
  });

  factory OutplantActionEvent.fromJson(Map<String, dynamic> json) =>
      OutplantActionEvent.partial(json: json);

  OutplantActionEvent.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.recordId,
    super.recordModelType,
    super.urlPath,
    super.internalPath,
    super.slug,
    super.metadata,
    super.base,
    super.eventTypeId,
    super.comment,
    super.imageUrl,
  }) : super.partial();

  @override
  OutplantActionEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    ModelType? recordModelType,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? comment,
    String? imageUrl,
    String? eventTypeId,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
  }) {
    return OutplantActionEvent(
      id: id ?? this.id,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
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
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: clearGeometry ? null : geometry,
      ).copyWith(clearGeometry: clearGeometry ? true : null),
    );
  }
}
