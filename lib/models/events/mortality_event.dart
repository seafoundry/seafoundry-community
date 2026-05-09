import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/population_loss_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';

class MortalityEvent extends PopulationLossEvent {
  MortalityEvent({
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
    required super.oldPopulation,
    required super.newPopulation,
    super.comment,
    required this.mortalityReasonId,
    this.diseaseTypeId,
  }) : super(lossReasonId: '');

  MortalityEvent.fromPopulationLossEvent(
    PopulationLossEvent event, {
    required this.mortalityReasonId,
    this.diseaseTypeId,
  }) : super(
         id: event.id,
         eventTypeId: event.eventTypeId,
         updatedAt: event.updatedAt,
         updatedById: event.updatedById,
         organizationId: event.organizationId,
         createdById: event.createdById,
         createdAt: event.createdAt,
         recordId: event.recordId,
         recordModelType: event.recordModelType,
         snapshot: event.snapshot,
         urlPath: event.urlPath,
         internalPath: event.internalPath,
         slug: event.slug,
         oldPopulation: event.oldPopulation,
         newPopulation: event.newPopulation,
         lossReasonId: PopulationLossReason.mortality.id,
         base: EventBaseParams(
           permitMetadata: event.permitMetadata,
           geometry: event.geometry,
         ),
       );

  MortalityEvent.fromJson(super.json)
    : mortalityReasonId =
          (json['mortalityReasonId'] as String?) ??
          PopulationLossReason.mortality.id,
      diseaseTypeId = json['diseaseTypeId'] as String?,
      super.fromJson();

  final String mortalityReasonId;
  final String? diseaseTypeId;

  @override
  String get lossReasonId => PopulationLossReason.mortality.id;

  @override
  List<Object?> get props => super.props + [mortalityReasonId];

  @override
  MortalityEvent copyWith({
    String? comment,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? mortalityReasonId,
    String? id,
    String? recordId,
    ModelType? recordModelType,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? createdById,
    String? createdAt,
    String? eventTypeId,
    String? lossReasonId,
    String? diseaseTypeId,
    int? oldPopulation,
    int? newPopulation,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return MortalityEvent(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      snapshot: snapshot,
      oldPopulation: oldPopulation ?? this.oldPopulation,
      newPopulation: newPopulation ?? this.newPopulation,
      comment: comment ?? this.comment,
      mortalityReasonId: mortalityReasonId ?? this.mortalityReasonId,
      diseaseTypeId: diseaseTypeId ?? this.diseaseTypeId,
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
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'mortalityReasonId': mortalityReasonId,
      'diseaseTypeId': diseaseTypeId,
    };
  }
}
