// @tier: community
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'transfer_manifest_snapshots.dart';
import 'transfer_status.dart';

/// Transfer manifest containing all information needed to verify and complete
/// a transfer between organizations.
///
/// Uses typed snapshot classes ([OrganizationSnapshot], [GenetSnapshot],
/// [UserSnapshot]) instead of raw Map<String, dynamic> to provide type safety
/// and better documentation of the expected data structure.
class TransferManifest {
  static const String currentVersion = '1.0.0';

  TransferManifest({
    required this.transferId,
    required this.generatedAt,
    required this.fromOrganization,
    required this.toOrganization,
    required this.genet,
    required this.quantity,
    this.version = currentVersion,
    this.comment,
    this.sourceStructureUrlPath,
    this.requestedBy,
    this.status = TransferStatus.draft,
    this.shippedAt,
    this.shippedById,
    this.receivedAt,
    this.receivedById,
    this.metadata,
  });

  final String transferId;
  final String version;
  final DateTime generatedAt;

  /// Point-in-time snapshot of the source organization.
  final OrganizationSnapshot fromOrganization;

  /// Point-in-time snapshot of the destination organization.
  /// May be email-only for transfers to unknown organizations.
  final OrganizationSnapshot toOrganization;

  /// Point-in-time snapshot of the genet being transferred.
  final GenetSnapshot genet;

  /// Point-in-time snapshot of the user who requested the transfer.
  final UserSnapshot? requestedBy;

  final int quantity;
  final String? comment;
  final String? sourceStructureUrlPath;
  final TransferStatus status;
  final DateTime? shippedAt;
  final String? shippedById;
  final DateTime? receivedAt;
  final String? receivedById;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'version': version,
        'generatedAt': generatedAt.toIso8601String(),
        'fromOrganization': fromOrganization.toJson(),
        'toOrganization': toOrganization.toJson(),
        'genet': genet.toJson(),
        'requestedBy': requestedBy?.toJson(),
        'quantity': quantity,
        'comment': comment,
        'sourceStructureUrlPath': sourceStructureUrlPath,
        'status': status.value,
        'shippedAt': shippedAt?.toIso8601String(),
        'shippedById': shippedById,
        'receivedAt': receivedAt?.toIso8601String(),
        'receivedById': receivedById,
        'metadata': metadata,
      };

  factory TransferManifest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) {
        return value.toUtc();
      }
      if (value is Timestamp) {
        return value.toDate().toUtc();
      }
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final generatedAt = parseDate(json['generatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return TransferManifest(
      transferId: json['transferId'] as String? ?? '',
      version: json['version'] as String? ?? currentVersion,
      generatedAt: generatedAt,
      fromOrganization: OrganizationSnapshot.fromJson(
        json['fromOrganization'] as Map<String, dynamic>?,
      ),
      toOrganization: OrganizationSnapshot.fromJson(
        json['toOrganization'] as Map<String, dynamic>?,
      ),
      genet: GenetSnapshot.fromJson(
        json['genet'] as Map<String, dynamic>?,
      ),
      requestedBy: json['requestedBy'] is Map
          ? UserSnapshot.fromJson(
              Map<String, dynamic>.from(json['requestedBy'] as Map),
            )
          : null,
      quantity: safeInt(json['quantity']) ?? 0,
      comment: json['comment'] as String?,
      sourceStructureUrlPath: json['sourceStructureUrlPath'] as String?,
      status: parseTransferStatus(json['status'] as String?),
      shippedAt: parseDate(json['shippedAt']),
      shippedById: json['shippedById'] as String?,
      receivedAt: parseDate(json['receivedAt']),
      receivedById: json['receivedById'] as String?,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  TransferManifest copyWith({
    String? transferId,
    String? version,
    DateTime? generatedAt,
    OrganizationSnapshot? fromOrganization,
    OrganizationSnapshot? toOrganization,
    GenetSnapshot? genet,
    UserSnapshot? requestedBy,
    int? quantity,
    String? comment,
    String? sourceStructureUrlPath,
    TransferStatus? status,
    DateTime? shippedAt,
    String? shippedById,
    DateTime? receivedAt,
    String? receivedById,
    Map<String, dynamic>? metadata,
  }) {
    return TransferManifest(
      transferId: transferId ?? this.transferId,
      version: version ?? this.version,
      generatedAt: generatedAt ?? this.generatedAt,
      fromOrganization: fromOrganization ?? this.fromOrganization,
      toOrganization: toOrganization ?? this.toOrganization,
      genet: genet ?? this.genet,
      requestedBy: requestedBy ?? this.requestedBy,
      quantity: quantity ?? this.quantity,
      comment: comment ?? this.comment,
      sourceStructureUrlPath:
          sourceStructureUrlPath ?? this.sourceStructureUrlPath,
      status: status ?? this.status,
      shippedAt: shippedAt ?? this.shippedAt,
      shippedById: shippedById ?? this.shippedById,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedById: receivedById ?? this.receivedById,
      metadata: metadata ?? this.metadata,
    );
  }

  TransferManifest updateStatus(
    TransferStatus status, {
    DateTime? timestamp,
    String? actorId,
  }) {
    final effectiveTimestamp = (timestamp ?? DateTime.now()).toUtc();
    switch (status) {
      case TransferStatus.draft:
      case TransferStatus.pending:
        return copyWith(status: status);
      case TransferStatus.shipped:
        return copyWith(
          status: status,
          shippedAt: effectiveTimestamp,
          shippedById: actorId ?? shippedById,
        );
      case TransferStatus.received:
        return copyWith(
          status: status,
          receivedAt: effectiveTimestamp,
          receivedById: actorId ?? receivedById,
        );
      case TransferStatus.rejected:
      case TransferStatus.cancelled:
        return copyWith(status: status);
    }
  }

  String encodePayload() {
    final jsonString = jsonEncode(toJson());
    return base64UrlEncode(utf8.encode(jsonString));
  }

  static TransferManifest decodePayload(String payload) {
    final decoded = utf8.decode(base64Url.decode(payload));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    return TransferManifest.fromJson(json);
  }

  static String checksumForJson(Map<String, dynamic> json) {
    final data = utf8.encode(jsonEncode(json));
    return sha256.convert(data).toString();
  }

  static String? checksumForPayload(String payload) {
    try {
      final decoded = utf8.decode(base64Url.decode(payload));
      return sha256.convert(utf8.encode(decoded)).toString();
    } catch (_) {
      return null;
    }
  }

  String get checksum {
    return checksumForJson(toJson());
  }
}
