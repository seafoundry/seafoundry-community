// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

class CrossEvent extends Event {
  final List<String> damIds;
  final List<String> sireIds;

  CrossEvent({
    required super.id,
    required this.damIds,
    required this.sireIds,
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
  }) : super(eventTypeId: 'event_cross');

  CrossEvent.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.recordId,
    ModelType? recordModelType,
    super.urlPath,
    super.internalPath,
    super.slug,

    super.metadata,

    super.base,
    super.eventTypeId,
    List<String>? damIds,
    List<String>? sireIds,
  }) : damIds = _listFrom(json, 'damIds', damIds),
       sireIds = _listFrom(json, 'sireIds', sireIds),
       super.partial(
         recordModelType: recordModelType ?? ModelType.genet,
       );

  CrossEvent.fromJson(super.json)
    : damIds = _listFrom(json, 'damIds', null),
      sireIds = _listFrom(json, 'sireIds', null),
      super.fromJson();

  @override
  Map<String, dynamic> toJson() {
    return {'damIds': damIds, 'sireIds': sireIds, ...super.toJson()};
  }

  @override
  CrossEvent copyWith({
    String? id,
    List<String>? damIds,
    List<String>? sireIds,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? eventTypeId,
    ModelType? recordModelType,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return CrossEvent(
      id: id ?? this.id,
      damIds: damIds ?? this.damIds,
      sireIds: sireIds ?? this.sireIds,
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
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
    );
  }

  @override
  List<Object?> get props => super.props + [damIds, sireIds];

  static List<String> _listFrom(
    Map<String, dynamic>? source,
    String key,
    List<String>? override,
  ) {
    if (override != null) {
      return override;
    }

    final value = source != null ? source[key] : null;
    if (value is List) {
      return value.whereType<String>().toList();
    }

    return const [];
  }
}
