import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Event representing merging multiple organism records into one.
///
/// When a merge occurs:
/// - Multiple source organisms are absorbed into a target organism
/// - The absorbed organisms are marked as deleted/archived
/// - The target organism's quantity increases by the sum of absorbed quantities
///
/// This event is recorded on the TARGET organism (the one absorbing others).
class MergeEvent extends InventoryEvent with CommentEvent {
  MergeEvent({
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
    super.metadata,
    super.base,
    required this.absorbedOrganismIds,
    required this.absorbedSnapshots,
    required this.targetSnapshotBefore,
    required this.totalQuantityBefore,
    required this.totalQuantityAfter,
    this.comment,
  });

  MergeEvent.fromJson(super.json)
    : absorbedOrganismIds = List<String>.from(json['absorbedOrganismIds'] ?? []),
      absorbedSnapshots = _parseAbsorbedSnapshots(json),
      targetSnapshotBefore = _parseInventorySnapshot(
        json['targetSnapshotBefore'],
        json,
      ),
      totalQuantityBefore = safeDouble(json['totalQuantityBefore']) ?? 0.0,
      totalQuantityAfter = safeDouble(json['totalQuantityAfter']) ?? 0.0,
      comment = CommentEvent.commentFromJson(json),
      super.fromJson();

  static List<InventoryRecord> _parseAbsorbedSnapshots(
    Map<String, dynamic> json,
  ) {
    final rawSnapshots = json['absorbedSnapshots'];
    if (rawSnapshots is List) {
      return rawSnapshots
          .whereType<Map<String, dynamic>>()
          .map((snapshotJson) => _parseInventorySnapshot(snapshotJson, json))
          .toList();
    }
    return const [];
  }

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

  final List<String> absorbedOrganismIds;
  final List<InventoryRecord> absorbedSnapshots;
  final InventoryRecord targetSnapshotBefore;
  final double totalQuantityBefore;
  final double totalQuantityAfter;

  @override
  final String? comment;

  @override
  String get eventTypeId => InventoryEventType.mergeId;

  int get absorbedCount => absorbedOrganismIds.length;

  @override
  List<Object?> get props => super.props + [
        absorbedOrganismIds,
        absorbedSnapshots,
        targetSnapshotBefore,
        totalQuantityBefore,
        totalQuantityAfter,
        comment,
      ];

  @override
  MergeEvent copyWith({
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
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    List<String>? absorbedOrganismIds,
    List<InventoryRecord>? absorbedSnapshots,
    InventoryRecord? targetSnapshotBefore,
    double? totalQuantityBefore,
    double? totalQuantityAfter,
    String? comment,
  }) {
    return MergeEvent(
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
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
      absorbedOrganismIds: absorbedOrganismIds ?? this.absorbedOrganismIds,
      absorbedSnapshots: absorbedSnapshots ?? this.absorbedSnapshots,
      targetSnapshotBefore: targetSnapshotBefore ?? this.targetSnapshotBefore,
      totalQuantityBefore: totalQuantityBefore ?? this.totalQuantityBefore,
      totalQuantityAfter: totalQuantityAfter ?? this.totalQuantityAfter,
      comment: comment ?? this.comment,
    );
  }

  @override
  bool validate() {
    return super.validate() &&
        absorbedOrganismIds.isNotEmpty &&
        absorbedSnapshots.length == absorbedOrganismIds.length &&
        totalQuantityAfter >= totalQuantityBefore;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'absorbedOrganismIds': absorbedOrganismIds,
      'absorbedSnapshots': absorbedSnapshots.map((s) => s.toJson()).toList(),
      'targetSnapshotBefore': targetSnapshotBefore.toJson(),
      'totalQuantityBefore': totalQuantityBefore,
      'totalQuantityAfter': totalQuantityAfter,
      'comment': comment,
    };
  }
}
