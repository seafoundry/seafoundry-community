import 'package:seafoundry_app/models/inventory/custody_history_entry.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/transfer_manifest.dart';
import 'package:seafoundry_app/models/types/transfer_ownership_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Service for managing custody history on OrganismRecord.
///
/// Provides utilities for:
/// - Creating initial custody entries for new organism records
/// - Appending transfer-based custody entries
/// - Reading custody history from organism records
/// - Including custody history in transfer manifests
class CustodyHistoryService {
  CustodyHistoryService._();

  /// Metadata key for custody history in OrganismRecord.metadata.
  static const String custodyHistoryKey = 'custodyHistory';

  /// Creates the initial custody history entry for a newly created organism.
  ///
  /// This should be called when creating a new OrganismRecord to establish
  /// the initial chain of custody.
  static CustodyHistoryEntry createInitialEntry({
    required Organization organization,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    DateTime? createdAt,
  }) {
    // Default to the creating organization if not specified
    final ownerId = ownerOrganizationId?.trim().isNotEmpty == true
        ? ownerOrganizationId!.trim()
        : organization.id;
    final managerId = managingOrganizationId?.trim().isNotEmpty == true
        ? managingOrganizationId!.trim()
        : organization.id;

    // For the initial entry, owner and manager names are the same org
    // if they are the creating organization
    final ownerName = ownerId == organization.id ? organization.name : null;
    final managerName = managerId == organization.id ? organization.name : null;

    return CustodyHistoryEntry.creation(
      ownerOrganizationId: ownerId,
      ownerOrganizationName: ownerName,
      managingOrganizationId: managerId,
      managingOrganizationName: managerName,
      createdAt: createdAt,
      note: 'Original creation',
    );
  }

  /// Creates a custody history entry for a transfer acceptance.
  ///
  /// Called when an organism is received via transfer to record the new
  /// custody arrangement.
  static CustodyHistoryEntry createTransferEntry({
    required String transferId,
    required TransferOwnershipType ownershipType,
    required String ownerOrganizationId,
    String? ownerOrganizationName,
    required String managingOrganizationId,
    String? managingOrganizationName,
    DateTime? acceptedAt,
    String? note,
  }) {
    final effectiveNote = note ?? _defaultNoteForTransferType(ownershipType);

    return CustodyHistoryEntry.fromTransfer(
      ownerOrganizationId: ownerOrganizationId,
      ownerOrganizationName: ownerOrganizationName,
      managingOrganizationId: managingOrganizationId,
      managingOrganizationName: managingOrganizationName,
      transferId: transferId,
      transferType: ownershipType,
      acceptedAt: acceptedAt,
      note: effectiveNote,
    );
  }

  static String _defaultNoteForTransferType(TransferOwnershipType type) {
    switch (type) {
      case TransferOwnershipType.fullTransfer:
        return 'Full ownership transfer';
      case TransferOwnershipType.retainedOwnership:
        return 'Transferred for management (ownership retained by sender)';
      case TransferOwnershipType.thirdPartyTransfer:
        return 'Third-party transfer';
    }
  }

  /// Reads custody history from an OrganismRecord.
  ///
  /// Returns an empty list if no custody history exists.
  static List<CustodyHistoryEntry> readCustodyHistory(OrganismRecord record) {
    final metadata = record.metadata;
    if (metadata == null) return const [];

    final historyRaw = metadata[custodyHistoryKey];
    if (historyRaw == null) return const [];

    return parseCustodyHistory(historyRaw);
  }

  /// Parses custody history from raw JSON data.
  static List<CustodyHistoryEntry> parseCustodyHistory(dynamic raw) {
    if (raw is! List) return const [];

    final entries = <CustodyHistoryEntry>[];
    for (final item in raw) {
      if (item is Map) {
        entries.add(CustodyHistoryEntry.fromJson(deepNormalizeMap(item)));
      }
    }
    return List<CustodyHistoryEntry>.unmodifiable(entries);
  }

  /// Serializes custody history to JSON for storage in metadata.
  static List<Map<String, dynamic>> serializeCustodyHistory(
    List<CustodyHistoryEntry> history,
  ) {
    return history.map((e) => e.toJson()).toList();
  }

  /// Gets the current custody (most recent entry) from an OrganismRecord.
  static CustodyHistoryEntry? getCurrentCustody(OrganismRecord record) {
    final history = readCustodyHistory(record);
    return history.isEmpty ? null : history.last;
  }

