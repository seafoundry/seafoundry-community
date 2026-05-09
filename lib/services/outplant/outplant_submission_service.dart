import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service responsible for creating outplant events with atomic batch writes.
///
/// Extracted from OutplantBatchBloc to separate submission logic from UI state management.
/// Handles:
/// - Event creation with allocations
/// - Inventory deduction via population updates
/// - Outplant tag updates on organisms
/// - Atomic batch write coordination
class OutplantSubmissionService {
  OutplantSubmissionService({
    required EventRepository eventRepository,
    required OrganismRecordRepository organismRecordRepository,
    LoggingService? loggingService,
  }) : _eventRepository = eventRepository,
       _organismRepository = organismRecordRepository,
       _logger = loggingService ?? LoggingService.instance;

  final EventRepository _eventRepository;
  final OrganismRecordRepository _organismRepository;
  final LoggingService _logger;

  // Firestore batch write limits and safety margins.
  // Firestore has a hard limit of 500 writes per batch.
  // We use 450 (90%) as a safety threshold to account for any edge cases.
  static const int _safeWriteThreshold = 450;

  /// Estimated max organisms: (450 - 2 base writes) / 2 writes per organism ≈ 224
  /// We advertise ~220 to users for a conservative estimate.
  static const int _estimatedMaxOrganismsPerBatch = 220;

