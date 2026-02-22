// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_snapshot_parser.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Canonical event type for life stage transitions
///
/// This is the preferred event type for recording when organisms transition between
/// life stages. It extends the Event base class and integrates with the inventory
/// event system, providing full support for permits, metadata, and organism snapshots.
///
/// Use EventRepository.createLifeStageTransitionEvent() to create instances.
///
/// Note: Replaces the deprecated LifeStageProgressionEvent which was a standalone
/// event type that didn't integrate with the broader event system.
class LifeStageTransitionEvent extends Event {
  LifeStageTransitionEvent({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    required super.recordId,
    required super.recordModelType,
    required this.organismRecordSnapshot,
    required this.oldLifeStage,
    required this.newLifeStage,
    this.oldSubtype,
    this.newSubtype,
    this.transitionReason,
    String? eventTypeId,
    super.missionId,
    super.metadata,
    super.base,
  }) : super(
         eventTypeId: eventTypeId ?? InventoryEventType.lifeStageTransitionId,
       );

  factory LifeStageTransitionEvent.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: use safe patterns for all required fields
    return LifeStageTransitionEvent(
      id: Record.inferId(json) ?? Missing.string,
      eventTypeId: json['eventTypeId']?.toString(),
      createdById: Record.stringFromJson(json, 'createdById') ?? Missing.string,
      createdAt: Record.stringFromJson(json, 'createdAt') ?? Missing.dateTimeString,
      updatedAt: Record.stringFromJson(json, 'updatedAt') ??
          Record.stringFromJson(json, 'createdAt') ??
          Missing.dateTimeString,
      updatedById: Record.stringFromJson(json, 'updatedById') ??
          Record.stringFromJson(json, 'createdById') ??
          Missing.string,
      organizationId: Record.inferOrganizationId(json) ?? Missing.string,
      urlPath: json['urlPath'] ?? Missing.string,
      internalPath: json['internalPath'] ?? Missing.string,
      slug: json['slug'] ?? Missing.string,
      recordId: json['recordId'] ?? Missing.string,
      recordModelType: ModelType.values.byName(
        json['recordModelType'] ?? ModelType.organismRecord.name,
      ),
      organismRecordSnapshot: parseOrganismSnapshot(json),
      oldLifeStage: LifeStageX.tryParse(json['oldLifeStage']?.toString()) ??
          LifeStage.unknown,
      newLifeStage: LifeStageX.tryParse(json['newLifeStage']?.toString()) ??
          LifeStage.unknown,
      oldSubtype: json['oldSubtype']?.toString(),
      newSubtype: json['newSubtype']?.toString(),
      transitionReason: json['transitionReason']?.toString(),
      metadata: safeMapCast(json['metadata']),
      base: EventBaseParams(
        permitMetadata: EventPermitMetadata.fromJson(
          safeMapCast(json['permitMetadata']),
        ),
        geometry: OutplantGeometry.maybeFromJson(json['geometry']),
      ),
    );
  }

  final OrganismRecord organismRecordSnapshot;
  final LifeStage oldLifeStage;
  final LifeStage newLifeStage;
  final String? oldSubtype;
  final String? newSubtype;
  final String? transitionReason;

  @override
  LifeStageTransitionEvent copyWith({
    String? eventTypeId,
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? recordId,
    ModelType? recordModelType,
    String? missionId,
    bool clearMissionId = false,
    OrganismRecord? organismRecordSnapshot,
    LifeStage? oldLifeStage,
    LifeStage? newLifeStage,
    String? oldSubtype,
    String? newSubtype,
    String? transitionReason,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return LifeStageTransitionEvent(
      id: id ?? this.id,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      organismRecordSnapshot:
          organismRecordSnapshot ?? this.organismRecordSnapshot,
      oldLifeStage: oldLifeStage ?? this.oldLifeStage,
      newLifeStage: newLifeStage ?? this.newLifeStage,
      oldSubtype: oldSubtype ?? this.oldSubtype,
      newSubtype: newSubtype ?? this.newSubtype,
      transitionReason: transitionReason ?? this.transitionReason,
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    organismRecordSnapshot,
    oldLifeStage,
    newLifeStage,
    oldSubtype,
    newSubtype,
    transitionReason,
  ];

  @override
  Map<String, dynamic> toJson() {
    return {
      'organismRecordSnapshot': organismRecordSnapshot.toJson(),
      'oldLifeStage': oldLifeStage.id,
      'newLifeStage': newLifeStage.id,
      if (oldSubtype != null) 'oldSubtype': oldSubtype,
      if (newSubtype != null) 'newSubtype': newSubtype,
      if (transitionReason != null) 'transitionReason': transitionReason,
      ...super.toJson(),
    };
  }
}
