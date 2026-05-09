// @tier: community
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/move_event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Event representing corals moving into a structure
class MoveInEvent extends Event with MoveEvent {
  @override
  final String fromUrlPath;

  @override
  final String fromParentId;

  @override
  final String toParentId;

  final List<String> movedCoralIds;
  final String? movedRecordId;
  final int? quantity;
  final String? reason;

  MoveInEvent({
    required super.id,
    required this.fromUrlPath,
    required this.fromParentId,
    required this.toParentId,
    required this.movedCoralIds,
    this.movedRecordId,
    this.quantity,
    this.reason,
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
  }) : super(eventTypeId: 'event_move_in');

  MoveInEvent.fromJson(super.json)
    : fromUrlPath = json['fromUrlPath'],
      fromParentId = json['fromParentId'],
      toParentId = json['toParentId'],
      movedCoralIds = List<String>.from(json['movedCoralIds'] ?? []),
      movedRecordId = json['movedRecordId'],
      quantity = json['quantity'],
      reason = json[eventReasonField] as String?,
      super.fromJson();

  MoveInEvent.partial({
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
    String? eventTypeId,
    String? fromUrlPath,
    String? fromParentId,
    String? toParentId,
    List<String>? movedCoralIds,
    String? movedRecordId,
    int? quantity,
    String? reason,
  }) : fromUrlPath = fromUrlPath ?? json?['fromUrlPath'] ?? 'unknown',
       fromParentId = fromParentId ?? json?['fromParentId'] ?? 'unknown',
       toParentId = toParentId ?? json?['toParentId'] ?? 'unknown',
       movedCoralIds =
           movedCoralIds ?? List<String>.from(json?['movedCoralIds'] ?? []),
       movedRecordId = movedRecordId ?? json?['movedRecordId'],
       quantity = quantity ?? json?['quantity'],
       reason = reason ?? json?[eventReasonField] as String?,
       super.partial(
         eventTypeId: eventTypeId ?? EventType.moveIn.id,
       );

  @override
  String get toUrlPath => urlPath; // Moving TO this structure

  @override
  bool validate() {
    return super.validate() &&
        fromUrlPath.isNotEmpty &&
        fromParentId.isNotEmpty &&
        toParentId.isNotEmpty;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'fromUrlPath': fromUrlPath,
      'fromParentId': fromParentId,
      'toParentId': toParentId,
      'movedCoralIds': movedCoralIds,
      if (movedRecordId != null) 'movedRecordId': movedRecordId,
      if (quantity != null) 'quantity': quantity,
      if (reason != null) eventReasonField: reason,
    };
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        fromUrlPath,
        fromParentId,
        toParentId,
        movedCoralIds,
        movedRecordId,
        quantity,
        reason,
      ];

  @override
  MoveInEvent copyWith({
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
    String? fromUrlPath,
    String? fromParentId,
    String? toParentId,
    List<String>? movedCoralIds,
    String? movedRecordId,
    int? quantity,
    String? reason,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return MoveInEvent(
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

      fromUrlPath: fromUrlPath ?? this.fromUrlPath,
      fromParentId: fromParentId ?? this.fromParentId,
      toParentId: toParentId ?? this.toParentId,
      movedCoralIds: movedCoralIds ?? this.movedCoralIds,
      movedRecordId: movedRecordId ?? this.movedRecordId,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
    );
  }
}
