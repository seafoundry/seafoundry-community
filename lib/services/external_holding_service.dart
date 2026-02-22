// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for managing external holding sites (mirror sites showing where
/// organisms are held by other orgs).
///
/// When an organization transfers organisms with "retained ownership", a mirror
/// site is created at the sender's org to track where their organisms are held.
class ExternalHoldingService {
  ExternalHoldingService({
    required FirebaseFirestore db,
    required SiteRepository siteRepository,
  })  : _db = db,
        _siteRepository = siteRepository;

  final FirebaseFirestore _db;
  final SiteRepository _siteRepository;

  /// Sends notification to owner org to create/update external holding mirror site.
  Future<void> notifyOwnerOfExternalHolding({
    required String ownerOrganizationId,
    required String holdingOrganizationId,
    required String holdingOrganizationName,
    required String holdingSiteId,
    required String holdingSiteName,
    required String? holdingGroupPath,
    required String transferId,
  }) async {
    try {
      final notificationRef = _db
          .collection('organizations')
          .doc(ownerOrganizationId)
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'type': ExternalHoldingNotificationType.created.id,
        'transferId': transferId,
        'holdingOrganizationId': holdingOrganizationId,
        'holdingOrganizationName': holdingOrganizationName,
        'holdingSiteId': holdingSiteId,
        'holdingSiteName': holdingSiteName,
        'holdingGroupPath': holdingGroupPath,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      LoggingService.instance.info(
        'Sent external holding notification to $ownerOrganizationId '
        'for transfer $transferId',
      );
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to send external holding notification: $e',
      );
      // Best-effort - don't fail the transfer
    }
  }

  /// Sends notification to owner org to remove external holding entry.
  Future<void> notifyOwnerOfHoldingRemoval({
    required String ownerOrganizationId,
    required String transferId,
  }) async {
    try {
      final notificationRef = _db
          .collection('organizations')
          .doc(ownerOrganizationId)
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'type': ExternalHoldingNotificationType.removed.id,
        'transferId': transferId,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      LoggingService.instance.info(
        'Sent external holding removal notification to $ownerOrganizationId',
      );
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to send external holding removal notification: $e',
      );
    }
  }

  /// Sends notification when custodian moves organisms to different location.
  Future<void> notifyOwnerOfLocationChange({
    required String ownerOrganizationId,
    required String organismRecordId,
    required String newSiteId,
    required String? newGroupId,
    required String newSiteName,
    required String? newGroupPath,
  }) async {
    try {
      final notificationRef = _db
          .collection('organizations')
          .doc(ownerOrganizationId)
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'type': ExternalHoldingNotificationType.locationChanged.id,
        'organismRecordId': organismRecordId,
        'newSiteId': newSiteId,
        'newGroupId': newGroupId,
        'newSiteName': newSiteName,
        'newGroupPath': newGroupPath,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to send location change notification: $e',
      );
    }
  }

  /// Streams external holding sites for the current organization.
  Stream<List<Site>> streamExternalHoldings() {
    return _siteRepository.streamAll.map(
      (sites) => sites.where((site) => site.isExternalHolding).toList(),
    );
  }
}

/// Notification types for external holding operations.
enum ExternalHoldingNotificationType {
  created('externalHoldingCreated'),
  removed('externalHoldingRemoved'),
  locationChanged('externalHoldingLocationChanged');

  const ExternalHoldingNotificationType(this.id);
  final String id;

  static ExternalHoldingNotificationType? fromId(String? id) {
    if (id == null) return null;
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// Result of external holding operation.
class ExternalHoldingResult {
  const ExternalHoldingResult({
    required this.success,
    this.externalHoldingSiteId,
    this.errorMessage,
  });

  final bool success;
  final String? externalHoldingSiteId;
  final String? errorMessage;

  factory ExternalHoldingResult.success(String siteId) =>
      ExternalHoldingResult(success: true, externalHoldingSiteId: siteId);

  factory ExternalHoldingResult.failure(String message) =>
      ExternalHoldingResult(success: false, errorMessage: message);
}

/// Data class for external holding display in UI.
class ExternalHoldingSiteInfo {
  const ExternalHoldingSiteInfo({
    required this.siteId,
    required this.holdingOrganizationId,
    required this.holdingOrganizationName,
    required this.holdingSiteName,
    required this.organismCount,
    required this.lastUpdated,
  });

  final String siteId;
  final String holdingOrganizationId;
  final String holdingOrganizationName;
  final String holdingSiteName;
  final int organismCount;
  final DateTime lastUpdated;
}
