// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/observation_severity.dart';

/// Types of biofouling that can be observed
class BiofoulingType {
  final String id;
  final String label;

  const BiofoulingType._({required this.id, required this.label});

  static BiofoulingType? fromId(String? id) {
    if (id == null) return null;
    return allValues.firstWhere(
      (type) => type.id == id,
      orElse: () => BiofoulingType._(id: id, label: 'Unknown'),
    );
  }

  static const BiofoulingType algae = BiofoulingType._(
    id: 'algae',
    label: 'Algae Growth',
  );

  static const BiofoulingType cyanobacteria = BiofoulingType._(
    id: 'cyanobacteria',
    label: 'Cyanobacteria',
  );

  static const BiofoulingType diatoms = BiofoulingType._(
    id: 'diatoms',
    label: 'Diatoms',
  );

  static const BiofoulingType aiptasia = BiofoulingType._(
    id: 'aiptasia',
    label: 'Aiptasia',
  );

  static const BiofoulingType hydroids = BiofoulingType._(
    id: 'hydroids',
    label: 'Hydroids',
  );

  static const BiofoulingType sponges = BiofoulingType._(
    id: 'sponges',
    label: 'Sponges',
  );

  static const BiofoulingType tunicates = BiofoulingType._(
    id: 'tunicates',
    label: 'Tunicates',
  );

  static const BiofoulingType other = BiofoulingType._(
    id: 'other',
    label: 'Other',
  );

  static const List<BiofoulingType> values = [
    algae,
    cyanobacteria,
    diatoms,
    sponges,
    other,
  ];

  /// Complete list including legacy biofouling types that have moved to pest observations.
  static const List<BiofoulingType> allValues = [
    algae,
    cyanobacteria,
    diatoms,
    sponges,
    other,
    aiptasia,
    hydroids,
    tunicates,
  ];
}

/// An observation event specifically for biofouling detection
class BiofoulingObservationEvent extends ObservationEvent {
  /// Type of biofouling observed
  final String biofoulingTypeId;

  /// Severity of the biofouling
  final String severity;

  /// Location on coral (base, sides, top, etc.)
  final String? location;

  /// Whether cleaning was performed
  final bool cleaningPerformed;

  BiofoulingObservationEvent({
    required super.id,
    required this.biofoulingTypeId,
    required this.severity,
    this.location,
    this.cleaningPerformed = false,
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
  }) : super(eventTypeId: 'event_biofouling_observation');

  BiofoulingObservationEvent.fromJson(super.json)
    : biofoulingTypeId = json['biofoulingTypeId'] ?? 'other',
      severity = json['severity'] ?? 'moderate',
      location = json['location'],
      cleaningPerformed = json['cleaningPerformed'] ?? false,
      super.fromJson();

  BiofoulingObservationEvent.partial({
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
    String? biofoulingTypeId,
    String? severity,
    String? location,
    bool? cleaningPerformed,
  }) : biofoulingTypeId =
           biofoulingTypeId ?? json?['biofoulingTypeId'] ?? 'other',
       severity = severity ?? json?['severity'] ?? 'moderate',
       location = location ?? json?['location'],
       cleaningPerformed =
           cleaningPerformed ?? json?['cleaningPerformed'] ?? false,
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'biofoulingTypeId': biofoulingTypeId,
      'severity': severity,
      if (location != null) 'location': location,
      'cleaningPerformed': cleaningPerformed,
    };
  }

  @override
  bool validate() {
    return super.validate() && biofoulingTypeId.isNotEmpty;
  }

  @override
  BiofoulingObservationEvent copyWith({
    String? id,
    String? biofoulingTypeId,
    String? severity,
    String? location,
    bool? cleaningPerformed,
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
    return BiofoulingObservationEvent(
      id: id ?? this.id,
      biofoulingTypeId: biofoulingTypeId ?? this.biofoulingTypeId,
      severity: severity ?? this.severity,
      location: location ?? this.location,
      cleaningPerformed: cleaningPerformed ?? this.cleaningPerformed,
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
    biofoulingTypeId,
    severity,
    location,
    cleaningPerformed,
  ];

  /// Get the biofouling type
  BiofoulingType get biofoulingType =>
      BiofoulingType.fromId(biofoulingTypeId) ?? BiofoulingType.other;

  /// Get the severity enum
  ObservationSeverity get severityLevel {
    return ObservationSeverity.tryParse(severity) ??
        ObservationSeverity.moderate;
  }
}
