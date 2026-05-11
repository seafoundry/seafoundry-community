import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// An event that represents a specific activity with flexible parameters.
/// Used for tracking various activities like fragmentation steps, maintenance tasks, etc.
class ActivityEvent extends Event {
  final String activityType;
  final String? description;
  final Map<String, dynamic>? parameters;

  ActivityEvent({
    required super.id,
    required this.activityType,
    this.description,
    this.parameters,
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
    super.metadata,
    super.base,
  }) : super(eventTypeId: 'event_activity');

  ActivityEvent.fromJson(super.json)
    : activityType = json['activityType'] ?? 'unknown',
      description = json['description'],
      parameters = json['parameters'] != null
          ? Map<String, dynamic>.from(json['parameters'])
          : null,
      super.fromJson();

  ActivityEvent.partial({
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
    String? activityType,
    String? description,
    Map<String, dynamic>? parameters,
  }) : activityType = activityType ?? json?['activityType'] ?? 'unknown',
       description = description ?? json?['description'],
       parameters =
           parameters ??
           (json?['parameters'] != null
               ? Map<String, dynamic>.from(json?['parameters'])
               : null),
       super.partial();

  @override
  bool validate() {
    return super.validate() && activityType.isNotEmpty;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'activityType': activityType,
      'description': description,
      'parameters': parameters,
    };
  }

  @override
  List<Object?> get props =>
      super.props + [activityType, description, parameters];

  @override
  ActivityEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    ModelType? recordModelType,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? eventTypeId,
    String? activityType,
    String? description,
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? metadata,
    OutplantGeometry? geometry,
  }) {
    return ActivityEvent(
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
        geometry: geometry,
      ),

      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      parameters: parameters ?? this.parameters,
    );
  }
}
