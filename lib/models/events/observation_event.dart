// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class ObservationEvent extends Event with ImageEvent {
  @override
  final String? imageUrl;
  final String? comment;
  final String? oldHealthStatus;
  final String? newHealthStatus;
  final String? healthIssueTypeId;
  final bool createTask;

  ObservationEvent({
    required super.id,
    this.comment,
    this.imageUrl,
    this.oldHealthStatus,
    this.newHealthStatus,
    this.healthIssueTypeId,
    this.createTask = false,
    required super.createdById,
    required super.createdAt,
    required super.recordId,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
    required super.recordModelType,
    String? eventTypeId,
  }) : super(eventTypeId: eventTypeId ?? EventType.observation.id);

  ObservationEvent.fromJson(super.json)
    : imageUrl = json['imageUrl'],
      comment = json['comment'],
      oldHealthStatus = json['oldHealthStatus'],
      newHealthStatus = json['newHealthStatus'],
      healthIssueTypeId = json['healthIssueTypeId'],
      createTask = json['createTask'] ?? false,
      super.fromJson();

  ObservationEvent.partial({
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
    String? imageUrl,
    String? comment,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    bool? createTask,
  }) : imageUrl = imageUrl ?? json?['imageUrl'],
       comment = comment ?? json?['comment'],
       oldHealthStatus = oldHealthStatus ?? json?['oldHealthStatus'],
       newHealthStatus = newHealthStatus ?? json?['newHealthStatus'],
       healthIssueTypeId = healthIssueTypeId ?? json?['healthIssueTypeId'],
       createTask = createTask ?? json?['createTask'] ?? false,
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'comment': comment,
      'imageUrl': imageUrl,
      'oldHealthStatus': oldHealthStatus,
      'newHealthStatus': newHealthStatus,
      'healthIssueTypeId': healthIssueTypeId,
      'createTask': createTask,
    };
  }

  /// Returns true if this observation includes a health status change
  bool get isHealthStatusChange =>
      oldHealthStatus != null &&
      newHealthStatus != null &&
      oldHealthStatus != newHealthStatus;

  /// Get the old health status as enum
  HealthStatus? get oldHealthStatusEnum =>
      HealthStatus.maybeFromId(oldHealthStatus);

  /// Get the new health status as enum
  HealthStatus? get newHealthStatusEnum =>
      HealthStatus.maybeFromId(newHealthStatus);

  @override
  bool validate() {
    return super.validate() &&
        ((comment?.isNotEmpty ?? false) || imageUrl != null);
  }

  @override
  ObservationEvent copyWith({
    String? id,
    String? comment,
    String? imageUrl,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    bool? createTask,
    String? eventTypeId,
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
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return ObservationEvent(
      id: id ?? this.id,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
      oldHealthStatus: oldHealthStatus ?? this.oldHealthStatus,
      newHealthStatus: newHealthStatus ?? this.newHealthStatus,
      healthIssueTypeId: healthIssueTypeId ?? this.healthIssueTypeId,
      createTask: createTask ?? this.createTask,
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
        geometry: geometry,
      ),
      eventTypeId: eventTypeId ?? this.eventTypeId,
    );
  }

  @override
  List<Object?> get props => super.props + [comment, imageUrl, oldHealthStatus, newHealthStatus, healthIssueTypeId, createTask];
}
