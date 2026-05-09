import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Event representing bulk updates to multiple corals
class UpdateEvent extends Event {
  final String updateType;
  final Map<String, dynamic> fieldUpdates;
  final String? notes;

  UpdateEvent({
    required super.id,
    required this.updateType,
    required this.fieldUpdates,
    this.notes,
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
  }) : super(eventTypeId: EventType.update.id);

  UpdateEvent.fromJson(super.json)
    : updateType = json['updateType'] ?? 'unknown',
      fieldUpdates = Map<String, dynamic>.from(json['fieldUpdates'] ?? {}),
      notes = json['notes'],
      super.fromJson();

  @override
  bool validate() {
    return super.validate() && updateType.isNotEmpty && fieldUpdates.isNotEmpty;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'updateType': updateType,
      'fieldUpdates': fieldUpdates,
      'notes': notes,
    };
  }

  UpdateEvent.partial({
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
    String? updateType,
    Map<String, dynamic>? fieldUpdates,
    String? notes,
  }) : updateType = updateType ?? json?['updateType'] ?? 'unknown',
       fieldUpdates =
           fieldUpdates ??
           Map<String, dynamic>.from(json?['fieldUpdates'] ?? const {}),
       notes = notes ?? json?['notes'],
       super.partial();

  @override
  List<Object?> get props => super.props + [updateType, fieldUpdates, notes];

  @override
  UpdateEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? eventTypeId,
    String? recordId,
    ModelType? recordModelType,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? updateType,
    Map<String, dynamic>? fieldUpdates,
    String? notes,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return UpdateEvent(
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
        geometry: geometry,
      ),

      updateType: updateType ?? this.updateType,
      fieldUpdates: fieldUpdates ?? this.fieldUpdates,
      notes: notes ?? this.notes,
    );
  }
}