  /// Create an outplant event with all allocations.
  ///
  /// This method performs atomic batch writes to ensure data consistency.
  /// If any write fails, all changes are rolled back.
  ///
  /// Parameters:
  /// - [site]: Target outplant site
  /// - [eventName]: Name for the outplant event
  /// - [selectedOrganisms]: List of organisms to outplant with quantities
  /// - [deductFromInventory]: Whether to reduce organism population counts
  /// - [organizationId]: Organization ID (unused, kept for API compatibility)
  /// - [userId]: User ID (unused, kept for API compatibility)
  /// - [geometry]: Optional geometry data for the outplant
  /// - [healthStatus]: Optional health status observation
  /// - [percentCover]: Optional percent cover measurement
  /// - [percentBleaching]: Optional percent bleaching measurement
  /// - [percentDisease]: Optional percent disease measurement
  /// - [comment]: Optional comment/notes
  /// - [attachmentUrls]: Optional attachment URLs (unused, kept for API compatibility)
  /// - [permitMetadata]: Optional permit metadata
  ///
  /// Returns [OutplantSubmissionResult] with created event and affected organisms.
  ///
  /// Throws [OutplantSubmissionException] if validation fails or batch commit fails.
  Future<OutplantSubmissionResult> createOutplantEvent({
    required Site site,
    required String eventName,
    required List<OutplantSelectedOrganism> selectedOrganisms,
    required bool deductFromInventory,
    required String organizationId,
    required String userId,
    OutplantGeometry? geometry,
    HealthStatus? healthStatus,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    String? comment,
    List<String>? attachmentUrls,
    EventPermitMetadata? permitMetadata,
  }) async {
    // Validation
    final trimmedEventName = eventName.trim();
    if (trimmedEventName.isEmpty) {
      throw const OutplantSubmissionException('Provide an event name.');
    }

    if (selectedOrganisms.isEmpty) {
      throw const OutplantSubmissionException(
        'Select at least one organism to outplant.',
      );
    }

    // Pre-flight batch size validation
    final estimatedWrites = _estimateBatchSize(
      selectedOrganisms,
      deductFromInventory: deductFromInventory,
      hasGeometry: geometry != null,
    );
    if (estimatedWrites > _safeWriteThreshold) {
      throw OutplantSubmissionException(
        'Too many organisms selected ($estimatedWrites writes needed). '
        'Maximum is ~$_estimatedMaxOrganismsPerBatch organisms per outplant. '
        'Please reduce the selection and try again.',
      );
    }

    // Ensure unique event name
    final uniqueEventName = await _eventRepository.ensureUniqueOutplantName(
      trimmedEventName,
    );

    // Build allocations
    final allocations = <OutplantAllocation>[];
    final allocationTags = <String>{};
    for (final item in selectedOrganisms) {
      final maxQuantity = item.quantity;
      if (maxQuantity <= 0) continue;

      if (item.tag != null && item.tag!.isNotEmpty) {
        allocationTags.add(item.tag!);
      }

      final rawName = item.tagId?.trim();
      final allocationName =
          rawName != null && rawName.isNotEmpty ? rawName : item.organismId;
      allocations.add(
        OutplantAllocation(
          organismId: item.organismId,
          tagId: allocationName,
          speciesId: item.speciesId ?? '',
          genetRecordId: item.genetRecordId,
          outplantTagId: item.tag,
          groupId: item.groupId,
          groupName: item.groupName,
          groupPath: item.groupPath,
          quantity: maxQuantity,
          sourcePath: item.sourcePath ?? '',
          snapshot: item.snapshot ?? {},
        ),
      );
    }

    final eventTagPrefix = resolveEventTagPrefix(
      eventName: uniqueEventName,
      site: site,
      date: DateTime.now(),
    );

    // ============ ATOMIC TRANSACTION BLOCK ============
    // All critical writes happen within a single WriteBatch.
    // If any write fails, none are committed (atomic guarantee).
    final batch = _organismRepository.db.batch();

    var outplantEvent = await _eventRepository.createOutplantEvent(
      name: uniqueEventName,
      site: site,
      allocations: allocations,
      percentCover: percentCover,
      percentBleaching: percentBleaching,
      percentDisease: percentDisease,
      healthStatus: healthStatus?.id,
      comment: comment?.trim().isEmpty ?? true ? null : comment!.trim(),
      geometry: geometry,
      permitMetadata: permitMetadata ?? const EventPermitMetadata.empty(),
      batch: batch,
    );

    // Add geometry update to batch if applicable
    if (geometry != null) {
      outplantEvent = await _eventRepository.updateOutplantGeometry(
        event: outplantEvent,
        geometry: geometry,
        batch: batch,
      );
    }

    // Add population updates to batch if deducting from inventory
    final affectedOrganismIds = <String>[];
    if (deductFromInventory) {
      for (final item in selectedOrganisms) {
        final currentQuantity = item.currentQuantity ?? item.quantity;
        if (currentQuantity <= 1) continue;

        final clamped = item.quantity.clamp(1, currentQuantity);
        if (clamped <= 0) continue;

        final updatedQuantity = (currentQuantity - clamped).clamp(0, 100000);

        // Fetch organism to update
        final organism = await _organismRepository.getRecordForId(
          item.organismId,
        );
        if (organism == null) {
          _logger.warning(
            'Cannot deduct inventory for organism ${item.organismId}: record not found',
          );
          continue;
        }

        await _organismRepository.updatePopulation(
          organism,
          updatedQuantity,
          lossReason: PopulationLossReason.outplanted,
          comment: 'Outplanted $clamped to ${site.name}',
          batch: batch,
        );

        affectedOrganismIds.add(item.organismId);
      }
    }

    // Commit all writes atomically
    try {
      await batch.commit();
    } catch (error, stackTrace) {
      _logger.error(
        'Atomic batch commit failed - no outplant data was saved',
        error,
        stackTrace,
      );
      throw const OutplantSubmissionException(
        'Failed to save outplant event. No data was written. Please try again.',
      );
    }
    // ============ END ATOMIC TRANSACTION BLOCK ============

    // ============ POST-COMMIT BEST-EFFORT OPERATIONS ============
    // These operations happen after the atomic commit. Failures here
    // won't affect the core outplant data integrity.
    try {
      await _updateOutplantTags(
        allocations: allocations,
        eventTagPrefix: eventTagPrefix,
        existingTag: allocationTags.length == 1 ? allocationTags.first : null,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to update tags for outplant ${outplantEvent.id}',
        error,
        stackTrace,
      );
      // Non-fatal: continue with remaining operations
    }

    _logger.info(
      'Created outplant event ${outplantEvent.id} (${outplantEvent.name}) for site ${site.name}',
    );

    return OutplantSubmissionResult(
      event: outplantEvent,
      affectedOrganismIds: affectedOrganismIds,
      success: true,
    );
  }

  /// Generate default event name from date and site.
  String generateDefaultEventName(DateTime date, Site? site) {
    final formattedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (site != null && site.name.isNotEmpty) {
      return '${site.name} Outplant $formattedDate';
    }
    return 'Outplant $formattedDate';
  }

  /// Resolve tag prefix for outplant tagging.
  ///
  /// Extracts and sanitizes the site slug to create a tag prefix.
  /// For example, "Sunset Reef" -> "SUNSETREEF"
  String resolveEventTagPrefix({
    required String eventName,
    required Site? site,
    required DateTime date,
  }) {
    if (site == null) return '';

    final slug = site.slug.trim();
    if (slug.isEmpty) return '';

    final segment = slug.split('/').last.trim();
    final sanitized = segment.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (sanitized.isEmpty) return '';

    return sanitized.toUpperCase();
  }

