// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Event representing splitting an organism record into two records.
///
/// When a split occurs:
/// - The source record's quantity is reduced by [splitQuantity]
/// - A new target record is created with [splitQuantity]
///
/// This event is recorded on the SOURCE organism (the one being split from).
class SplitEvent extends InventoryEvent with CommentEvent {
  SplitEvent({
    required super.id,
    required super.eventTypeId,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.recordModelType,
    required super.snapshot,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
    required this.sourceSnapshotBefore,
    required this.targetOrganismId,
    required this.targetSnapshot,
    required this.splitQuantity,
    required this.sourceQuantityBefore,
    required this.sourceQuantityAfter,
    this.comment,
  });

  SplitEvent.fromJson(super.json)
    : sourceSnapshotBefore = _parseInventorySnapshot(
        json['sourceSnapshotBefore'],
        json,
      ),
      targetOrganismId = json['targetOrganismId'] ?? '',
      targetSnapshot = _parseInventorySnapshot(json['targetSnapshot'], json),
      splitQuantity = safeDouble(json['splitQuantity']) ?? 0.0,
      sourceQuantityBefore = safeDouble(json['sourceQuantityBefore']) ?? 0.0,
      sourceQuantityAfter = safeDouble(json['sourceQuantityAfter']) ?? 0.0,
      comment = CommentEvent.commentFromJson(json),
      super.fromJson();

  static InventoryRecord _parseInventorySnapshot(
    dynamic snapshotData,
    Map<String, dynamic> parentJson,
  ) {
    if (snapshotData is Map<String, dynamic> && snapshotData.isNotEmpty) {
      final normalized = Map<String, dynamic>.from(snapshotData);
      normalized.putIfAbsent(
        'modelType',
        () => parentJson['recordModelType'] ?? ModelType.organismRecord.name,
      );
      normalized.putIfAbsent('organizationId', () => parentJson['organizationId']);
      normalized.putIfAbsent('createdAt', () => parentJson['createdAt']);
      normalized.putIfAbsent(
        'updatedAt',
        () => parentJson['updatedAt'] ?? parentJson['createdAt'],
      );
      normalized.putIfAbsent('createdById', () => parentJson['createdById']);
      normalized.putIfAbsent('updatedById', () => parentJson['updatedById']);
      return RecordFactory.recordFromJson(normalized);
    }
    return SnapshotEvent.snapshotFromJson(parentJson);
  }

  final InventoryRecord sourceSnapshotBefore;
  final String targetOrganismId;
  final InventoryRecord targetSnapshot;
  final double splitQuantity;
  final double sourceQuantityBefore;
  final double sourceQuantityAfter;

  @override
  final String? comment;

  @override
  String get eventTypeId => InventoryEventType.splitId;

  @override
  List<Object?> get props => super.props + [
        sourceSnapshotBefore,
        targetOrganismId,
        targetSnapshot,
        splitQuantity,
        sourceQuantityBefore,
        sourceQuantityAfter,
        comment,
      ];

  @override
  SplitEvent copyWith({
    String? id,
    String? eventTypeId,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    ModelType? recordModelType,
    InventoryRecord? snapshot,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? missionId,
    bool clearMissionId = false,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    InventoryRecord? sourceSnapshotBefore,
    String? targetOrganismId,
    InventoryRecord? targetSnapshot,
    double? splitQuantity,
    double? sourceQuantityBefore,
    double? sourceQuantityAfter,
    String? comment,
  }) {
    return SplitEvent(
      id: id ?? this.id,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      snapshot: snapshot ?? this.snapshot,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
      sourceSnapshotBefore: sourceSnapshotBefore ?? this.sourceSnapshotBefore,
      targetOrganismId: targetOrganismId ?? this.targetOrganismId,
      targetSnapshot: targetSnapshot ?? this.targetSnapshot,
      splitQuantity: splitQuantity ?? this.splitQuantity,
      sourceQuantityBefore: sourceQuantityBefore ?? this.sourceQuantityBefore,
      sourceQuantityAfter: sourceQuantityAfter ?? this.sourceQuantityAfter,
      comment: comment ?? this.comment,
    );
  }

  @override
  bool validate() {
    // Validate quantity invariant: splitQuantity == before - after
    final quantityInvariantValid =
        (sourceQuantityBefore - sourceQuantityAfter - splitQuantity).abs() <
            0.001;

    return super.validate() &&
        targetOrganismId.isNotEmpty &&
        splitQuantity > 0 &&
        sourceQuantityBefore > sourceQuantityAfter &&
        sourceQuantityAfter >= 0 &&
        quantityInvariantValid;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'sourceSnapshotBefore': sourceSnapshotBefore.toJson(),
      'targetOrganismId': targetOrganismId,
      'targetSnapshot': targetSnapshot.toJson(),
      'splitQuantity': splitQuantity,
      'sourceQuantityBefore': sourceQuantityBefore,
      'sourceQuantityAfter': sourceQuantityAfter,
      'comment': comment,
    };
  }
}
