// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/observation_severity.dart';

/// Types of pest organisms that can be observed
class PestType {
  final String id;
  final String label;

  const PestType._({required this.id, required this.label});

  static PestType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => PestType._(id: id, label: 'Unknown'),
    );
  }

  static const PestType aiptasia = PestType._(
    id: 'aiptasia',
    label: 'Aiptasia',
  );
  static const PestType hydroids = PestType._(
    id: 'hydroids',
    label: 'Hydroids',
  );
  static const PestType tunicates = PestType._(
    id: 'tunicates',
    label: 'Tunicates',
  );
  static const PestType other = PestType._(id: 'other', label: 'Other');

  static const List<PestType> values = [aiptasia, hydroids, tunicates, other];
}

/// An observation event specifically for pest detection
class PestObservationEvent extends ObservationEvent {
  /// Type of pest observed
  final String pestTypeId;

  /// Severity of the pest presence
  final String severity;

  /// Location on structure/coral
  final String? location;

  /// Whether mitigation (removal/treatment) was performed
  final bool mitigationPerformed;

  PestObservationEvent({
    required super.id,
    required this.pestTypeId,
    required this.severity,
    this.location,
    this.mitigationPerformed = false,
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
  }) : super(eventTypeId: 'event_pest_observation');

  PestObservationEvent.fromJson(super.json)
    : pestTypeId = json['pestTypeId'] ?? 'other',
      severity = json['severity'] ?? 'moderate',
      location = json['location'],
      mitigationPerformed = json['mitigationPerformed'] ?? false,
      super.fromJson();

  PestObservationEvent.partial({
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
    String? pestTypeId,
    String? severity,
    String? location,
    bool? mitigationPerformed,
  }) : pestTypeId = pestTypeId ?? json?['pestTypeId'] ?? 'other',
       severity = severity ?? json?['severity'] ?? 'moderate',
       location = location ?? json?['location'],
       mitigationPerformed =
           mitigationPerformed ?? json?['mitigationPerformed'] ?? false,
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'pestTypeId': pestTypeId,
      'severity': severity,
      if (location != null) 'location': location,
      'mitigationPerformed': mitigationPerformed,
    };
  }

  @override
  bool validate() {
    return super.validate() && pestTypeId.isNotEmpty;
  }

  @override
  PestObservationEvent copyWith({
    String? id,
    String? pestTypeId,
    String? severity,
    String? location,
    bool? mitigationPerformed,
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
    return PestObservationEvent(
      id: id ?? this.id,
      pestTypeId: pestTypeId ?? this.pestTypeId,
      severity: severity ?? this.severity,
      location: location ?? this.location,
      mitigationPerformed: mitigationPerformed ?? this.mitigationPerformed,
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
    pestTypeId,
    severity,
    location,
    mitigationPerformed,
  ];

  PestType get pestType => PestType.fromId(pestTypeId) ?? PestType.other;

  ObservationSeverity get severityLevel {
    return ObservationSeverity.tryParse(severity) ??
        ObservationSeverity.moderate;
  }
}
