// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/gene_bank_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// An event representing a gene bank audit
///
/// Audits track routine inspections of gene bank storage structures,
/// verifying inventory counts, storage conditions, and record accuracy.
class GeneBankAuditEvent extends HusbandryEvent {
  /// Type of audit performed (e.g., "routine", "comprehensive", "spot_check")
  final String auditType;

  /// Number of items verified during audit
  final int? itemsVerified;

  /// Whether any discrepancies were found
  final bool hasDiscrepancies;

  /// Description of any discrepancies found
  final String? discrepancyNotes;

  GeneBankAuditEvent({
    required super.id,
    required this.auditType,
    this.itemsVerified,
    this.hasDiscrepancies = false,
    this.discrepancyNotes,
    super.comment,
    super.imageUrl,
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
  }) : super(eventTypeId: GeneBankEventType.auditId);

  GeneBankAuditEvent.fromJson(super.json)
    : auditType = json['auditType'] ?? 'routine',
      itemsVerified = safeInt(json['itemsVerified']),
      hasDiscrepancies = json['hasDiscrepancies'] == true,
      discrepancyNotes = json['discrepancyNotes'],
      super.fromJson();

  GeneBankAuditEvent.partial({
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
    String? auditType,
    int? itemsVerified,
    bool? hasDiscrepancies,
    String? discrepancyNotes,
  }) : auditType = auditType ?? json?['auditType'] ?? 'routine',
       itemsVerified = itemsVerified ?? safeInt(json?['itemsVerified']),
       hasDiscrepancies = hasDiscrepancies ?? json?['hasDiscrepancies'] == true,
       discrepancyNotes = discrepancyNotes ?? json?['discrepancyNotes'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'auditType': auditType,
      if (itemsVerified != null) 'itemsVerified': itemsVerified,
      'hasDiscrepancies': hasDiscrepancies,
      if (discrepancyNotes != null) 'discrepancyNotes': discrepancyNotes,
    };
  }

  @override
  bool validate() {
    return super.validate() && auditType.isNotEmpty;
  }

  @override
  GeneBankAuditEvent copyWith({
    String? id,
    String? auditType,
    int? itemsVerified,
    bool? hasDiscrepancies,
    String? discrepancyNotes,
    String? comment,
    String? imageUrl,
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
    return GeneBankAuditEvent(
      id: id ?? this.id,
      auditType: auditType ?? this.auditType,
      itemsVerified: itemsVerified ?? this.itemsVerified,
      hasDiscrepancies: hasDiscrepancies ?? this.hasDiscrepancies,
      discrepancyNotes: discrepancyNotes ?? this.discrepancyNotes,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
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
  List<Object?> get props =>
      super.props +
      [auditType, itemsVerified, hasDiscrepancies, discrepancyNotes];
}
