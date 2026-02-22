// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/status_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/status_event_type.dart';

class PropagationReadyStatus extends StatusEvent {
  PropagationReadyStatus({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    super.concludedAt,
    required super.recordId,
    required super.recordModelType,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
    required this.genetId,
    required super.subEventIds,
  }) : super(eventTypeId: '');

  PropagationReadyStatus.fromJson(super.json)
    : genetId = json['genetId'],
      super.fromJson();

  final String genetId;

  @override
  String get eventTypeId => StatusEventType.propagationReady.id;

  @override
  bool validate() {
    return super.validate() && genetId.isNotEmpty;
  }

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'genetId': genetId};
  }

  @override
  PropagationReadyStatus copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? concludedAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? eventTypeId,
    ModelType? recordModelType,
    List<String>? subEventIds,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
  }) => PropagationReadyStatus(
    id: id ?? this.id,
    createdById: createdById ?? this.createdById,
    createdAt: createdAt ?? this.createdAt,
    concludedAt: concludedAt ?? this.concludedAt,
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
    genetId: genetId,
    subEventIds: subEventIds ?? this.subEventIds,
  );
}
