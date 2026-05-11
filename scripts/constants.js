/**
 * Shared constants for seed scripts and utilities
 *
 * IMPORTANT: These constants must be kept in sync with their Dart equivalents
 *
 * Synchronization Requirements:
 * - TOUR_VERSION must match TourService.tourVersion in lib/services/tour_service.dart
 */

/**
 * Tour version identifier
 * @type {string}
 * @see lib/services/tour_service.dart:6 - TourService.tourVersion (source of truth)
 */
const TOUR_VERSION = '1.0.1';

/**
 * Global/shared collections that contain reference data
 * These collections contain data shared across all organizations
 */
const GLOBAL_COLLECTIONS = [
  'historical_impact_points',
  'historical_outplant_events',
  'historical_filter_options',
  'historical_reef_aggregates',
  'provenance_crosswalk',
  'community_provenances',
  'community_genetics_provenances',
  'community_genetics_aliases',
  'taxonomy',
  'taxonomy_species',
  'taxonomy_provenances',
  'taxonomy_lineages',
  'taxonomy_overrides', // Organization-independent overrides (thresholds, schedules, validation rules)
  'species',
  'group_types',
  'site_types',
  'tier_manifest',
  'training_media',
  'sops',
];

/**
 * Check if a collection is global (shared across organizations)
 * @param {string} name - Collection name
 * @returns {boolean}
 */
function isGlobalCollection(name) {
  return GLOBAL_COLLECTIONS.includes(name);
}

module.exports = {
  TOUR_VERSION,
  GLOBAL_COLLECTIONS,
  isGlobalCollection,
};
