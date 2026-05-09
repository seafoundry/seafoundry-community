// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Event tracking the deletion of a record (site, group, or organism).
///
/// Created as part of cascade deletion to maintain an audit trail.
/// The event is associated with the parent organization (not the deleted record).
class DeletionEvent extends Event {
  /// ID of the record that was deleted
  final String deletedRecordId;

  /// Type of record deleted ('site', 'group', 'organism')
  final String deletedRecordType;

  /// Name of the record that was deleted (for display in activity feed)
  final String deletedRecordName;

  /// Path of the deleted record (for audit trail)
  final String? deletedRecordPath;

  /// Reason for deletion (from predefined list)
  final String reason;

  /// Optional comment providing additional context
  final String? comment;

  /// If this deletion was part of a cascade, the ID of the parent deletion event
  final String? parentDeletionId;

  /// Number of child records also deleted (for summary display)
  final int? cascadeCount;

  DeletionEvent({
    required super.id,
    required this.deletedRecordId,
    required this.deletedRecordType,
    required this.deletedRecordName,
    this.deletedRecordPath,
    required this.reason,
    this.comment,
    this.parentDeletionId,
    this.cascadeCount,
    required super.createdById,
    required super.createdAt,
    required super.recordId,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    super.base,
    required super.recordModelType,
  }) : super(eventTypeId: EventType.delete.id);

  DeletionEvent.fromJson(super.json)
      : deletedRecordId = json['deletedRecordId'] ?? '',
        deletedRecordType = json['deletedRecordType'] ?? '',
        deletedRecordName = json['deletedRecordName'] ?? '',
        deletedRecordPath = json['deletedRecordPath'],
        reason = json['reason'] ?? '',
        comment = json['comment'],
        parentDeletionId = json['parentDeletionId'],
        cascadeCount = json['cascadeCount'],
        super.fromJson();

  DeletionEvent.partial({
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
    String? deletedRecordId,
    String? deletedRecordType,
    String? deletedRecordName,
    String? deletedRecordPath,
    String? reason,
    String? comment,
    String? parentDeletionId,
    int? cascadeCount,
  })  : deletedRecordId = deletedRecordId ?? json?['deletedRecordId'] ?? '',
        deletedRecordType = deletedRecordType ?? json?['deletedRecordType'] ?? '',
        deletedRecordName = deletedRecordName ?? json?['deletedRecordName'] ?? '',
        deletedRecordPath = deletedRecordPath ?? json?['deletedRecordPath'],
        reason = reason ?? json?['reason'] ?? '',
        comment = comment ?? json?['comment'],
        parentDeletionId = parentDeletionId ?? json?['parentDeletionId'],
        cascadeCount = cascadeCount ?? json?['cascadeCount'],
        super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'deletedRecordId': deletedRecordId,
      'deletedRecordType': deletedRecordType,
      'deletedRecordName': deletedRecordName,
      if (deletedRecordPath != null) 'deletedRecordPath': deletedRecordPath,
      'reason': reason,
      if (comment != null) 'comment': comment,
      if (parentDeletionId != null) 'parentDeletionId': parentDeletionId,
      if (cascadeCount != null) 'cascadeCount': cascadeCount,
    };
  }

  /// Whether this deletion was part of a cascade from a parent deletion
  bool get isCascadeChild => parentDeletionId != null;

  /// Whether this deletion triggered child deletions
  bool get hasCascadeChildren => (cascadeCount ?? 0) > 0;

  @override
  DeletionEvent copyWith({
    String? id,
    String? deletedRecordId,
    String? deletedRecordType,
    String? deletedRecordName,
    String? deletedRecordPath,
    String? reason,
    String? comment,
    String? parentDeletionId,
    int? cascadeCount,
    String? eventTypeId,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    ModelType? recordModelType,
    String? urlPath,
    String? internalPath,
    String? slug,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return DeletionEvent(
      id: id ?? this.id,
      deletedRecordId: deletedRecordId ?? this.deletedRecordId,
      deletedRecordType: deletedRecordType ?? this.deletedRecordType,
      deletedRecordName: deletedRecordName ?? this.deletedRecordName,
      deletedRecordPath: deletedRecordPath ?? this.deletedRecordPath,
      reason: reason ?? this.reason,
      comment: comment ?? this.comment,
      parentDeletionId: parentDeletionId ?? this.parentDeletionId,
      cascadeCount: cascadeCount ?? this.cascadeCount,
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
        deletedRecordId,
        deletedRecordType,
        deletedRecordName,
        deletedRecordPath,
        reason,
        comment,
        parentDeletionId,
        cascadeCount,
      ];
}
