import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_community/models/events/event.dart';
import 'package:seafoundry_community/models/transfer_manifest.dart';
import 'package:seafoundry_community/models/transfer_status.dart';
import 'package:seafoundry_community/models/types/loan_event_type.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

/// Event representing a genetics transfer between organizations
class TransferEvent extends Event {
  final String? genetRecordId;
  final String? toOrganizationId;
  final String? toOrganizationEmail;
  final String? fromOrganizationId;
  final String? status;
  final String? comment;
  final int quantity;
  final String? sourceUrlPath;
  final String? targetUrlPath;
  final Map<String, dynamic>? manifest;
  final String? manifestVersion;
  final String? manifestChecksum;
  final String? shippedAt;
  final String? shippedById;
  final String? receivedAt;
  final String? receivedById;
  final String? trackingNumber;
  final List<Map<String, dynamic>>? stateHistory;

  TransferEvent({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    required super.recordModelType,
    OutplantGeometry? geometry,
    EventBaseParams base = const EventBaseParams(),
    this.genetRecordId,
    this.toOrganizationId,
    this.toOrganizationEmail,
    this.fromOrganizationId,
    this.status,
    this.comment,
    this.quantity = 0,
    this.sourceUrlPath,
    this.targetUrlPath,
    this.manifest,
    this.manifestVersion,
    this.manifestChecksum,
    this.shippedAt,
    this.shippedById,
    this.receivedAt,
    this.receivedById,
    this.trackingNumber,
    this.stateHistory,
  }) : super(
         eventTypeId: LoanEventType.loanId,
         base: EventBaseParams(
           geometry: base.clearGeometry ? null : base.geometry ?? geometry,
           clearGeometry: base.clearGeometry,
         ),
       );

  TransferEvent.incomplete({required Map<String, dynamic> json})
    : genetRecordId = json['genetRecordId'],
      toOrganizationId = json['toOrganizationId'],
      toOrganizationEmail = json['toOrganizationEmail'] as String?,
      fromOrganizationId = json['fromOrganizationId'],
      status = json['status'],
      comment = json['comment'],
      quantity = safeInt(json['quantity']) ?? 0,
      sourceUrlPath = json['sourceUrlPath'],
      targetUrlPath = json['targetUrlPath'],
      manifest = json['manifest'] is Map
          ? Map<String, dynamic>.from(json['manifest'] as Map)
          : null,
      manifestVersion = json['manifestVersion'] as String?,
      manifestChecksum = json['manifestChecksum'] as String?,
      shippedAt = _timestampToString(json['shippedAt']),
      shippedById = json['shippedById'] as String?,
      receivedAt = _timestampToString(json['receivedAt']),
      receivedById = json['receivedById'] as String?,
      trackingNumber = json['trackingNumber'] as String?,
      stateHistory = (json['stateHistory'] as List?)?.whereType<Map>().map((
        entry,
      ) {
        final normalized = Map<String, dynamic>.from(entry);
        final changedAt = _timestampToString(normalized['changedAt']);
        if (changedAt != null) {
          normalized['changedAt'] = changedAt;
        }
        return normalized;
      }).toList(),
      super.partial(
        json: json,
        base: EventBaseParams(
          geometry: OutplantGeometry.maybeFromJson(json['geometry']),
        ),
      );

  factory TransferEvent.initiate({
    required String id,
    required String genetRecordId,
    required String recordId,
    required String createdById,
    required String createdAt,
    required String updatedAt,
    required String updatedById,
    required String urlPath,
    required String internalPath,
    required String slug,
    required String organizationId,
    String? toOrganizationId,
    String? toOrganizationEmail,
    String? sourceStructureUrlPath,
    int quantity = 0,
    String? comment,
    Map<String, dynamic>? metadata,
    OutplantGeometry? geometry,
  }) {
    final history = [
      {
        'status': TransferStatus.draft.value,
        'changedAt': updatedAt,
        'changedById': updatedById,
      },
    ];
    return TransferEvent(
      id: id,
      createdById: createdById,
      createdAt: createdAt,
      updatedAt: updatedAt,
      updatedById: updatedById,
      organizationId: organizationId,
      recordId: recordId,
      recordModelType: ModelType.genet,
      urlPath: urlPath,
      internalPath: internalPath,
      slug: slug,
      genetRecordId: genetRecordId,
      fromOrganizationId: organizationId,
      toOrganizationId: toOrganizationId,
      toOrganizationEmail: toOrganizationEmail,
      status: TransferStatus.draft.value,
      comment: comment,
      quantity: quantity,
      sourceUrlPath: sourceStructureUrlPath,
      targetUrlPath: toOrganizationId,
      stateHistory: history,
      manifestVersion: TransferManifest.currentVersion,
      metadata: metadata,
      geometry: geometry,
    );
  }

