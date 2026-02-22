// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Site environment context for maintenance types
enum SiteEnvironment {
  /// Land-based facilities with controlled environments (tanks, raceways, LSS)
  exSitu,

  /// Ocean-based/in-water environments (trees, tables, outplant sites)
  inSitu,
}

/// Types of structure maintenance
class StructureMaintenanceType {
  final String id;
  final String label;

  /// Which site environments this maintenance type is applicable to.
  /// If empty, the type is applicable to all environments.
  final Set<SiteEnvironment> applicableEnvironments;

  const StructureMaintenanceType._({
    required this.id,
    required this.label,
    this.applicableEnvironments = const {},
  });

  /// Whether this maintenance type is applicable to all site environments
  bool get isUniversal => applicableEnvironments.isEmpty;

  /// Whether this maintenance type is applicable to the given environment
  bool isApplicableTo(SiteEnvironment environment) {
    return isUniversal || applicableEnvironments.contains(environment);
  }

  static StructureMaintenanceType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => StructureMaintenanceType._(id: id, label: 'Unknown'),
    );
  }

  /// Get maintenance types applicable to a specific site environment
  static List<StructureMaintenanceType> valuesFor(SiteEnvironment environment) {
    return values.where((type) => type.isApplicableTo(environment)).toList();
  }

  // === Universal maintenance types (applicable to all environments) ===

  static const StructureMaintenanceType rackRepair = StructureMaintenanceType._(
    id: 'rack_repair',
    label: 'Rack Repair',
  );

  static const StructureMaintenanceType plugReplacement =
      StructureMaintenanceType._(
        id: 'plug_replacement',
        label: 'Plug Replacement',
      );

  static const StructureMaintenanceType equipmentMaintenance =
      StructureMaintenanceType._(
        id: 'equipment_maintenance',
        label: 'Equipment Maintenance',
      );

  static const StructureMaintenanceType other = StructureMaintenanceType._(
    id: 'other',
    label: 'Other',
  );

  // === Ex-situ only maintenance types (land-based facilities) ===

  static const StructureMaintenanceType plumbingRepair =
      StructureMaintenanceType._(
        id: 'plumbing_repair',
        label: 'Plumbing Repair',
        applicableEnvironments: {SiteEnvironment.exSitu},
      );

  static const StructureMaintenanceType pumpMaintenance =
      StructureMaintenanceType._(
        id: 'pump_maintenance',
        label: 'Pump Maintenance',
        applicableEnvironments: {SiteEnvironment.exSitu},
      );

  static const StructureMaintenanceType heaterMaintenance =
      StructureMaintenanceType._(
        id: 'heater_maintenance',
        label: 'Heater Maintenance',
        applicableEnvironments: {SiteEnvironment.exSitu},
      );

  static const StructureMaintenanceType lightingMaintenance =
      StructureMaintenanceType._(
        id: 'lighting_maintenance',
        label: 'Lighting Maintenance',
        applicableEnvironments: {SiteEnvironment.exSitu},
      );

  static const StructureMaintenanceType filterChange =
      StructureMaintenanceType._(
        id: 'filter_change',
        label: 'Filter Change',
        applicableEnvironments: {SiteEnvironment.exSitu},
      );

  // === In-situ only maintenance types (ocean-based) ===

  static const StructureMaintenanceType lineReplacement =
      StructureMaintenanceType._(
        id: 'line_replacement',
        label: 'Line Replacement',
        applicableEnvironments: {SiteEnvironment.inSitu},
      );

  static const StructureMaintenanceType anchorMaintenance =
      StructureMaintenanceType._(
        id: 'anchor_maintenance',
        label: 'Anchor/Mooring Maintenance',
        applicableEnvironments: {SiteEnvironment.inSitu},
      );

  static const StructureMaintenanceType buoyReplacement =
      StructureMaintenanceType._(
        id: 'buoy_replacement',
        label: 'Buoy Replacement',
        applicableEnvironments: {SiteEnvironment.inSitu},
      );

  static const List<StructureMaintenanceType> values = [
    // Universal
    rackRepair,
    plugReplacement,
    equipmentMaintenance,
    other,
    // Ex-situ only
    plumbingRepair,
    pumpMaintenance,
    heaterMaintenance,
    lightingMaintenance,
    filterChange,
    // In-situ only
    lineReplacement,
    anchorMaintenance,
    buoyReplacement,
  ];
}

/// An event representing structure maintenance
class StructureMaintenanceEvent extends HusbandryEvent {
  /// Type of maintenance performed
  final String maintenanceTypeId;

  /// Duration of maintenance in minutes
  final int? durationMinutes;

  /// Equipment or structure maintained
  final String? equipmentName;

  /// Whether the issue was resolved
  final bool resolved;

  StructureMaintenanceEvent({
    required super.id,
    required this.maintenanceTypeId,
    this.durationMinutes,
    this.equipmentName,
    this.resolved = true,
    super.imageUrl,
    super.comment,
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
  }) : super(
         eventTypeId: HusbandryEventType.structureMaintenanceId,
       );

  StructureMaintenanceEvent.fromJson(super.json)
    : maintenanceTypeId = json['maintenanceTypeId'] ?? 'other',
      durationMinutes = json['durationMinutes'],
      equipmentName = json['equipmentName'],
      resolved = json['resolved'] ?? true,
      super.fromJson();

  StructureMaintenanceEvent.partial({
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
    super.eventTypeId,
    super.comment,
    super.imageUrl,
    String? maintenanceTypeId,
    int? durationMinutes,
    String? equipmentName,
    bool? resolved,
  }) : maintenanceTypeId =
           maintenanceTypeId ?? json?['maintenanceTypeId'] ?? 'other',
       durationMinutes = durationMinutes ?? json?['durationMinutes'],
       equipmentName = equipmentName ?? json?['equipmentName'],
       resolved = resolved ?? json?['resolved'] ?? true,
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'maintenanceTypeId': maintenanceTypeId,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (equipmentName != null) 'equipmentName': equipmentName,
      'resolved': resolved,
    };
  }

  @override
  bool validate() {
    return super.validate() && maintenanceTypeId.isNotEmpty;
  }

  @override
  StructureMaintenanceEvent copyWith({
    String? id,
    String? maintenanceTypeId,
    int? durationMinutes,
    String? equipmentName,
    bool? resolved,
    String? imageUrl,
    String? comment,
    String? eventTypeId,
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
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return StructureMaintenanceEvent(
      id: id ?? this.id,
      maintenanceTypeId: maintenanceTypeId ?? this.maintenanceTypeId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      equipmentName: equipmentName ?? this.equipmentName,
      resolved: resolved ?? this.resolved,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
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
  List<Object?> get props => [
    ...super.props,
    maintenanceTypeId,
    durationMinutes,
    equipmentName,
    resolved,
  ];

  /// Get the maintenance type
  StructureMaintenanceType get maintenanceType =>
      StructureMaintenanceType.fromId(maintenanceTypeId) ??
      StructureMaintenanceType.other;
}
