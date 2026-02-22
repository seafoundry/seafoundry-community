// @tier: community
part of 'organism_record_repository.dart';

/// Helper methods for OrganismRecordRepository.
///
/// Contains validation, parsing, and utility functions used across
/// query and mutation operations.
mixin _OrganismRecordRepositoryHelpers on _OrganismRecordRepositoryBase {
  /// Safely parse an organism record from JSON, returning null on error.
  OrganismRecord? parseOrganismSafe(Map<String, dynamic> data) {
    try {
      return RecordFactory.recordFromJson<OrganismRecord>(data);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to parse organism record',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Validate 5-axis constraints before save operations.
  void validateOrganismRecord(OrganismRecord record) {
    final recordNameValue = record.recordName.trim();
    if (recordNameValue.isEmpty || recordNameValue == Missing.string) {
      throw RepositoryError(
        message: 'Invalid organism record: recordName is required',
        category: AppErrorCategory.validation,
        recoverySuggestion: 'Provide a record name for the organism.',
      );
    }
    final localIdValue = record.localId?.trim();
    if (localIdValue == null ||
        localIdValue.isEmpty ||
        localIdValue == Missing.string) {
      throw RepositoryError(
        message: 'Invalid organism record: localId is required',
        category: AppErrorCategory.validation,
        recoverySuggestion: 'Provide a local ID for the organism.',
      );
    }
    final validationError = record.validateFiveAxisConstraints();
    if (validationError != null) {
      throw RepositoryError(
        message: 'Invalid organism record: $validationError',
        category: AppErrorCategory.validation,
        recoverySuggestion: validationError,
      );
    }
  }

  /// Generate a URL-friendly slug base from the organism record.
  ///
  /// Priority:
  /// 1. localId (e.g., "Apal-002" -> "apal-002")
  /// 2. speciesId (e.g., "apal" -> "apal")
  /// 3. Fallback to "organism"
  ///
  /// Guards against empty sanitization results (e.g., "----", "!!!", emoji-only)
  /// which would cause invalid Firestore document paths.
  String generateSlugBase(OrganismRecord record) {
    // Try localId first - guard against sanitization yielding empty string
    final localId = record.localId;
    if (localId != null && localId.trim().isNotEmpty) {
      final sanitized = sanitizeForSlug(localId);
      if (sanitized.isNotEmpty) {
        return sanitized;
      }
    }

    // Try speciesId - also guard against empty sanitization result
    final speciesId = record.speciesId;
    if (speciesId != null && speciesId.trim().isNotEmpty) {
      final sanitized = sanitizeForSlug(speciesId);
      if (sanitized.isNotEmpty) {
        return sanitized;
      }
    }

    // Fallback to generic
    return 'organism';
  }

  /// Sanitize a string for use in a URL slug.
  ///
  /// Converts to lowercase, replaces spaces with hyphens, removes special chars.
  String sanitizeForSlug(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// Validates that adding an organism to a group won't exceed capacity limits.
  ///
  /// This provides defense-in-depth validation at the repository layer to protect
  /// against capacity violations from CSV imports, API calls, and concurrent
  /// operations that bypass dialog-layer validation.
  ///
  /// Throws [CapabilityConstraintError] if the group would exceed capacity.
  Future<void> validateGroupCapacity(
    String groupId,
    OrganismRecord record,
    Group group,
  ) async {
    if (!structureCapacityService.isEnabled) return;

    await structureCapacityService.ensureInitialized();

    // Count current organisms in the group
    final currentCount = await countByGroup(groupId);

    // Evaluate capacity with delta of 1 (adding one organism)
    final evaluation = structureCapacityService.evaluate(
      StructureCapacityRequest.forOccupants(
        containerType: group.groupType,
        organismKind: record.organismKind,
        lifeStage: record.lifeStage.stage,
        physicalFormId: record.physicalForm?.formId,
        currentUnits: currentCount,
        deltaUnits: 1, // Adding one organism
      ),
    );

    // No rule defined, skip validation
    if (!evaluation.hasRule) {
      return;
    }

    // Block if over capacity
    if (evaluation.isOverCapacity) {
      throw CapabilityConstraintError(
        message: evaluation.blockingMessage,
        capability: 'structureCapacity',
        recoverySuggestion:
            'Choose a different group or remove existing organisms.',
        context: {
          'groupId': group.id,
          'groupName': group.name,
          'organismKind': record.organismKind.name,
          'currentUnits': currentCount,
          'projectedUnits': evaluation.projectedUnits,
          'maxUnits': evaluation.rule?.maxUnits,
        },
      );
    }

    // Log warning if approaching capacity (non-blocking)
    if (evaluation.isWarning) {
      LoggingService.instance.warning(
        'Approaching capacity: ${evaluation.warnings.join(", ")}',
        {
          'groupId': group.id,
          'currentUnits': currentCount,
          'maxUnits': evaluation.rule?.maxUnits,
        },
      );
    }
  }

}
