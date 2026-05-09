import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_snapshot_parser.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

class QuantityChangeEvent extends Event {
  QuantityChangeEvent({
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
    required this.oldMeasurement,
    required this.newMeasurement,
    this.oldCount,
    this.newCount,
    this.oldVolumeCm3,
    this.newVolumeCm3,
    this.oldTissueAreaCm2,
    this.newTissueAreaCm2,
    super.metadata,
    super.base,
    String? eventTypeId,
  }) : super(
         eventTypeId: eventTypeId ?? InventoryEventType.quantityChangeId,
       );

  factory QuantityChangeEvent.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: use safe patterns for all required fields
    return QuantityChangeEvent(
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
      oldMeasurement: PopulationMeasurement.fromJson(
        deepNormalizeMap(json['oldMeasurement']),
      ),
      newMeasurement: PopulationMeasurement.fromJson(
        deepNormalizeMap(json['newMeasurement']),
      ),
      oldCount: safeInt(json['oldCount']),
      newCount: safeInt(json['newCount']),
      oldVolumeCm3: safeDouble(json['oldVolumeCm3']),
      newVolumeCm3: safeDouble(json['newVolumeCm3']),
      oldTissueAreaCm2: safeDouble(json['oldTissueAreaCm2']),
      newTissueAreaCm2: safeDouble(json['newTissueAreaCm2']),
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
  final PopulationMeasurement oldMeasurement;
  final PopulationMeasurement newMeasurement;

  // Compound metric fields for 3-field measurement system
  final int? oldCount;
  final int? newCount;
  final double? oldVolumeCm3;
  final double? newVolumeCm3;
  final double? oldTissueAreaCm2;
  final double? newTissueAreaCm2;

  // Computed properties for deltas
  int? get countDelta => (newCount != null && oldCount != null)
      ? newCount! - oldCount!
      : null;

  double? get volumeDelta => (newVolumeCm3 != null && oldVolumeCm3 != null)
      ? newVolumeCm3! - oldVolumeCm3!
      : null;

  double? get tissueAreaDelta => (newTissueAreaCm2 != null && oldTissueAreaCm2 != null)
      ? newTissueAreaCm2! - oldTissueAreaCm2!
      : null;

  bool get hasCompoundChanges =>
      oldCount != null ||
      oldVolumeCm3 != null ||
      oldTissueAreaCm2 != null;

  // Legacy delta for backward compatibility
  double get delta => newMeasurement.value - oldMeasurement.value;

  @override
  QuantityChangeEvent copyWith({
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
    OrganismRecord? organismRecordSnapshot,
    PopulationMeasurement? oldMeasurement,
    PopulationMeasurement? newMeasurement,
    int? oldCount,
    int? newCount,
    double? oldVolumeCm3,
    double? newVolumeCm3,
    double? oldTissueAreaCm2,
    double? newTissueAreaCm2,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return QuantityChangeEvent(
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
      oldMeasurement: oldMeasurement ?? this.oldMeasurement,
      newMeasurement: newMeasurement ?? this.newMeasurement,
      oldCount: oldCount ?? this.oldCount,
      newCount: newCount ?? this.newCount,
      oldVolumeCm3: oldVolumeCm3 ?? this.oldVolumeCm3,
      newVolumeCm3: newVolumeCm3 ?? this.newVolumeCm3,
      oldTissueAreaCm2: oldTissueAreaCm2 ?? this.oldTissueAreaCm2,
      newTissueAreaCm2: newTissueAreaCm2 ?? this.newTissueAreaCm2,
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
    oldMeasurement,
    newMeasurement,
    oldCount,
    newCount,
    oldVolumeCm3,
    newVolumeCm3,
    oldTissueAreaCm2,
    newTissueAreaCm2,
  ];

  @override
  Map<String, dynamic> toJson() {
    return {
      'organismRecordSnapshot': organismRecordSnapshot.toJson(),
      'oldMeasurement': oldMeasurement.toJson(),
      'newMeasurement': newMeasurement.toJson(),
      if (oldCount != null) 'oldCount': oldCount,
      if (newCount != null) 'newCount': newCount,
      if (oldVolumeCm3 != null) 'oldVolumeCm3': oldVolumeCm3,
      if (newVolumeCm3 != null) 'newVolumeCm3': newVolumeCm3,
      if (oldTissueAreaCm2 != null) 'oldTissueAreaCm2': oldTissueAreaCm2,
      if (newTissueAreaCm2 != null) 'newTissueAreaCm2': newTissueAreaCm2,
      ...super.toJson(),
    };
  }
}
