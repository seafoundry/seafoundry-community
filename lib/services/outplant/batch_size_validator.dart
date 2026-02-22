// @tier: community

/// Utility service for estimating Firestore write counts in outplant operations.
///
/// Firestore enforces a hard limit of 500 writes per batch. This service
/// provides conservative estimates and validation to prevent batch limit errors
/// during outplant submissions.
///
/// This is a pure utility with no dependencies - all methods are stateless.
class BatchSizeValidator {
  const BatchSizeValidator();

  /// Maximum writes Firestore allows in a single batch.
  ///
  /// We use 450 (90%) as a safety threshold to account for edge cases,
  /// even though Firestore's hard limit is 500.
  static const int safeWriteThreshold = 450;

  /// Conservative estimate of max organisms per batch.
  ///
  /// Calculation: (450 - 2 base writes) / ~2 writes per organism ≈ 224
  /// We advertise ~220 to users for a conservative estimate.
  static const int estimatedMaxOrganismsPerBatch = 220;

  /// Estimates total Firestore writes for an outplant operation.
  ///
  /// Write breakdown:
  /// - Base writes: 1 (event creation)
  /// - Geometry: +1 if [hasGeometry] is true
  /// - Per organism: 2 writes (allocation update + inventory deduction)
  ///   only if [deductFromInventory] is true
  ///
  /// [selectedOrganismCount]: Number of organisms being outplanted
  /// [deductFromInventory]: Whether inventory will be deducted
  /// [hasGeometry]: Whether geometry data is included
  /// [avgQuantityPerOrganism]: Average quantity per organism (for future use)
  int estimateWrites({
    required int selectedOrganismCount,
    required bool deductFromInventory,
    required bool hasGeometry,
    int avgQuantityPerOrganism = 1,
  }) {
    // 1 write for outplant event creation (always)
    int writes = 1;

    // 1 write for geometry update (only if geometry input exists)
    if (hasGeometry) {
      writes += 1;
    }

    // Per organism: 2 writes only if deducting from inventory
    // (1 for record update + 1 for population loss event)
    if (deductFromInventory) {
      writes += selectedOrganismCount * 2;
    }

    return writes;
  }

  /// Returns true if estimated writes exceed the safe threshold.
  ///
  /// Use this to validate before submitting an outplant operation.
  bool exceedsLimit(int estimatedWrites) {
    return estimatedWrites > safeWriteThreshold;
  }

  /// Returns maximum organisms that can be safely processed in one batch.
  ///
  /// This calculation accounts for:
  /// - Base writes (event + optional geometry)
  /// - Whether inventory deduction is enabled
  ///
  /// [deductFromInventory]: Whether inventory will be deducted
  /// [hasGeometry]: Whether geometry data is included
  int maxSafeOrganismCount({
    required bool deductFromInventory,
    required bool hasGeometry,
  }) {
    // Start with safe threshold
    int availableWrites = safeWriteThreshold;

    // Subtract base writes (event creation always happens)
    availableWrites -= 1;

    // Subtract geometry write if applicable
    if (hasGeometry) {
      availableWrites -= 1;
    }

    // Calculate max organisms based on whether we're deducting inventory
    if (deductFromInventory) {
      // 2 writes per organism (record update + event)
      return availableWrites ~/ 2;
    } else {
      // No per-organism writes needed if not deducting inventory
      // In this case, the limit is effectively unlimited from a batch perspective
      // Return a large but reasonable number
      return 100000;
    }
  }

  /// Validates an outplant operation and returns an error message if invalid.
  ///
  /// Returns null if the operation is within safe limits.
  /// Returns a user-friendly error message if limits are exceeded.
  String? validateOperation({
    required int selectedOrganismCount,
    required bool deductFromInventory,
    required bool hasGeometry,
  }) {
    final estimatedWrites = estimateWrites(
      selectedOrganismCount: selectedOrganismCount,
      deductFromInventory: deductFromInventory,
      hasGeometry: hasGeometry,
    );

    if (exceedsLimit(estimatedWrites)) {
      return 'Too many organisms selected ($estimatedWrites writes needed). '
          'Maximum is ~$estimatedMaxOrganismsPerBatch organisms per outplant. '
          'Please reduce the selection and try again.';
    }

    return null;
  }
}
