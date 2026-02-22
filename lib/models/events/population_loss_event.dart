// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class PopulationLossEvent extends InventoryEvent with CommentEvent {
  PopulationLossEvent({
    required super.id,
    required super.eventTypeId,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.recordModelType,
    required super.snapshot,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
    required this.oldPopulation,
    required this.newPopulation,
    required this.lossReasonId,
    this.comment,
  });

  PopulationLossEvent.fromJson(super.json)
    : oldPopulation = _parsePopulation(json['oldPopulation']),
      newPopulation = _parsePopulation(json['newPopulation']),
      lossReasonId = json['lossReasonId'] ?? '',
      comment = CommentEvent.commentFromJson(json),
      super.fromJson();

  static int _parsePopulation(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  final int oldPopulation;
  final int newPopulation;

  final String lossReasonId;

  int get delta => newPopulation - oldPopulation;

  @override
  String get eventTypeId => InventoryEventType.populationLoss.id;

  @override
  final String? comment;

  @override
  List<Object?> get props =>
      super.props + [lossReasonId, comment, oldPopulation, newPopulation];

  @override
  PopulationLossEvent copyWith({
    String? lossReasonId,
    String? comment,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
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
    String? eventTypeId,
    int? oldPopulation,
    int? newPopulation,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return PopulationLossEvent(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      snapshot: snapshot,
      oldPopulation: oldPopulation ?? this.oldPopulation,
      newPopulation: newPopulation ?? this.newPopulation,
      comment: comment ?? this.comment,
      lossReasonId: lossReasonId ?? this.lossReasonId,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
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
  bool validate() {
    return super.validate() &&
        oldPopulation > newPopulation &&
        newPopulation >= 0;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'oldPopulation': oldPopulation,
      'newPopulation': newPopulation,
      'lossReasonId': lossReasonId,
      'comment': comment,
    };
  }
}
