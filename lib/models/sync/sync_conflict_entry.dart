// @tier: community
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/offline_queue.dart';

/// Known conflict reason identifiers produced by the sync pipeline.
///
/// These values are persisted in Firestore and must remain stable.
/// Use [SyncConflictReason.id] when writing reasons, and
/// [SyncConflictReason.fromId] when reading from stored data.
enum SyncConflictReason {
  serverNewerThanOfflineChange('server_newer_than_offline_change'),
  serverNewerThanOfflineQuantityUpdate('server_newer_than_offline_quantity_update'),
  moveConflictServerNewer('move_conflict_server_newer'),
  moveConflictServerNewerPartial('move_conflict_server_newer_partial'),
  snapshotTimestampMissing('snapshot_timestamp_missing');

  const SyncConflictReason(this.id);

  /// Stable string identifier persisted to Firestore.
  final String id;

  /// All known reason IDs as an unmodifiable list for use in filter dropdowns.
  static List<String> get allIds =>
      values.map((r) => r.id).toList(growable: false);

  /// Parses a stored reason string into a [SyncConflictReason], or null if
  /// the value does not match any known reason.
  static SyncConflictReason? fromId(String? id) {
    if (id == null) return null;
    for (final reason in values) {
      if (reason.id == id) return reason;
    }
    return null;
  }
}

/// Captures metadata about an offline replay that could not be applied because
/// a newer server edit already exists (conflict).
class SyncConflictEntry {
  const SyncConflictEntry({
    required this.operationId,
    required this.operationType,
    required this.modelType,
    required this.recordId,
    required this.organizationId,
    required this.queuedAtIso,
    required this.loggedAtIso,
    this.serverUpdatedAtIso,
    this.queuedUpdatedAtIso,
    this.reason,
    this.metadata,
    this.operationData,
    this.parentId,
    this.resolvedById,
    this.resolvedAtIso,
    this.resolutionAction,
    this.resolutionNotes,
  });

  final String operationId;
  final OperationType operationType;
  final ModelType modelType;
  final String recordId;
  final String organizationId;
  final String queuedAtIso;
  final String loggedAtIso;
  final String? serverUpdatedAtIso;
  final String? queuedUpdatedAtIso;
  final String? reason;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? operationData;
  final String? parentId;
  final String? resolvedById;
  final String? resolvedAtIso;
  final String? resolutionAction;
  final String? resolutionNotes;

  DateTime get loggedAt =>
      DateTime.tryParse(loggedAtIso) ?? DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'operationType': operationType.name,
    'modelType': modelType.name,
    'recordId': recordId,
    'organizationId': organizationId,
    'queuedAt': queuedAtIso,
    'loggedAt': loggedAtIso,
    'serverUpdatedAt': serverUpdatedAtIso,
    'queuedUpdatedAt': queuedUpdatedAtIso,
    'reason': reason,
    'metadata': metadata,
    'operationData': operationData,
    'parentId': parentId,
    'resolvedById': resolvedById,
    'resolvedAt': resolvedAtIso,
    'resolutionAction': resolutionAction,
    'resolutionNotes': resolutionNotes,
  };

  factory SyncConflictEntry.fromJson(Map<String, dynamic> json) {
    return SyncConflictEntry(
      operationId: json['operationId'] as String,
      operationType: OperationType.values.firstWhere(
        (value) => value.name == json['operationType'],
      ),
      modelType: ModelType.values.firstWhere(
        (value) => value.name == json['modelType'],
      ),
      recordId: json['recordId'] as String,
      organizationId: json['organizationId'] as String,
      queuedAtIso: json['queuedAt'] as String,
      loggedAtIso: json['loggedAt'] as String,
      serverUpdatedAtIso: json['serverUpdatedAt'] as String?,
      queuedUpdatedAtIso: json['queuedUpdatedAt'] as String?,
      reason: json['reason'] as String?,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
      operationData: json['operationData'] == null
          ? null
          : Map<String, dynamic>.from(json['operationData'] as Map),
      parentId: json['parentId'] as String?,
      resolvedById: json['resolvedById'] as String?,
      resolvedAtIso: json['resolvedAt'] as String?,
      resolutionAction: json['resolutionAction'] as String?,
      resolutionNotes: json['resolutionNotes'] as String?,
    );
  }

  SyncConflictEntry copyWith({
    String? resolvedById,
    String? resolvedAtIso,
    String? resolutionAction,
    String? resolutionNotes,
  }) {
    return SyncConflictEntry(
      operationId: operationId,
      operationType: operationType,
      modelType: modelType,
      recordId: recordId,
      organizationId: organizationId,
      queuedAtIso: queuedAtIso,
      loggedAtIso: loggedAtIso,
      serverUpdatedAtIso: serverUpdatedAtIso,
      queuedUpdatedAtIso: queuedUpdatedAtIso,
      reason: reason,
      metadata: metadata == null ? null : Map<String, dynamic>.from(metadata!),
      operationData:
          operationData == null ? null : Map<String, dynamic>.from(operationData!),
      parentId: parentId,
      resolvedById: resolvedById ?? this.resolvedById,
      resolvedAtIso: resolvedAtIso ?? this.resolvedAtIso,
      resolutionAction: resolutionAction ?? this.resolutionAction,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }
}
