import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class StatusEvent extends Event {
  StatusEvent({
    required super.id,
    required super.eventTypeId,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    this.concludedAt,
    required super.recordId,
    required super.recordModelType,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    super.base,
    required this.subEventIds,
  });

  StatusEvent.partial({
    super.json,
    super.id,
    super.eventTypeId,
    super.createdById,
    super.createdAt,
    String? concludedAt,
    super.recordId,
    super.recordModelType,
    super.urlPath,
    super.internalPath,
    super.slug,

    super.metadata,

    super.base,
    List<String>? subEventIds,
  }) : concludedAt = concludedAt ?? json?['concludedAt'],
       subEventIds = List<String>.from(json?['subEventIds'] ?? []),
       super.partial();

  StatusEvent.fromJson(super.json)
    : concludedAt = json['concludedAt'],
      subEventIds = List<String>.from(json['subEventIds'] ?? []),
      super.fromJson();

  final String? concludedAt;
  final List<String> subEventIds;

  bool get isConcluded => concludedAt != null;

  @override
  Map<String, dynamic> toJson() {
    return {
      'concludedAt': concludedAt,
      'subEventIds': subEventIds,
      ...super.toJson(),
    };
  }

  @override
  StatusEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? concludedAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? eventTypeId,
    ModelType? recordModelType,
    List<String>? subEventIds,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
  }) {
    return StatusEvent(
      id: id ?? this.id,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      concludedAt: concludedAt ?? this.concludedAt,
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
    );
  }

  @override
  bool validate() {
    return super.validate() &&
        (concludedAt == null || createdAt.compareTo(concludedAt!) < 0);
  }

  @override
  List<Object?> get props => super.props + [concludedAt, subEventIds];
}
