// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/types/disease_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/observation_severity.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// An observation event specifically for disease detection
class DiseaseObservationEvent extends ObservationEvent {
  /// Type of disease observed
  final String diseaseTypeId;

  /// Severity of the disease
  final String severity;

  /// Percentage of coral affected (0-100)
  final double? affectedPercentage;

  /// Whether treatment was initiated
  final bool treatmentInitiated;

  DiseaseObservationEvent({
    required super.id,
    required this.diseaseTypeId,
    required this.severity,
    this.affectedPercentage,
    this.treatmentInitiated = false,
    super.imageUrl,
    super.comment,
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
  }) : super(eventTypeId: 'event_disease_observation');

  DiseaseObservationEvent.fromJson(super.json)
    : diseaseTypeId = json['diseaseTypeId'] ?? 'other',
      severity = json['severity'] ?? 'moderate',
      affectedPercentage = safeDouble(json['affectedPercentage']),
      treatmentInitiated = json['treatmentInitiated'] ?? false,
      super.fromJson();

  DiseaseObservationEvent.partial({
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
    super.imageUrl,
    super.comment,
    String? diseaseTypeId,
    String? severity,
    double? affectedPercentage,
    bool? treatmentInitiated,
  }) : diseaseTypeId = diseaseTypeId ?? json?['diseaseTypeId'] ?? 'other',
       severity = severity ?? json?['severity'] ?? 'moderate',
       affectedPercentage =
           affectedPercentage ??
           safeDouble(json?['affectedPercentage']),
       treatmentInitiated =
           treatmentInitiated ?? json?['treatmentInitiated'] ?? false,
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'diseaseTypeId': diseaseTypeId,
      'severity': severity,
      if (affectedPercentage != null) 'affectedPercentage': affectedPercentage,
      'treatmentInitiated': treatmentInitiated,
    };
  }

  @override
  bool validate() {
    return super.validate() && diseaseTypeId.isNotEmpty;
  }

  @override
  DiseaseObservationEvent copyWith({
    String? id,
    String? diseaseTypeId,
    String? severity,
    double? affectedPercentage,
    bool? treatmentInitiated,
    String? imageUrl,
    String? comment,
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
    return DiseaseObservationEvent(
      id: id ?? this.id,
      diseaseTypeId: diseaseTypeId ?? this.diseaseTypeId,
      severity: severity ?? this.severity,
      affectedPercentage: affectedPercentage ?? this.affectedPercentage,
      treatmentInitiated: treatmentInitiated ?? this.treatmentInitiated,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
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

  @override
  List<Object?> get props => [
    ...super.props,
    diseaseTypeId,
    severity,
    affectedPercentage,
    treatmentInitiated,
  ];

  /// Get the disease type
  DiseaseType get diseaseType =>
      DiseaseType.builtins[diseaseTypeId] ?? DiseaseType.other;

  /// Get the severity enum
  ObservationSeverity get severityLevel {
    return ObservationSeverity.tryParse(severity) ??
        ObservationSeverity.moderate;
  }
}
