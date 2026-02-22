// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/population_loss_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';

/// Event representing a mortality at an outplanting site.
/// Tracks outplant-specific mortality causes (pest/predation, disease, thermal stress,
/// water quality, unknown) separately from nursery mortalities.
class OutplantMortalityEvent extends PopulationLossEvent {
  OutplantMortalityEvent({
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
    required super.oldPopulation,
    required super.newPopulation,
    super.comment,
    required this.outplantLossReasonId,
    this.diseaseTypeId,
  }) : super(lossReasonId: '');

  OutplantMortalityEvent.fromPopulationLossEvent(
    PopulationLossEvent event, {
    required this.outplantLossReasonId,
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
         metadata: event.metadata,
         oldPopulation: event.oldPopulation,
         newPopulation: event.newPopulation,
         lossReasonId: outplantLossReasonId,
         base: EventBaseParams(
           permitMetadata: event.permitMetadata,
           geometry: event.geometry,
         ),
       );

  OutplantMortalityEvent.fromJson(super.json)
    : outplantLossReasonId =
          (json['outplantLossReasonId'] as String?) ??
          (json['lossReasonId'] as String?) ??
          OutplantLossReason.unknown.id,
      diseaseTypeId = json['diseaseTypeId'] as String?,
      super.fromJson();

  /// The specific outplant loss reason (pest/predation, disease, thermal stress, water quality, unknown)
  final String outplantLossReasonId;

  /// Optional disease type when the loss reason is disease
  final String? diseaseTypeId;

  @override
  String get lossReasonId => outplantLossReasonId;

  @override
  List<Object?> get props =>
      super.props + [outplantLossReasonId, diseaseTypeId];

  @override
  OutplantMortalityEvent copyWith({
    String? comment,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? outplantLossReasonId,
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
    String? lossReasonId,
    String? diseaseTypeId,
    int? oldPopulation,
    int? newPopulation,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
  }) {
    return OutplantMortalityEvent(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      snapshot: snapshot,
      oldPopulation: oldPopulation ?? this.oldPopulation,
      newPopulation: newPopulation ?? this.newPopulation,
      comment: comment ?? this.comment,
      outplantLossReasonId: outplantLossReasonId ?? this.outplantLossReasonId,
      diseaseTypeId: diseaseTypeId ?? this.diseaseTypeId,
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
        geometry: clearGeometry ? null : geometry,
      ).copyWith(clearGeometry: clearGeometry ? true : null),
      eventTypeId: eventTypeId ?? this.eventTypeId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'outplantLossReasonId': outplantLossReasonId,
      if (diseaseTypeId != null) 'diseaseTypeId': diseaseTypeId,
      ...super.toJson(),
    };
  }

  @override
  bool validate() {
    return super.validate() &&
        OutplantLossReason.builtins.containsKey(outplantLossReasonId);
  }
}
