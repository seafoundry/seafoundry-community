// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/status_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/status_event_type.dart';

class RecentPropagationStatus extends StatusEvent {
  RecentPropagationStatus({
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
    super.metadata,
    super.base,
    required super.subEventIds,
    required this.propagationEventId,
  }) : super(eventTypeId: '');

  RecentPropagationStatus.fromJson(super.json)
    : propagationEventId = json['propagationEventId'] ?? json['fragEventId'],
      super.fromJson();

  final String propagationEventId;

  @override
  String get eventTypeId => StatusEventType.recentPropagation.id;

  @override
  List<Object?> get props => super.props + [propagationEventId];

  @override
  bool validate() {
    return super.validate() && propagationEventId.isNotEmpty;
  }

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'propagationEventId': propagationEventId};
  }

  @override
  RecentPropagationStatus copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? recordId,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? eventTypeId,
    ModelType? recordModelType,
    List<String>? subEventIds,
    String? propagationEventId,
    String? concludedAt,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
  }) => RecentPropagationStatus(
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
    subEventIds: subEventIds ?? this.subEventIds,
    propagationEventId: propagationEventId ?? this.propagationEventId,
    concludedAt: concludedAt ?? this.concludedAt,
  );
}
