import 'package:seafoundry_community/models/genet.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';

/// Result of checking for transfer locks on identity fields.
class TransferLockInfo {
  const TransferLockInfo({
    this.isLocked = false,
    this.sourceOrganizationId,
    this.senderLocalId,
    this.senderRecordName,
    this.transferEventId,
  });

  /// Whether identity fields should be locked due to transfer metadata.
  final bool isLocked;

  /// The organization ID that sent this organism via transfer.
  final String? sourceOrganizationId;

  /// The localID from the sender organization.
  final String? senderLocalId;

  /// The record name from the sender organization.
  final String? senderRecordName;

  /// The transfer event ID that created this linkage.
  final String? transferEventId;

  /// Human-readable reason for the lock.
  String get lockReason {
    if (!isLocked) return '';
    if (sourceOrganizationId != null) {
      return 'This identity is linked to an external organization via transfer. '
          'Editing is disabled to preserve the cross-organizational linkage.';
    }
    return 'Identity editing is disabled due to external associations.';
  }
}

/// Information about external associations that may be affected by identity changes.
class ExternalAssociationInfo {
  const ExternalAssociationInfo({
    required this.hasExternalAssociations,
    this.aliasCount = 0,
    this.clonalId,
    this.accessionNumber,
    this.provenanceId,
    this.sourceOrganizationId,
    this.senderLocalId,
  });

  /// Whether this organism/genet has external associations.
  final bool hasExternalAssociations;

  /// Number of aliases attached.
  final int aliasCount;

  /// Clonal ID if set.
  final String? clonalId;

  /// Accession number if set.
  final String? accessionNumber;

  /// Provenance ID if set.
  final String? provenanceId;

  /// Source organization ID from transfer metadata.
  final String? sourceOrganizationId;

  /// Sender's local ID from transfer metadata.
  final String? senderLocalId;

  // Note: buildWarningMessage() was removed as dead code.
  // The UI builds warnings directly from ExternalAssociationInfo fields
  // for more flexible presentation (e.g., warning chips, inline text).
}

/// Service for managing identity field editing with transfer locks and warnings.
class IdentityEditService {
  const IdentityEditService();

  /// Check if identity fields should be locked due to transfer metadata.
  ///
  /// Returns [TransferLockInfo] with isLocked=true if:
  /// - The genet has transfer metadata linking to an external organization
  /// - The foreignKeys contain a 'sourceGenet' reference
  TransferLockInfo checkTransferLock({
    Genet? genet,
    OrganismRecord? organismRecord,
  }) {
    // Check genet transfer metadata
    if (genet != null) {
      final transferMeta = _extractTransferMetadata(genet.metadata);
      if (transferMeta != null) {
        final fromOrgId = transferMeta['fromOrganizationId']?.toString();
        if (fromOrgId != null && fromOrgId.trim().isNotEmpty) {
          return TransferLockInfo(
            isLocked: true,
            sourceOrganizationId: fromOrgId,
            senderLocalId: transferMeta['senderLocalId']?.toString(),
            senderRecordName: transferMeta['senderRecordName']?.toString(),
            transferEventId: transferMeta['transferEventId']?.toString(),
          );
        }
      }
    }

    // Check organism record foreignKeys for sourceGenet
    if (organismRecord != null) {
      final sourceGenetRef = organismRecord.foreignKeys['sourceGenet'];
      if (sourceGenetRef != null && sourceGenetRef.id.isNotEmpty) {
        final orgId = sourceGenetRef.metadata['organizationId']?.toString();
        return TransferLockInfo(
          isLocked: orgId != null && orgId.isNotEmpty,
          sourceOrganizationId: orgId,
          transferEventId: sourceGenetRef.metadata['transferId']?.toString(),
        );
      }
    }

    return const TransferLockInfo();
  }

  /// Check for external associations that would be affected by identity changes.
  ExternalAssociationInfo checkExternalAssociations({
    Genet? genet,
    OrganismRecord? organismRecord,
  }) {
    String? clonalId;
    String? accessionNumber;
    String? provenanceId;
    String? sourceOrganizationId;
    String? senderLocalId;
    int aliasCount = 0;

    if (genet != null) {
      clonalId = genet.clonalId;
      accessionNumber = genet.accessionNumber;
      provenanceId = genet.provenanceId;
      aliasCount = genet.aliases?.length ?? 0;

      final transferMeta = _extractTransferMetadata(genet.metadata);
      if (transferMeta != null) {
        sourceOrganizationId = transferMeta['fromOrganizationId']?.toString();
        senderLocalId = transferMeta['senderLocalId']?.toString();
      }
    }

    if (organismRecord != null) {
      aliasCount += organismRecord.aliases.length;

      final sourceGenetRef = organismRecord.foreignKeys['sourceGenet'];
      if (sourceGenetRef != null && sourceOrganizationId == null) {
        sourceOrganizationId =
            sourceGenetRef.metadata['organizationId']?.toString();
      }
    }

    final hasExternalAssociations =
        aliasCount > 0 ||
        (clonalId != null && clonalId.trim().isNotEmpty) ||
        (accessionNumber != null && accessionNumber.trim().isNotEmpty) ||
        (sourceOrganizationId != null && sourceOrganizationId.trim().isNotEmpty);

    return ExternalAssociationInfo(
      hasExternalAssociations: hasExternalAssociations,
      aliasCount: aliasCount,
      clonalId: clonalId,
      accessionNumber: accessionNumber,
      provenanceId: provenanceId,
      sourceOrganizationId: sourceOrganizationId,
      senderLocalId: senderLocalId,
    );
  }

  /// Extract transfer metadata from a genet's metadata map.
  Map<String, dynamic>? _extractTransferMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final transferData = metadata['transfer'];
    if (transferData is Map<String, dynamic>) {
      return transferData;
    }
    if (transferData is Map) {
      return Map<String, dynamic>.from(transferData);
    }
    return null;
  }
}
