// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class PopulationGainEvent extends InventoryEvent with CommentEvent {
  PopulationGainEvent({
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
    super.metadata,
    super.base,
    required this.oldPopulation,
    required this.newPopulation,
    required this.gainReasonId,
    this.comment,
  });

  PopulationGainEvent.fromJson(super.json)
    : oldPopulation = _parsePopulation(json['oldPopulation']),
      newPopulation = _parsePopulation(json['newPopulation']),
      gainReasonId = json['gainReasonId'] ?? '',
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

  final String gainReasonId;

  int get delta => newPopulation - oldPopulation;

  @override
  String get eventTypeId => InventoryEventType.populationGain.id;

  @override
  final String? comment;

  @override
  List<Object?> get props =>
      super.props + [gainReasonId, comment, oldPopulation, newPopulation];

  @override
  PopulationGainEvent copyWith({
    String? gainReasonId,
    String? comment,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? id,
    String? recordId,
    ModelType? recordModelType,
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
    return PopulationGainEvent(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      snapshot: snapshot,
      oldPopulation: oldPopulation ?? this.oldPopulation,
      newPopulation: newPopulation ?? this.newPopulation,
      comment: comment ?? this.comment,
      gainReasonId: gainReasonId ?? this.gainReasonId,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
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
    return super.validate() && newPopulation > oldPopulation;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'oldPopulation': oldPopulation,
      'newPopulation': newPopulation,
      'gainReasonId': gainReasonId,
      'comment': comment,
    };
  }
}