  /// Creates updated metadata with a new custody history entry appended.
  ///
  /// Does not mutate the original metadata; returns a new map.
  static Map<String, dynamic> appendCustodyEntry(
    Map<String, dynamic>? existingMetadata,
    CustodyHistoryEntry newEntry,
  ) {
    final metadata = Map<String, dynamic>.from(existingMetadata ?? const {});
    final existingHistory = parseCustodyHistory(metadata[custodyHistoryKey]);
    final updatedHistory = [...existingHistory, newEntry];
    metadata[custodyHistoryKey] = serializeCustodyHistory(updatedHistory);
    return metadata;
  }

  /// Creates metadata with initial custody history for a new organism.
  ///
  /// Merges with any existing metadata.
  static Map<String, dynamic> createMetadataWithInitialCustody({
    Map<String, dynamic>? existingMetadata,
    required Organization organization,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    DateTime? createdAt,
  }) {
    final initialEntry = createInitialEntry(
      organization: organization,
      ownerOrganizationId: ownerOrganizationId,
      managingOrganizationId: managingOrganizationId,
      createdAt: createdAt,
    );

    return appendCustodyEntry(existingMetadata, initialEntry);
  }

  /// Extracts custody history for inclusion in a transfer manifest.
  ///
  /// Returns a JSON-serializable representation suitable for the manifest's
  /// metadata field.
  static Map<String, dynamic> extractCustodyHistoryForManifest(OrganismRecord record) {
    final history = readCustodyHistory(record);
    if (history.isEmpty) return const {};

    return {
      custodyHistoryKey: serializeCustodyHistory(history),
    };
  }

  /// Creates custody history entry from a transfer manifest.
  ///
  /// Extracts the necessary information from the manifest to create
  /// the receiving organization's custody entry.
  static CustodyHistoryEntry createEntryFromManifest({
    required TransferManifest manifest,
    required String receivingOrganizationId,
    String? receivingOrganizationName,
    String? ownerOrganizationId,
    String? ownerOrganizationName,
  }) {
    // Parse ownership type from manifest metadata
    final ownershipTypeRaw =
        manifest.metadata?['ownershipType']?.toString();
    final ownershipType = TransferOwnershipTypeX.tryParse(ownershipTypeRaw) ??
        TransferOwnershipType.fullTransfer;

    // Determine the effective owner based on ownership type
    String effectiveOwnerId;
    String? effectiveOwnerName;

    switch (ownershipType) {
      case TransferOwnershipType.fullTransfer:
        // Full transfer: receiving org becomes owner
        effectiveOwnerId = ownerOrganizationId ?? receivingOrganizationId;
        effectiveOwnerName = ownerOrganizationName ?? receivingOrganizationName;

      case TransferOwnershipType.retainedOwnership:
        // Retained: sender keeps ownership
        effectiveOwnerId =
            manifest.fromOrganization.id ?? receivingOrganizationId;
        effectiveOwnerName =
            manifest.fromOrganization.name ?? receivingOrganizationName;

      case TransferOwnershipType.thirdPartyTransfer:
        // Third-party: original owner specified in metadata
        effectiveOwnerId = manifest.metadata?['originalOwnerOrganizationId']
                ?.toString() ??
            manifest.fromOrganization.id ??
            receivingOrganizationId;
        effectiveOwnerName = manifest.fromOrganization.name;
    }

    return createTransferEntry(
      transferId: manifest.transferId,
      ownershipType: ownershipType,
      ownerOrganizationId: effectiveOwnerId,
      ownerOrganizationName: effectiveOwnerName,
      managingOrganizationId: receivingOrganizationId,
      managingOrganizationName: receivingOrganizationName,
      acceptedAt: manifest.receivedAt,
    );
  }

  /// Queries whether the given organization has ever had custody of an organism.
  static bool hasOrganizationEverHadCustody(
    OrganismRecord record,
    String organizationId,
  ) {
    final history = readCustodyHistory(record);
    return history.hasEverHadCustody(organizationId);
  }

  /// Queries whether the given organization has ever owned an organism.
  static bool hasOrganizationEverOwned(
    OrganismRecord record,
    String organizationId,
  ) {
    final history = readCustodyHistory(record);
    return history.hasEverOwned(organizationId);
  }

  /// Queries whether the given organization has ever managed an organism.
  static bool hasOrganizationEverManaged(
    OrganismRecord record,
    String organizationId,
  ) {
    final history = readCustodyHistory(record);
    return history.hasEverManaged(organizationId);
  }

  /// Gets all organization IDs that have ever had custody of an organism.
  static Set<String> getAllCustodyOrganizations(OrganismRecord record) {
    final history = readCustodyHistory(record);
    return history.allCustodyIds;
  }
}
