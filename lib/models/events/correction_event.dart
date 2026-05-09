// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class CorrectionEvent extends Event {
  CorrectionEvent({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    EventBaseParams base = const EventBaseParams(),
    required super.recordId,
    required super.recordModelType,
    required this.originalEventId,
    required this.correctedEventId,
    this.notes,
    required super.eventTypeId,
  });

  CorrectionEvent.fromJson(super.json)
    : originalEventId = json['originalEventId'] ?? Missing.string,
      correctedEventId = json['correctedEventId'] ?? Missing.string,
      notes = json['notes'],
      super.fromJson();

  final String originalEventId;
  final String correctedEventId;
  final String? notes;

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'originalEventId': originalEventId,
      'correctedEventId': correctedEventId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  @override
  CorrectionEvent copyWith({
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
    String? originalEventId,
    String? correctedEventId,
    String? notes,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return CorrectionEvent(
      id: id ?? this.id,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),

      eventTypeId: eventTypeId ?? this.eventTypeId,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      originalEventId: originalEventId ?? this.originalEventId,
      correctedEventId: correctedEventId ?? this.correctedEventId,
      notes: notes ?? this.notes,
    );
  }
}
