// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/types/health_issue_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/observation_severity.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// An observation event specifically for thermal stress detection
class ThermalStressObservationEvent extends ObservationEvent {
  /// Severity of the thermal stress observation
  final String severity;

  /// Percentage of coral affected (0-100)
  final double? affectedPercentage;

  ThermalStressObservationEvent({
    required super.id,
    required this.severity,
    this.affectedPercentage,
    super.imageUrl,
    super.comment,
    String? healthIssueTypeId,
    super.createTask,
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
  }) : super(
         eventTypeId: 'event_thermal_stress_observation',
         healthIssueTypeId:
             healthIssueTypeId ?? HealthIssueType.thermalStress.id,
       );

  ThermalStressObservationEvent.fromJson(super.json)
    : severity = json['severity'] ?? ObservationSeverity.moderate.name,
      affectedPercentage = safeDouble(json['affectedPercentage']),
      super.fromJson();

  ThermalStressObservationEvent.partial({
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
    String? severity,
    double? affectedPercentage,
    String? healthIssueTypeId,
    super.createTask,
  }) : severity =
           severity ?? json?['severity'] ?? ObservationSeverity.moderate.name,
       affectedPercentage =
           affectedPercentage ??
           safeDouble(json?['affectedPercentage']),
       super.partial(
         healthIssueTypeId:
             healthIssueTypeId ??
             json?['healthIssueTypeId'] ??
             HealthIssueType.thermalStress.id,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'severity': severity,
      'affectedPercentage': affectedPercentage,
    };
  }

  @override
  ThermalStressObservationEvent copyWith({
    String? id,
    String? severity,
    double? affectedPercentage,
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
    return ThermalStressObservationEvent(
      id: id ?? this.id,
      severity: severity ?? this.severity,
      affectedPercentage: affectedPercentage ?? this.affectedPercentage,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
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
    );
  }
}
