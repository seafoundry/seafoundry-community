import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/size_change_snapshot.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

class SizeChangeEvent extends Event {
  SizeChangeEvent({
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
    required this.oldSize,
    required this.newSize,
    String? eventTypeId,
    super.metadata,
    super.base,
  }) : super(
         eventTypeId: eventTypeId ?? InventoryEventType.sizeChangeId,
       );

  factory SizeChangeEvent.fromJson(Map<String, dynamic> json) {
    return SizeChangeEvent(
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
      organismRecordSnapshot: SizeChangeSnapshot.fromJson(
        deepNormalizeMap(json['organismRecordSnapshot']),
      ),
      oldSize: SizeSpec.fromJson(
        deepNormalizeMap(json['oldSize']),
      ),
      newSize: SizeSpec.fromJson(
        deepNormalizeMap(json['newSize']),
      ),
      metadata: safeMapCast(json['metadata']),
      base: EventBaseParams(
        geometry: OutplantGeometry.maybeFromJson(json['geometry']),
      ),
    );
  }

  final SizeChangeSnapshot organismRecordSnapshot;
  final SizeSpec oldSize;
  final SizeSpec newSize;

  @override
  SizeChangeEvent copyWith({
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
    SizeChangeSnapshot? organismRecordSnapshot,
    SizeSpec? oldSize,
    SizeSpec? newSize,
    Map<String, dynamic>? metadata,
    OutplantGeometry? geometry,
  }) {
    return SizeChangeEvent(
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
      oldSize: oldSize ?? this.oldSize,
      newSize: newSize ?? this.newSize,
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
    oldSize,
    newSize,
  ];

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'organismRecordSnapshot': organismRecordSnapshot.toJson(),
      'oldSize': oldSize.toJson(),
      'newSize': newSize.toJson(),
    };
  }
}
