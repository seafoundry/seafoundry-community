// @tier: community
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/services/environmental_threshold_registry.dart';
import 'package:seafoundry_app/services/husbandry_schedule_registry.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/mortality_cause_registry.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/training_gate_registry.dart';
import 'package:seafoundry_app/services/validation_rule_registry.dart';

/// Centralized manager for clearing all global caches and singletons on logout.
///
/// When a user logs out, stale data from the previous session must be cleared
/// to prevent data leakage or incorrect state when the same or a different
/// user logs back in.
///
/// This includes:
/// - SpeciesRegistry (global species/taxonomy cache)
/// - TaxonomyService caches (via SpeciesRegistry refresh)
/// - SiteBaselineService caches (cleared when RepositoriesProvider rebuilds)
/// - SyncManager configuration (repositories and feature gates)
/// - Organism config registries (environmental thresholds, husbandry schedules, etc.)
class CacheManager {
  CacheManager._();

  static final CacheManager instance = CacheManager._();

  /// Clears all global caches and resets singletons to their initial state.
  ///
  /// Call this during logout before signing out of Firebase Auth.
  void clearAllCaches() {
    if (kDebugMode) {
      LoggingService.instance.debug('CacheManager: Clearing all global caches on logout');
    }

    _clearSpeciesRegistry();
    _clearOrganismConfigRegistries();
    _clearProTierServices();

    LoggingService.instance.info('All global caches cleared on logout');
  }

  /// Clears the global SpeciesRegistry and resets Species to builtin defaults.
  void _clearSpeciesRegistry() {
    try {
      // Reset Species model to builtin defaults
      Species.reset();

      // Clear the global SpeciesRegistry instance if it exists
      final registry = SpeciesRegistry.globalInstance;
      if (registry != null) {
        // The SpeciesRegistry will be recreated on next login
        // We just need to ensure the global reference is cleared
        SpeciesRegistry.installGlobal(SpeciesRegistry());
      }

      if (kDebugMode) {
        LoggingService.instance.debug('CacheManager: SpeciesRegistry cleared');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to clear SpeciesRegistry',
        e,
        stackTrace,
      );
    }
  }

  /// Clears all organism configuration registries (thresholds, schedules, etc.).
  void _clearOrganismConfigRegistries() {
    try {
      // Clear EnvironmentalThresholdRegistry
      EnvironmentalThresholdRegistry.instance.reset();

      // Clear HusbandryScheduleRegistry
      HusbandryScheduleRegistry.instance.reset();

      // Clear ValidationRuleRegistry
      ValidationRuleRegistry.instance.reset();

      // Clear MortalityCauseRegistry
      MortalityCauseRegistry.instance.reset();

      // Clear TrainingGateRegistry
      TrainingGateRegistry.instance.reset();

      // Clear PhysicalFormRegistry
      PhysicalFormRegistry.instance.clearCache();

      if (kDebugMode) {
        LoggingService.instance.debug('CacheManager: Organism config registries cleared');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to clear organism config registries',
        e,
        stackTrace,
      );
    }
  }

  /// Optional callback to reset pro-tier services like SyncManager.
  /// Set by pro tier initialization code.
  static void Function()? _proTierResetCallback;

  /// Registers a callback to reset pro-tier services.
  /// Called by pro tier initialization to enable SyncManager reset on logout.
  static void registerProTierReset(void Function() callback) {
    _proTierResetCallback = callback;
  }

  /// Resets pro-tier services if available.
  void _clearProTierServices() {
    try {
      // Call the pro tier reset callback if registered
      _proTierResetCallback?.call();
      if (kDebugMode) {
        LoggingService.instance.debug('CacheManager: tier services reset (if available)');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to reset pro tier services',
        e,
        stackTrace,
      );
    }
  }
}
