// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Types of maintenance that may be required
class MaintenanceRequiredType {
  final String id;
  final String label;

  const MaintenanceRequiredType._({required this.id, required this.label});

  static MaintenanceRequiredType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => MaintenanceRequiredType._(id: id, label: 'Unknown'),
    );
  }

  static const MaintenanceRequiredType plugReplacement =
      MaintenanceRequiredType._(
        id: 'plug_replacement',
        label: 'Plug Replacement Needed',
      );

  static const MaintenanceRequiredType rackRepair = MaintenanceRequiredType._(
    id: 'rack_repair',
    label: 'Rack Repair Needed',
  );

  static const MaintenanceRequiredType equipmentIssue =
      MaintenanceRequiredType._(
        id: 'equipment_issue',
        label: 'Equipment Issue',
      );

  static const MaintenanceRequiredType waterQualityIssue =
      MaintenanceRequiredType._(
        id: 'water_quality_issue',
        label: 'Water Quality Issue',
      );

  static const MaintenanceRequiredType lightingIssue =
      MaintenanceRequiredType._(id: 'lighting_issue', label: 'Lighting Issue');

  static const MaintenanceRequiredType flowIssue = MaintenanceRequiredType._(
    id: 'flow_issue',
    label: 'Flow Issue',
  );

  static const MaintenanceRequiredType temperatureIssue =
      MaintenanceRequiredType._(
        id: 'temperature_issue',
        label: 'Temperature Issue',
      );

  static const MaintenanceRequiredType other = MaintenanceRequiredType._(
    id: 'other',
    label: 'Other',
  );

  static const List<MaintenanceRequiredType> values = [
    plugReplacement,
    rackRepair,
    equipmentIssue,
    waterQualityIssue,
    lightingIssue,
    flowIssue,
    temperatureIssue,
    other,
  ];
}

/// Priority levels for maintenance
enum MaintenancePriority {
  low,
  medium,
  high,
  urgent;

  String get label {
    switch (this) {
      case MaintenancePriority.low:
        return 'Low';
      case MaintenancePriority.medium:
        return 'Medium';
      case MaintenancePriority.high:
        return 'High';
      case MaintenancePriority.urgent:
        return 'Urgent';
    }
  }
}

/// An observation event for identifying maintenance needs
class MaintenanceRequiredObservationEvent extends ObservationEvent {
  /// Type of maintenance required
  final String maintenanceTypeId;

  /// Priority level
  final String priority;

  /// Whether maintenance has been completed
  final bool completed;

  /// When maintenance was completed (if applicable)
  final DateTime? completedAt;

  MaintenanceRequiredObservationEvent({
    required super.id,
    required this.maintenanceTypeId,
    required this.priority,
    this.completed = false,
    this.completedAt,
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
  }) : super(eventTypeId: EventType.maintenanceRequiredObservation.id);

  MaintenanceRequiredObservationEvent.fromJson(super.json)
    : maintenanceTypeId = json['maintenanceTypeId'] ?? 'other',
      priority = json['priority'] ?? 'medium',
      completed = json['completed'] ?? false,
      completedAt = json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      super.fromJson();

  MaintenanceRequiredObservationEvent.partial({
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
    String? maintenanceTypeId,
    String? priority,
    bool? completed,
    DateTime? completedAt,
  }) : maintenanceTypeId =
           maintenanceTypeId ?? json?['maintenanceTypeId'] ?? 'other',
       priority = priority ?? json?['priority'] ?? 'medium',
       completed = completed ?? json?['completed'] ?? false,
       completedAt =
           completedAt ??
           (json?['completedAt'] != null
               ? DateTime.parse(json?['completedAt'])
               : null),
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'maintenanceTypeId': maintenanceTypeId,
      'priority': priority,
      'completed': completed,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }

  @override
  bool validate() {
    return super.validate() && maintenanceTypeId.isNotEmpty;
  }

  @override
  MaintenanceRequiredObservationEvent copyWith({
    String? id,
    String? maintenanceTypeId,
    String? priority,
    bool? completed,
    DateTime? completedAt,
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
    return MaintenanceRequiredObservationEvent(
      id: id ?? this.id,
      maintenanceTypeId: maintenanceTypeId ?? this.maintenanceTypeId,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
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
    maintenanceTypeId,
    priority,
    completed,
    completedAt,
  ];

  /// Get the maintenance type
  MaintenanceRequiredType get maintenanceType =>
      MaintenanceRequiredType.fromId(maintenanceTypeId) ??
      MaintenanceRequiredType.other;

  /// Get the priority enum
  MaintenancePriority get priorityLevel {
    try {
      return MaintenancePriority.values.firstWhere(
        (p) => p.name == priority,
        orElse: () => MaintenancePriority.medium,
      );
    } catch (_) {
      return MaintenancePriority.medium;
    }
  }
}