  /// Update outplant tags on organism metadata.
  ///
  /// This is a best-effort operation that runs after the atomic commit.
  /// Failures are logged but don't affect the overall submission.
  Future<void> _updateOutplantTags({
    required List<OutplantAllocation> allocations,
    String? eventTagPrefix,
    String? existingTag,
  }) async {
    for (final allocation in allocations) {
      if (allocation.outplantTagId == null || allocation.outplantTagId!.isEmpty) {
        continue;
      }

      try {
        // Fetch the organism record
        final organism = await _organismRepository.getRecordForId(
          allocation.organismId,
        );
        if (organism == null) {
          _logger.warning(
            'Cannot update tag for organism ${allocation.organismId}: record not found',
          );
          continue;
        }

        // Update organism metadata with tag
        final updatedMetadata = {
          ...organism.metadata ?? {},
          'outplantTag': allocation.outplantTagId,
        };

        final updatedOrganism = organism.copyWith(metadata: updatedMetadata);
        await _organismRepository.updateRecord(updatedOrganism);

        _logger.info(
          'Updated organism ${organism.id} with tag ${allocation.outplantTagId}',
        );
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to update tag for organism ${allocation.organismId}',
          error,
          stackTrace,
        );
        // Continue processing other allocations even if one fails
      }
    }
  }

  /// Estimates the number of Firestore writes for the outplant operation.
  ///
  /// Firestore batches are limited to 500 writes; we use [_safeWriteThreshold] for safety margin.
  ///
  /// Accurate estimation accounts for:
  /// - 1 write for outplant event creation (always)
  /// - 1 write for geometry update (only if geometry exists)
  /// - Per organism: 2 writes (record update + event) only if:
  ///   - deductFromInventory is true AND
  ///   - organism's current quantity > 1
  int _estimateBatchSize(
    List<OutplantSelectedOrganism> organisms, {
    required bool deductFromInventory,
    required bool hasGeometry,
  }) {
    // 1 write for outplant event creation (always)
    int writes = 1;

    // 1 write for geometry update (only if geometry exists)
    if (hasGeometry) {
      writes += 1;
    }

    // Per organism: 2 writes only if deducting from inventory AND quantity > 1
    if (deductFromInventory) {
      for (final item in organisms) {
        final currentQuantity = item.currentQuantity ?? item.quantity;
        // Only count writes for organisms that will actually be updated
        // (currentQuantity > 1 because we skip organisms with quantity <= 1)
        if (currentQuantity > 1 && item.quantity > 0) {
          writes += 2; // updateRecord + createEvent
        }
      }
    }

    return writes;
  }
}

/// Model for selected organism with outplant details.
///
/// This is a simplified version of the OutplantSelectedOrganism from the bloc state,
/// containing only the data needed for submission.
class OutplantSelectedOrganism extends Equatable {
  const OutplantSelectedOrganism({
    required this.organismId,
    required this.quantity,
    this.tag,
    this.groupId,
    this.groupName,
    this.groupPath,
    this.currentQuantity,
    this.tagId,
    this.speciesId,
    this.genetRecordId,
    this.sourcePath,
    this.snapshot,
  });

  final String organismId;
  final int quantity;
  final String? tag;
  final String? groupId;
  final String? groupName;
  final String? groupPath;

  /// Current quantity in inventory (for deduction calculation)
  final int? currentQuantity;

  /// Display name for the organism
  final String? tagId;

  /// Species taxonomy ID
  final String? speciesId;

  /// Genet provenance ID
  final String? genetRecordId;

  /// URL path to organism record
  final String? sourcePath;

  /// Snapshot data for allocation
  final Map<String, dynamic>? snapshot;

  @override
  List<Object?> get props => [
    organismId,
    quantity,
    tag,
    groupId,
    groupName,
    groupPath,
    currentQuantity,
    tagId,
    speciesId,
    genetRecordId,
    sourcePath,
    snapshot,
  ];
}

/// Result of outplant submission.
class OutplantSubmissionResult extends Equatable {
  const OutplantSubmissionResult({
    required this.event,
    required this.affectedOrganismIds,
    required this.success,
    this.errorMessage,
  });

  final OutplantEvent event;
  final List<String> affectedOrganismIds;
  final bool success;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    event,
    affectedOrganismIds,
    success,
    errorMessage,
  ];
}

/// Exception thrown during outplant submission.
class OutplantSubmissionException implements Exception {
  const OutplantSubmissionException(this.message);

  final String message;

  @override
  String toString() => 'OutplantSubmissionException: $message';
}
