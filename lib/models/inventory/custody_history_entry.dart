import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/transfer_ownership_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Represents a single entry in an organism's chain of custody history.
///
/// The custody history tracks ownership and management changes over the
/// lifecycle of an organism record. Each entry captures:
/// - Who owned the organism during this period
/// - Who was managing (physically holding) the organism
/// - When this custody period started
/// - The transfer that initiated this change (if applicable)
/// - The type of ownership arrangement
///
/// The history is append-only and provides a complete audit trail for
/// provenance tracking.
class CustodyHistoryEntry extends Equatable {
  const CustodyHistoryEntry({
    required this.ownerOrganizationId,
    this.ownerOrganizationName,
    required this.managingOrganizationId,
    this.managingOrganizationName,
    required this.startedAt,
    this.transferId,
    this.transferType,
    this.note,
  });

  /// The organization that owns the organism during this custody period.
  final String ownerOrganizationId;

  /// Human-readable name of the owner organization (snapshot at time of entry).
  final String? ownerOrganizationName;

  /// The organization physically managing/holding the organism.
  /// May differ from owner in retained ownership or third-party transfers.
  final String managingOrganizationId;

  /// Human-readable name of the managing organization (snapshot at time of entry).
  final String? managingOrganizationName;

  /// When this custody period began.
  final DateTime startedAt;

  /// The transfer event ID that initiated this custody change.
  /// Null for the original creation entry.
  final String? transferId;

  /// The type of transfer that caused this custody change.
  /// Null for original creation. Uses [TransferOwnershipType.id] values.
  final String? transferType;

  /// Optional note about this custody entry (e.g., "Original creation",
  /// "Transferred for research purposes").
  final String? note;

  /// Whether this is the original creation entry (no transfer).
  bool get isOriginalCreation => transferId == null;

  /// Parses the [transferType] string to a [TransferOwnershipType] enum.
  /// Returns null for original creation entries or unrecognized types.
  TransferOwnershipType? get transferOwnershipType {
    if (transferType == null) return null;
    return TransferOwnershipTypeX.tryParse(transferType);
  }

  factory CustodyHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now().toUtc();
      if (value is DateTime) return value.toUtc();
      if (value is Timestamp) return value.toDate().toUtc();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
      }
      return DateTime.now().toUtc();
    }

    final normalized = deepNormalizeMap(json);

    return CustodyHistoryEntry(
      ownerOrganizationId:
          normalized['ownerOrganizationId']?.toString() ?? '',
      ownerOrganizationName:
          normalized['ownerOrganizationName']?.toString(),
      managingOrganizationId:
          normalized['managingOrganizationId']?.toString() ?? '',
      managingOrganizationName:
          normalized['managingOrganizationName']?.toString(),
      startedAt: parseTimestamp(normalized['startedAt']),
      transferId: normalized['transferId']?.toString(),
      transferType: normalized['transferType']?.toString(),
      note: normalized['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'ownerOrganizationId': ownerOrganizationId,
      'managingOrganizationId': managingOrganizationId,
      'startedAt': startedAt.toIso8601String(),
    };

    if (ownerOrganizationName != null) {
      json['ownerOrganizationName'] = ownerOrganizationName;
    }
    if (managingOrganizationName != null) {
      json['managingOrganizationName'] = managingOrganizationName;
    }
    if (transferId != null) {
      json['transferId'] = transferId;
    }
    if (transferType != null) {
      json['transferType'] = transferType;
    }
    if (note != null) {
      json['note'] = note;
    }

    return json;
  }

  CustodyHistoryEntry copyWith({
    String? ownerOrganizationId,
    String? ownerOrganizationName,
    String? managingOrganizationId,
    String? managingOrganizationName,
    DateTime? startedAt,
    String? transferId,
    String? transferType,
    String? note,
  }) {
    return CustodyHistoryEntry(
      ownerOrganizationId: ownerOrganizationId ?? this.ownerOrganizationId,
      ownerOrganizationName:
          ownerOrganizationName ?? this.ownerOrganizationName,
      managingOrganizationId:
          managingOrganizationId ?? this.managingOrganizationId,
      managingOrganizationName:
          managingOrganizationName ?? this.managingOrganizationName,
      startedAt: startedAt ?? this.startedAt,
      transferId: transferId ?? this.transferId,
      transferType: transferType ?? this.transferType,
      note: note ?? this.note,
    );
  }

  /// Creates an entry for the original creation of an organism record.
  factory CustodyHistoryEntry.creation({
    required String ownerOrganizationId,
    String? ownerOrganizationName,
    required String managingOrganizationId,
    String? managingOrganizationName,
    DateTime? createdAt,
    String? note,
  }) {
    return CustodyHistoryEntry(
      ownerOrganizationId: ownerOrganizationId,
      ownerOrganizationName: ownerOrganizationName,
      managingOrganizationId: managingOrganizationId,
      managingOrganizationName: managingOrganizationName,
      startedAt: createdAt ?? DateTime.now().toUtc(),
      transferId: null,
      transferType: null,
      note: note ?? 'Original creation',
    );
  }

  /// Creates an entry for a custody change due to transfer acceptance.
  factory CustodyHistoryEntry.fromTransfer({
    required String ownerOrganizationId,
    String? ownerOrganizationName,
    required String managingOrganizationId,
    String? managingOrganizationName,
    required String transferId,
    required TransferOwnershipType transferType,
    DateTime? acceptedAt,
    String? note,
  }) {
    return CustodyHistoryEntry(
      ownerOrganizationId: ownerOrganizationId,
      ownerOrganizationName: ownerOrganizationName,
      managingOrganizationId: managingOrganizationId,
      managingOrganizationName: managingOrganizationName,
      startedAt: acceptedAt ?? DateTime.now().toUtc(),
      transferId: transferId,
      transferType: transferType.id,
      note: note,
    );
  }

  @override
  List<Object?> get props => [
        ownerOrganizationId,
        ownerOrganizationName,
        managingOrganizationId,
        managingOrganizationName,
        startedAt,
        transferId,
        transferType,
        note,
      ];
}

/// Extension methods for parsing and managing custody history on OrganismRecord.
extension CustodyHistoryExtension on List<CustodyHistoryEntry> {
  /// Returns the most recent (current) custody entry.
  CustodyHistoryEntry? get current => isEmpty ? null : last;

  /// Returns all organization IDs that have ever owned this organism.
  Set<String> get allOwnerIds =>
      map((e) => e.ownerOrganizationId).toSet();

  /// Returns all organization IDs that have ever managed this organism.
  Set<String> get allManagerIds =>
      map((e) => e.managingOrganizationId).toSet();

  /// Returns all organization IDs that have ever had custody (owner or manager).
  Set<String> get allCustodyIds =>
      {...allOwnerIds, ...allManagerIds};

  /// Checks if the given organization has ever owned this organism.
  bool hasEverOwned(String organizationId) =>
      any((e) => e.ownerOrganizationId == organizationId);

  /// Checks if the given organization has ever managed this organism.
  bool hasEverManaged(String organizationId) =>
      any((e) => e.managingOrganizationId == organizationId);

  /// Checks if the given organization has ever had custody (owner or manager).
  bool hasEverHadCustody(String organizationId) =>
      hasEverOwned(organizationId) || hasEverManaged(organizationId);
}
