import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/move_event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Event representing corals moving out of a structure
class MoveOutEvent extends Event with MoveEvent {
  @override
  final String toUrlPath;

  @override
  final String fromParentId;

  @override
  final String toParentId;

  final List<String> movedCoralIds;
  final String? movedRecordId;
  final int? quantity;
  final String? reason;

  MoveOutEvent({
    required super.id,
    required this.toUrlPath,
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
  }) : super(eventTypeId: 'event_move_out');

  MoveOutEvent.fromJson(super.json)
    : toUrlPath = json['toUrlPath'],
      fromParentId = json['fromParentId'],
      toParentId = json['toParentId'],
      movedCoralIds = List<String>.from(json['movedCoralIds'] ?? []),
      movedRecordId = json['movedRecordId'],
      quantity = json['quantity'],
      reason = json[eventReasonField] as String?,
      super.fromJson();

  MoveOutEvent.partial({
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
    String? toUrlPath,
    String? fromParentId,
    String? toParentId,
    List<String>? movedCoralIds,
    String? movedRecordId,
    int? quantity,
    String? reason,
  }) : toUrlPath = toUrlPath ?? json?['toUrlPath'] ?? 'unknown',
       fromParentId = fromParentId ?? json?['fromParentId'] ?? 'unknown',
       toParentId = toParentId ?? json?['toParentId'] ?? 'unknown',
       movedCoralIds =
           movedCoralIds ?? List<String>.from(json?['movedCoralIds'] ?? []),
       movedRecordId = movedRecordId ?? json?['movedRecordId'],
       quantity = quantity ?? json?['quantity'],
       reason = reason ?? json?[eventReasonField] as String?,
       super.partial(
         eventTypeId: eventTypeId ?? EventType.moveOut.id,
       );

  @override
  String get fromUrlPath => urlPath; // Moving FROM this structure

  @override
  bool validate() {
    return super.validate() &&
        toUrlPath.isNotEmpty &&
        fromParentId.isNotEmpty &&
        toParentId.isNotEmpty;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'toUrlPath': toUrlPath,
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
        toUrlPath,
        fromParentId,
        toParentId,
        movedCoralIds,
        movedRecordId,
        quantity,
        reason,
      ];

  @override
  MoveOutEvent copyWith({
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
    String? toUrlPath,
    String? fromParentId,
    String? toParentId,
    List<String>? movedCoralIds,
    String? movedRecordId,
    int? quantity,
    String? reason,
    Map<String, dynamic>? metadata,
    OutplantGeometry? geometry,
  }) {
    return MoveOutEvent(
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

      toUrlPath: toUrlPath ?? this.toUrlPath,
      fromParentId: fromParentId ?? this.fromParentId,
      toParentId: toParentId ?? this.toParentId,
      movedCoralIds: movedCoralIds ?? this.movedCoralIds,
      movedRecordId: movedRecordId ?? this.movedRecordId,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
    );
  }
}