  factory TransferEvent.complete({
    required String id,
    required String genetRecordId,
    required String recordId,
    required String createdById,
    required String createdAt,
    required String updatedAt,
    required String updatedById,
    required String urlPath,
    required String internalPath,
    required String slug,
    required String organizationId,
    String? fromOrganizationId,
    int quantity = 0,
    String? comment,
    Map<String, dynamic>? metadata,
  }) {
    return TransferEvent(
      id: id,
      createdById: createdById,
      createdAt: createdAt,
      updatedAt: updatedAt,
      updatedById: updatedById,
      organizationId: organizationId,
      recordId: recordId,
      recordModelType: ModelType.genet,
      urlPath: urlPath,
      internalPath: internalPath,
      slug: slug,
      genetRecordId: genetRecordId,
      fromOrganizationId: fromOrganizationId,
      toOrganizationId: organizationId,
      toOrganizationEmail: null,
      status: TransferStatus.received.value,
      comment: comment,
      quantity: quantity,
      targetUrlPath: organizationId,
      stateHistory: [
        {
          'status': TransferStatus.received.value,
          'changedAt': updatedAt,
          'changedById': updatedById,
        },
      ],
      manifestVersion: TransferManifest.currentVersion,
      metadata: metadata,
    );
  }

  TransferEvent.fromJson(super.json)
    : genetRecordId = json['genetRecordId'],
      toOrganizationId = json['toOrganizationId'],
      toOrganizationEmail = json['toOrganizationEmail'] as String?,
      fromOrganizationId = json['fromOrganizationId'],
      status = json['status'],
      comment = json['comment'],
      quantity = safeInt(json['quantity']) ?? 0,
      sourceUrlPath = json['sourceUrlPath'],
      targetUrlPath = json['targetUrlPath'],
      manifest = json['manifest'] is Map
          ? Map<String, dynamic>.from(json['manifest'] as Map)
          : null,
      manifestVersion = json['manifestVersion'] as String?,
      manifestChecksum = json['manifestChecksum'] as String?,
      shippedAt = _timestampToString(json['shippedAt']),
      shippedById = json['shippedById'] as String?,
      receivedAt = _timestampToString(json['receivedAt']),
      receivedById = json['receivedById'] as String?,
      trackingNumber = json['trackingNumber'] as String?,
      stateHistory = (json['stateHistory'] as List?)?.whereType<Map>().map((
        entry,
      ) {
        final normalized = Map<String, dynamic>.from(entry);
        final changedAt = _timestampToString(normalized['changedAt']);
        if (changedAt != null) {
          normalized['changedAt'] = changedAt;
        }
        return normalized;
      }).toList(),
      super.fromJson();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'genetRecordId': genetRecordId,
      'toOrganizationId': toOrganizationId,
      'toOrganizationEmail': toOrganizationEmail,
      'fromOrganizationId': fromOrganizationId,
      'status': status,
      'comment': comment,
      'quantity': quantity,
      'sourceUrlPath': sourceUrlPath,
      'targetUrlPath': targetUrlPath,
      'manifest': manifest,
      'manifestVersion': manifestVersion,
      'manifestChecksum': manifestChecksum,
      'shippedAt': shippedAt,
      'shippedById': shippedById,
      'receivedAt': receivedAt,
      'receivedById': receivedById,
      'trackingNumber': trackingNumber,
      'stateHistory': stateHistory,
    };
  }

  @override
  bool validate() {
    // A valid transfer requires:
    // 1. Base event validation (required fields not missing)
    // 2. A genetRecordId (what is being transferred)
    // 3. A recipient: either toOrganizationId (direct) or toOrganizationEmail (email-based)
    return super.validate() &&
        genetRecordId != null &&
        (toOrganizationId != null || toOrganizationEmail != null);
  }

  @override
  TransferEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? eventTypeId,
    String? recordId,
    String? urlPath,
    String? internalPath,
    String? slug,
    ModelType? recordModelType,
    String? genetRecordId,
    String? toOrganizationId,
    String? toOrganizationEmail,
    String? fromOrganizationId,
    String? status,
    String? comment,
    int? quantity,
    String? sourceUrlPath,
    String? targetUrlPath,
    Map<String, dynamic>? manifest,
    String? manifestVersion,
    String? manifestChecksum,
    String? shippedAt,
    String? shippedById,
    String? receivedAt,
    String? receivedById,
    String? trackingNumber,
    List<Map<String, dynamic>>? stateHistory,
    Map<String, dynamic>? metadata,
    OutplantGeometry? geometry,
  }) {
    return TransferEvent(
      id: id ?? this.id,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      recordId: recordId ?? this.recordId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        geometry: geometry,
      ),

      recordModelType: recordModelType ?? this.recordModelType,
      genetRecordId: genetRecordId ?? this.genetRecordId,
      toOrganizationId: toOrganizationId ?? this.toOrganizationId,
      toOrganizationEmail: toOrganizationEmail ?? this.toOrganizationEmail,
      fromOrganizationId: fromOrganizationId ?? this.fromOrganizationId,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      quantity: quantity ?? this.quantity,
      sourceUrlPath: sourceUrlPath ?? this.sourceUrlPath,
      targetUrlPath: targetUrlPath ?? this.targetUrlPath,
      manifest: manifest ?? this.manifest,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      manifestChecksum: manifestChecksum ?? this.manifestChecksum,
      shippedAt: shippedAt ?? this.shippedAt,
      shippedById: shippedById ?? this.shippedById,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedById: receivedById ?? this.receivedById,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      stateHistory: stateHistory ?? this.stateHistory,
    );
  }
}

String? _timestampToString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}
