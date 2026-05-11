import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/physical_form_snapshot.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

class PhysicalFormChangeEvent extends Event {
  PhysicalFormChangeEvent({
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
    this.oldFormId,
    this.newFormId,
    String? eventTypeId,
    super.metadata,
    super.base,
  }) : super(eventTypeId: eventTypeId ?? InventoryEventType.physicalFormChangeId);

  factory PhysicalFormChangeEvent.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: use safe patterns for all required fields
    return PhysicalFormChangeEvent(
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
      organismRecordSnapshot: PhysicalFormSnapshot.fromJson(
        deepNormalizeMap(json['organismRecordSnapshot']),
      ),
      oldFormId: json['oldFormId']?.toString(),
      newFormId: json['newFormId']?.toString(),
      metadata: safeMapCast(json['metadata']),
      base: EventBaseParams(
        geometry: OutplantGeometry.maybeFromJson(json['geometry']),
      ),
    );
  }

  final PhysicalFormSnapshot organismRecordSnapshot;
  final String? oldFormId;
  final String? newFormId;

  @override
  PhysicalFormChangeEvent copyWith({
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
    PhysicalFormSnapshot? organismRecordSnapshot,
    String? oldFormId,
    String? newFormId,
    Map<String, dynamic>? metadata,
    OutplantGeometry? geometry,
  }) {
    return PhysicalFormChangeEvent(
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
      oldFormId: oldFormId ?? this.oldFormId,
      newFormId: newFormId ?? this.newFormId,
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        geometry: geometry,
      ),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    organismRecordSnapshot,
    oldFormId,
    newFormId,
  ];

  @override
  Map<String, dynamic> toJson() {
    return {
      'organismRecordSnapshot': organismRecordSnapshot.toJson(),
      if (oldFormId != null) 'oldFormId': oldFormId,
      if (newFormId != null) 'newFormId': newFormId,
      ...super.toJson(),
    };
  }
}
