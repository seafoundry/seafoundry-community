// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

class SpawnEvent extends Event {
  @override
  bool validate() {
    return super.validate() &&
        parentOrganismIds.isNotEmpty &&
        gameteCount > 0 &&
        gameteRole != null;
  }

  final List<String> parentOrganismIds;
  final int gameteCount;
  final ProvenanceGameteRole? gameteRole;

  SpawnEvent({
    required super.id,
    required this.parentOrganismIds,
    required this.gameteCount,
    this.gameteRole,
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
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    OutplantGeometry? geometry,
    EventBaseParams base = const EventBaseParams(),
  }) : super(
         eventTypeId: EventType.spawn.id,
         base: EventBaseParams(
           permitMetadata: base.permitMetadata ?? permitMetadata,
           geometry: base.clearGeometry ? null : base.geometry ?? geometry,
           clearGeometry: base.clearGeometry,
         ),
       );

  SpawnEvent.fromJson(super.json)
    : parentOrganismIds = _parseParentIds(json),
      gameteCount = json['gameteCount'],
      gameteRole = ProvenanceGameteRoleX.tryParse(
        json['gameteRole']?.toString(),
      ),
      super.fromJson();

  /// Parse parent IDs with backward compatibility for old 'parentCoralIds' field
  static List<String> _parseParentIds(Map<String, dynamic> json) {
    if (json.containsKey('parentOrganismIds')) {
      return List<String>.from(json['parentOrganismIds']);
    }
    // Backward compatibility: Support old 'parentCoralIds' field
    if (json.containsKey('parentCoralIds')) {
      return List<String>.from(json['parentCoralIds']);
    }
    return [];
  }

  SpawnEvent.partial({
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
    super.eventTypeId,
    List<String>? parentOrganismIds,
    int? gameteCount,
    ProvenanceGameteRole? gameteRole,
    super.permitMetadata,
    super.geometry,
    super.base,
  }) : parentOrganismIds =
           parentOrganismIds ?? _parseParentIds(json ?? {}),
       gameteCount = gameteCount ?? json?['gameteCount'] ?? 0,
       gameteRole = gameteRole ??
           ProvenanceGameteRoleX.tryParse(json?['gameteRole']?.toString()),
       super.partial();

  @override
  List<Object?> get props =>
      super.props + [parentOrganismIds, gameteCount, gameteRole];

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'parentOrganismIds': parentOrganismIds,
      'gameteCount': gameteCount,
      if (gameteRole != null) 'gameteRole': gameteRole!.name,
    };
  }

  @override
  SpawnEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    ModelType? recordModelType,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? eventTypeId,
    List<String>? parentOrganismIds,
    int? gameteCount,
    ProvenanceGameteRole? gameteRole,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return SpawnEvent(
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
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
      parentOrganismIds: parentOrganismIds ?? this.parentOrganismIds,
      gameteCount: gameteCount ?? this.gameteCount,
      gameteRole: gameteRole ?? this.gameteRole,
    );
  }
}
