// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class SettleEvent extends Event {
  final String crossEventId;
  final int? settledCount;

  SettleEvent({
    required super.id,
    required this.crossEventId,
    this.settledCount,
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
  }) : super(eventTypeId: EventType.settle.id);

  SettleEvent.fromJson(super.json)
    : crossEventId = json['crossEventId'],
      settledCount = json['settledCount'],
      super.fromJson();

  @override
  Map<String, dynamic> toJson() {
    return {
      'crossEventId': crossEventId,
      'settledCount': settledCount,
      ...super.toJson(),
    };
  }

  SettleEvent.partial({
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
    String? crossEventId,
    int? settledCount,
  }) : crossEventId = crossEventId ?? json?['crossEventId'] ?? '',
       settledCount = settledCount ?? json?['settledCount'],
       super.partial();

  @override
  SettleEvent copyWith({
    String? id,
    String? crossEventId,
    int? settledCount,
    String? createdById,
    String? createdAt,
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
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
  }) {
    return SettleEvent(
      id: id ?? this.id,
      crossEventId: crossEventId ?? this.crossEventId,
      settledCount: settledCount ?? this.settledCount,
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

  @override
  bool validate() {
    return super.validate() && crossEventId.isNotEmpty;
  }

  @override
  List<Object?> get props => super.props + [crossEventId, settledCount];
}
