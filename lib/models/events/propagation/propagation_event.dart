// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class PropagationEvent extends Event {
  PropagationEvent({
    required super.id,
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
    super.missionId,
    super.metadata,
    super.base,
    required this.genetId,
    required this.inputOrganismIds,
    required this.outputOrganismIds,
    required this.inputQuantity,
    required this.outputQuantity,
  }) : super(eventTypeId: '');

  PropagationEvent.fromJson(super.json)
    : genetId = json['genetId'],
      inputOrganismIds = List<String>.from(json['inputOrganismIds'] ?? json['inputCoralIds'] ?? []),
      outputOrganismIds = List<String>.from(json['outputOrganismIds'] ?? json['outputCoralIds'] ?? []),
      inputQuantity = json['inputQuantity'],
      outputQuantity = json['outputQuantity'],
      super.fromJson();

  PropagationEvent.partial({
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
    String? genetId,
    List<String>? inputOrganismIds,
    List<String>? outputOrganismIds,
    int? inputQuantity,
    int? outputQuantity,
  }) : genetId = genetId ?? json?['genetId'] ?? Missing.string,
       inputOrganismIds =
           inputOrganismIds ?? List<String>.from(json?['inputOrganismIds'] ?? json?['inputCoralIds'] ?? []),
       outputOrganismIds =
           outputOrganismIds ?? List<String>.from(json?['outputOrganismIds'] ?? json?['outputCoralIds'] ?? []),
       inputQuantity = inputQuantity ?? json?['inputQuantity'],
       outputQuantity = outputQuantity ?? json?['outputQuantity'],
       super.partial();

  final String genetId;
  final List<String> inputOrganismIds;
  final List<String> outputOrganismIds;
  final int inputQuantity;
  final int outputQuantity;

  @override
  String get eventTypeId => EventType.propagation.id;

  @override
  bool validate() {
    return super.validate() &&
        inputQuantity > 0 &&
        outputQuantity > inputQuantity;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'genetId': genetId,
      'inputOrganismIds': inputOrganismIds,
      'outputOrganismIds': outputOrganismIds,
      'inputQuantity': inputQuantity,
      'outputQuantity': outputQuantity,
    };
  }

  @override
  PropagationEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    String? urlPath,
    String? internalPath,
    ModelType? recordModelType,
    String? missionId,
    bool clearMissionId = false,
    String? slug,
    String? genetId,
    List<String>? inputOrganismIds,
    List<String>? outputOrganismIds,
    int? inputQuantity,
    int? outputQuantity,
    String? eventTypeId,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) => PropagationEvent(
    id: id ?? this.id,
    createdById: createdById ?? this.createdById,
    createdAt: createdAt ?? this.createdAt,
    recordId: recordId ?? this.recordId,
    recordModelType: recordModelType ?? this.recordModelType,
    urlPath: urlPath ?? this.urlPath,
    internalPath: internalPath ?? this.internalPath,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    slug: slug ?? this.slug,
    missionId: clearMissionId ? null : (missionId ?? this.missionId),
    metadata: metadata ?? this.metadata,
    base: resolveBaseParams(permitMetadata: permitMetadata, geometry: geometry),

    genetId: genetId ?? this.genetId,
    inputOrganismIds: inputOrganismIds ?? this.inputOrganismIds,
    outputOrganismIds: outputOrganismIds ?? this.outputOrganismIds,
    inputQuantity: inputQuantity ?? this.inputQuantity,
    outputQuantity: outputQuantity ?? this.outputQuantity,
  );
}
