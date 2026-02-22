// @tier: community
import 'package:seafoundry_app/models/types/coral_size.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class CoralSizeEvent extends InventoryEvent with CommentEvent {
  CoralSizeEvent({
    required super.id,
    required super.eventTypeId,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.snapshot,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
    this.oldSize,
    required this.newSize,
    this.comment,
  }) : super(recordModelType: ModelType.organismRecord);

  CoralSizeEvent.fromJson(super.json)
    : oldSize = json['oldSize'] != null
          ? CoralSize.values.byName(json['oldSize'])
          : null,
      newSize = CoralSize.values.byName(json['newSize']),
      comment = json['comment'],
      super.fromJson();

  final CoralSize? oldSize;
  final CoralSize newSize;

  @override
  final String? comment;

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'oldSize': oldSize?.name,
      'newSize': newSize.name,
      'comment': comment,
    };
  }

  @override
  CoralSizeEvent copyWith({
    String? lossReasonId,
    String? comment,
    String? id,
    String? recordId,
    ModelType? recordModelType,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? eventTypeId,
    CoralSize? oldSize,
    CoralSize? newSize,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return CoralSizeEvent(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      snapshot: snapshot,
      oldSize: oldSize ?? this.oldSize,
      newSize: newSize ?? this.newSize,
      comment: comment ?? this.comment,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),

      eventTypeId: eventTypeId ?? this.eventTypeId,
    );
  }

  @override
  List<Object?> get props => super.props + [oldSize, newSize, comment];

  @override
  bool validate() {
    return super.validate() && validateSizeChange();
  }

  bool validateSizeChange() {
    if (oldSize == null) {
      return eventTypeId == CoralSizeEventType.sizeAdded.id;
    } else if (eventTypeId == CoralSizeEventType.growth.id) {
      return oldSize!.index < newSize.index;
    } else if (eventTypeId == CoralSizeEventType.tissueLoss.id) {
      return oldSize!.index > newSize.index;
    }
    return false;
  }
}
