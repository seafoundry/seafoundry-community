// @tier: community
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/holdings/holding_constructor_helper.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/inventory/holding_record.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Holding for urchin (echinoid) batches held in tanks, trays, or raceways.
/// 
/// Urchins are typically raised in flow-through or recirculating systems.
/// Key fields include tank identifier, test diameter (size), and stocking date.
class UrchinTankHolding extends HoldingRecord {
  factory UrchinTankHolding({
    required String id,
    required String recordName,
    String? localId,
    required OrganismKind organismKind,
    required PopulationMeasurement measurement,
    String? provenanceId,
    String? cohortId,
    String? siteId,
    String? groupId,
    String? structureId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    Map<String, ForeignKeyReference>? foreignKeys,
    HoldingAttributes? attributes,
    String? tankIdentifier,
    double? averageTestDiameterMm,
    DateTime? stockedAt,
    Map<String, dynamic>? metadata,
    OrganismRecord? organismRecord,
    LifeStage? organismLifeStage,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
  }) {
    final defaults = HoldingConstructorHelper.prepare(
      organismKind: organismKind,
      measurement: measurement,
      recordName: recordName,
      localId: localId,
      requestedLifeStage: organismLifeStage,
      fallbackLifeStage: LifeStage.juvenile,
      fallbackPhysicalForm: const PhysicalFormInstance(
        formId: 'batch',
        sizeBandId: 'medium',
      ),
      metadata: metadata,
      organismRecord: organismRecord,
      attributes: attributes,
    );
    return UrchinTankHolding._(
      id: id,
      recordName: recordName,
      organismKind: organismKind,
      measurement: measurement,
      provenanceId: provenanceId,
      cohortId: cohortId,
      siteId: siteId,
      groupId: groupId,
      structureId: structureId,
      ownerOrganizationId: ownerOrganizationId,
      managingOrganizationId: managingOrganizationId,
      foreignKeys: foreignKeys,
      attributes: attributes,
      tankIdentifier: tankIdentifier,
      averageTestDiameterMm: averageTestDiameterMm,
      stockedAt: stockedAt,
      metadata: defaults.metadata,
      organismRecord: defaults.organismRecord,
      lifeStage: defaults.lifeStage,
      createdAt: createdAt,
      createdById: createdById,
      updatedAt: updatedAt,
      updatedById: updatedById,
      organizationId: organizationId,
      urlPath: urlPath,
      internalPath: internalPath,
      slug: slug,
    );
  }

  UrchinTankHolding._({
    required super.id,
    required super.recordName,
    required super.organismKind,
    required super.measurement,
    super.provenanceId,
    super.cohortId,
    super.siteId,
    super.groupId,
    super.structureId,
    super.ownerOrganizationId,
    super.managingOrganizationId,
    super.foreignKeys,
    super.attributes,
    this.tankIdentifier,
    this.averageTestDiameterMm,
    this.stockedAt,
    required super.metadata,
    required OrganismRecord super.organismRecord,
    required super.lifeStage,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.urlPath,
    super.internalPath,
    super.slug,
  });

  /// Optional tank or tray identifier (e.g., "Tank A3", "Tray 12")
  final String? tankIdentifier;
  
  /// Average test diameter in mm (primary size metric for urchins)
  final double? averageTestDiameterMm;
  
  /// Date when urchins were stocked into this tank
  final DateTime? stockedAt;

  @override
  UrchinTankHolding copyWith({
    String? id,
    String? recordName,
    String? localId,
    OrganismKind? organismKind,
    LifeStage? lifeStage,
    PopulationMeasurement? measurement,
    String? provenanceId,
    String? cohortId,
    String? siteId,
    String? groupId,
    String? structureId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    Map<String, ForeignKeyReference>? foreignKeys,
    HoldingAttributes? attributes,
    Map<String, dynamic>? metadata,
    OrganismRecord? organismRecord,
    String? tankIdentifier,
    double? averageTestDiameterMm,
    DateTime? stockedAt,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
  }) {
    final defaults = HoldingConstructorHelper.prepare(
      organismKind: organismKind ?? this.organismKind,
      measurement: measurement ?? this.measurement,
      recordName: recordName ?? this.recordName,
      localId: localId,
      requestedLifeStage: lifeStage ?? this.lifeStage,
      fallbackLifeStage: LifeStage.juvenile,
      fallbackPhysicalForm: const PhysicalFormInstance(
        formId: 'batch',
        sizeBandId: 'medium',
      ),
      metadata: metadata ?? this.metadata,
      organismRecord: organismRecord ?? this.organismRecord,
      attributes: attributes ?? this.attributes,
    );
    return UrchinTankHolding._(
      id: id ?? this.id,
      recordName: recordName ?? this.recordName,
      organismKind: organismKind ?? this.organismKind,
      measurement: measurement ?? this.measurement,
      provenanceId: provenanceId ?? this.provenanceId,
      cohortId: cohortId ?? this.cohortId,
      siteId: siteId ?? this.siteId,
      groupId: groupId ?? this.groupId,
      structureId: structureId ?? this.structureId,
      ownerOrganizationId: ownerOrganizationId ?? this.ownerOrganizationId,
      managingOrganizationId:
          managingOrganizationId ?? this.managingOrganizationId,
      foreignKeys: foreignKeys ?? this.foreignKeys,
      attributes: attributes ?? this.attributes,
      tankIdentifier: tankIdentifier ?? this.tankIdentifier,
      averageTestDiameterMm:
          averageTestDiameterMm ?? this.averageTestDiameterMm,
      stockedAt: stockedAt ?? this.stockedAt,
      metadata: defaults.metadata,
      organismRecord: defaults.organismRecord,
      lifeStage: defaults.lifeStage,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (tankIdentifier != null) {
      json['tankIdentifier'] = tankIdentifier;
    }
    if (averageTestDiameterMm != null) {
      json['averageTestDiameterMm'] = averageTestDiameterMm;
    }
    if (stockedAt != null) {
      json['stockedAt'] = stockedAt!.toIso8601String();
    }
    return json;
  }

  factory UrchinTankHolding.fromJson(Map<String, dynamic> json) {
    final base = HoldingRecord.fromJson(json);
    return UrchinTankHolding(
      id: base.id,
      recordName: base.recordName,
      organismKind: base.organismKind,
      measurement: base.measurement,
      provenanceId: base.provenanceId,
      cohortId: base.cohortId,
      siteId: base.siteId,
      groupId: base.groupId,
      structureId: base.structureId,
      ownerOrganizationId: base.ownerOrganizationId,
      managingOrganizationId: base.managingOrganizationId,
      foreignKeys: base.foreignKeys,
      attributes: base.attributes,
      metadata: base.metadata,
      organismRecord: base.organismRecord,
      organismLifeStage: base.lifeStage,
      tankIdentifier: json['tankIdentifier'] as String?,
      averageTestDiameterMm: safeDouble(json['averageTestDiameterMm']),
      stockedAt: _parseDate(json['stockedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
