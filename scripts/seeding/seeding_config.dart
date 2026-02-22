// Configuration constants and utility classes for inventory seeding scripts.
//
// This module contains magic numbers extracted from the seeding scripts
// to provide named, documented constants.

import 'dart:math';

/// Seeding configuration constants
///
/// All threshold and range values used throughout the seeding scripts
/// are centralized here for maintainability and discoverability.
abstract final class SeedingConfig {
  // ---------------------------------------------------------------------------
  // Genet generation
  // ---------------------------------------------------------------------------

  /// Minimum number of genets created per species
  static const int kMinGenetsPerSpecies = 10;

  /// Variance added to minimum genets (actual range: 10 to 10+8=17)
  static const int kGenetVariance = 8;

  /// Probability threshold for founder type (0-49 = founder)
  static const int kFounderThreshold = 50;

  /// Probability threshold for cohort type (50-74 = cohort, 75+ = sexual recruit)
  static const int kCohortThreshold = 75;

  /// Maximum days ago for cross date generation (6 years)
  static const int kMaxCrossDateDaysAgo = 365 * 6;

  /// Minimum collection depth in meters
  static const int kMinDepthMeters = 6;

  /// Depth variance in meters (actual range: 6 to 6+15=21)
  static const int kDepthVariance = 15;

  /// Number of gametes generated per parent (dam/sire)
  static const int kGametesPerParent = 2;

  // ---------------------------------------------------------------------------
  // Monitoring events
  // ---------------------------------------------------------------------------

  /// Days between monitoring events (approximate)
  static const int kMonitoringEventSpacingDays = 30;

  /// Random jitter applied to monitoring event spacing
  static const int kMonitoringEventJitterDays = 15;

  /// Minimum number of genets selected per monitoring event
  static const int kMinGenetCount = 5;

  /// Variance for genet count (actual range: 5 to 5+11=15)
  static const int kGenetCountVariance = 11;

  // ---------------------------------------------------------------------------
  // Health metric thresholds
  // ---------------------------------------------------------------------------

  /// Probability threshold below which bleaching is 0% (0-69 = no bleaching)
  static const int kBleachingProbability = 70;

  /// Probability threshold for severe bleaching (90+ = severe)
  static const int kBleachingSeverityThreshold = 90;

  /// Minimum bleaching percentage when present (moderate range)
  static const int kBleachingMinSeverity = 15;

  /// Maximum bleaching percentage for severe cases
  static const int kBleachingMaxSeverity = 40;

  /// Probability threshold below which disease is 0% (0-84 = no disease)
  static const int kDiseaseProbability = 85;

  /// Probability threshold for severe disease (95+ = severe)
  static const int kDiseaseSeverityThreshold = 95;

  /// Minimum disease percentage when present (moderate range)
  static const int kDiseaseMinSeverity = 10;

  /// Maximum disease percentage for severe cases
  static const int kDiseaseMaxSeverity = 25;

  // ---------------------------------------------------------------------------
  // Coral cover by site type
  // ---------------------------------------------------------------------------

  /// Minimum coral cover for ex-situ (outplant) sites
  static const int kExSituMinCover = 5;

  /// Maximum additional coral cover variance for ex-situ sites (5 to 5+35=40%)
  static const int kExSituMaxCover = 35;

  /// Minimum coral cover for in-situ (nursery) sites
  static const int kInSituMinCover = 60;

  /// Maximum additional coral cover variance for in-situ sites (60 to 60+35=95%)
  static const int kInSituMaxCover = 35;

  // ---------------------------------------------------------------------------
  // Batch processing
  // ---------------------------------------------------------------------------

  /// Default batch size for parallel Firestore operations
  static const int kDefaultBatchSize = 10;

  /// Batch size for structure creation (tanks, domes, etc.)
  static const int kStructureBatchSize = 3;

  /// Batch size for rack seeding operations
  static const int kRackBatchSize = 5;

  // ---------------------------------------------------------------------------
  // Ecological survey defaults
  // ---------------------------------------------------------------------------

  /// Days between ecological surveys (quarterly)
  static const int kEcologicalSurveySpacingDays = 90;

  /// Random jitter applied to ecological survey spacing
  static const int kEcologicalSurveyJitterDays = 30;
}

/// Represents a range with min and max values for random selection.
///
/// Used throughout seeding scripts to define configurable ranges for
/// structures, racks, fragments, and other quantities.
class Range {
  /// Creates a range with the given minimum and maximum values.
  const Range(this.min, this.max);

  /// The minimum value (inclusive)
  final int min;

  /// The maximum value (inclusive)
  final int max;

  /// Picks a random value within this range (inclusive).
  ///
  /// Uses `min + rand.nextInt(max - min + 1)` to ensure both endpoints
  /// are included in the possible results.
  int pick(Random rand) => min + rand.nextInt(max - min + 1);

  @override
  String toString() => 'Range($min, $max)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Range && min == other.min && max == other.max;

  @override
  int get hashCode => Object.hash(min, max);
}
