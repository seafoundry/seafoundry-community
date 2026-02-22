// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';

/// Pure static utility for calculating and formatting organism tissue volumes.
///
/// All callers use the static convenience methods. Volume resolution uses
/// pre-resolved [OrganismRecord.inventoryMetrics].
class VolumeCalculationService {
  const VolumeCalculationService._();

  /// Check if an organism represents viable outplantable tissue.
  ///
  /// Returns `false` for gametes and embryos; `true` for everything else
  /// (plugs, clippings, juveniles, spawning colonies, recruits, larvae, etc.).
  ///
  /// **Design decision — larvae as viable tissue:**
  /// Larvae are classified as viable tissue for general inventory volume
  /// calculations because they represent living tissue mass that contributes
  /// to total holdings. In outplanting analytics, liquid allocations (gametes,
  /// embryos, larvae) are tracked separately via `_isLiquidAllocation()`, so
  /// larvae volume is not double-counted in tissue volume totals there. Only
  /// gametes and embryos are excluded here because they are vial/container
  /// content rather than discrete tissue units.
  static bool isViableTissue(OrganismRecord organism) {
    final stage = organism.lifeStage.stage;
    if (stage == LifeStage.gamete || stage == LifeStage.embryo) {
      return false;
    }
    return true;
  }

  /// Check if an organism is a gamete or embryo (non-viable tissue).
  static bool isVialContent(OrganismRecord organism) {
    return !isViableTissue(organism);
  }

  // -- Static methods using pre-resolved inventoryMetrics --

  /// Static: total volume in mm3 using pre-resolved [OrganismRecord.inventoryMetrics].
  static double? totalVolumeMm3(OrganismRecord organism) {
    final volumeCm3 = organism.inventoryMetrics.volumeCm3;
    if (volumeCm3 == null) return null;
    return volumeCm3 * 1000.0 * organism.measurement.value.round();
  }

  /// Static: viable tissue volume (excludes gametes/embryos).
  static double? tissueVolumeMm3(OrganismRecord organism) {
    if (!isViableTissue(organism)) return null;
    return totalVolumeMm3(organism);
  }

  /// Static: total volume for a collection of organisms.
  static double? totalCollectionVolumeMm3(
    Iterable<OrganismRecord> organisms, {
    bool includeNonViable = false,
  }) {
    if (organisms.isEmpty) return null;
    double total = 0.0;
    bool hasVolume = false;
    for (final organism in organisms) {
      if (!includeNonViable && !isViableTissue(organism)) continue;
      final volume = totalVolumeMm3(organism);
      if (volume != null) {
        total += volume;
        hasVolume = true;
      }
    }
    return hasVolume ? total : null;
  }

  /// Format volume in mm3 with appropriate unit based on magnitude.
  static String formatVolumeMm3(double? volumeMm3) {
    if (volumeMm3 == null) return 'N/A';
    if (volumeMm3 >= 1000000) {
      return '${(volumeMm3 / 1000000).toStringAsFixed(2)} L';
    }
    if (volumeMm3 >= 1000) {
      return '${(volumeMm3 / 1000).toStringAsFixed(1)} cm\u00B3';
    }
    return '${volumeMm3.toStringAsFixed(0)} mm\u00B3';
  }

  /// Count viable vs non-viable quantities.
  ///
  /// Returns map with 'viable' (tissue count) and 'nonViable' (gametes/embryos).
  static Map<String, int> countQuantitiesByType(
    Iterable<OrganismRecord> organisms,
  ) {
    int viableCount = 0;
    int nonViableCount = 0;
    for (final organism in organisms) {
      if (isViableTissue(organism)) {
        viableCount += organism.measurement.value.round();
      } else {
        nonViableCount += organism.measurement.value.round();
      }
    }
    return {'viable': viableCount, 'nonViable': nonViableCount};
  }

  /// Count unique genotypes in a collection of organisms.
  static Set<String> countUniqueGenotypes(
    Iterable<OrganismRecord> organisms,
  ) =>
      organisms
          .map((o) => GenetIdResolver.resolve(o) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

}
