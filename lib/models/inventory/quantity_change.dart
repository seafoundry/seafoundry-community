import 'package:seafoundry_app/models/types/population_gain_reason.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';

enum QuantityChangeKind { gain, loss }

class QuantityChangeReason {
  const QuantityChangeReason({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final QuantityChangeKind kind;

  /// Converts this reason to the corresponding [PopulationLossReason].
  ///
  /// Returns `null` if this is not a loss reason.
  ///
  /// **Mapping rationale:**
  /// - `'mortality'` → `PopulationLossReason.mortality` (direct semantic match)
  /// - `'transferOut'` → `PopulationLossReason.transferred` (direct semantic match)
  /// - `'outplant'` → `PopulationLossReason.outplanted` (direct semantic match)
  /// - `'density'` → `PopulationLossReason.other` (intentional culling has no exact match)
  /// - `'otherLoss'` → `PopulationLossReason.other` (direct semantic match)
  ///
  /// Note: `'density'` maps to `other` because density management/culling is an
  /// intentional management action that doesn't fit `humanError` (accidental)
  /// or `propagated` (fragmentation for propagation purposes).
  PopulationLossReason? toPopulationLossReason({
    PopulationLossReason? mortalityReason,
  }) {
    if (kind != QuantityChangeKind.loss) {
      return null;
    }

    switch (id) {
      case 'mortality':
        // Use specific mortality reason if provided, else generic mortality
        return mortalityReason ?? PopulationLossReason.mortality;
      case 'transferOut':
        return PopulationLossReason.transferred;
      case 'outplant':
        return PopulationLossReason.outplanted;
      case 'density':
        // Density management/culling is intentional - use 'other' as closest match
        return PopulationLossReason.other;
      case 'otherLoss':
        return PopulationLossReason.other;
      default:
        return PopulationLossReason.other;
    }
  }

  /// Converts this reason to the corresponding [PopulationGainReason].
  ///
  /// Returns `null` if this is not a gain reason.
  ///
  /// **Mapping rationale:**
  /// - `'reproduction'` → `PopulationGainReason.recruitment` (spawning/settlement)
  /// - `'transferIn'` → `PopulationGainReason.transferIn` (direct semantic match)
  /// - `'split'` → `PopulationGainReason.fragmentation` (splitting = fragmentation)
  /// - `'otherGain'` → `PopulationGainReason.other` (direct semantic match)
  PopulationGainReason? toPopulationGainReason() {
    if (kind != QuantityChangeKind.gain) {
      return null;
    }

    switch (id) {
      case 'reproduction':
        return PopulationGainReason.recruitment;
      case 'transferIn':
        return PopulationGainReason.transferIn;
      case 'split':
        return PopulationGainReason.fragmentation;
      case 'otherGain':
        return PopulationGainReason.other;
      default:
        return PopulationGainReason.other;
    }
  }

  /// Looks up a [QuantityChangeReason] by its [id].
  ///
  /// Returns `null` if no reason matches the given id.
  static QuantityChangeReason? fromId(String id) {
    for (final reason in gainReasons) {
      if (reason.id == id) return reason;
    }
    for (final reason in lossReasons) {
      if (reason.id == id) return reason;
    }
    return null;
  }

  /// All available gain reasons.
  static const List<QuantityChangeReason> gainReasons = _gainReasons;

  /// All available loss reasons.
  static const List<QuantityChangeReason> lossReasons = _lossReasons;
}

const List<QuantityChangeReason> _gainReasons = [
  QuantityChangeReason(
    id: 'reproduction',
    label: 'Reproduction / spawn',
    kind: QuantityChangeKind.gain,
  ),
  QuantityChangeReason(
    id: 'transferIn',
    label: 'Transfer in',
    kind: QuantityChangeKind.gain,
  ),
  QuantityChangeReason(
    id: 'split',
    label: 'Split / combine adjustment',
    kind: QuantityChangeKind.gain,
  ),
  QuantityChangeReason(
    id: 'otherGain',
    label: 'Other gain',
    kind: QuantityChangeKind.gain,
  ),
];

const List<QuantityChangeReason> _lossReasons = [
  QuantityChangeReason(
    id: 'mortality',
    label: 'Mortality',
    kind: QuantityChangeKind.loss,
  ),
  QuantityChangeReason(
    id: 'transferOut',
    label: 'Transfer out',
    kind: QuantityChangeKind.loss,
  ),
  QuantityChangeReason(
    id: 'outplant',
    label: 'Outplant / release',
    kind: QuantityChangeKind.loss,
  ),
  QuantityChangeReason(
    id: 'density',
    label: 'Density management / culling',
    kind: QuantityChangeKind.loss,
  ),
  QuantityChangeReason(
    id: 'otherLoss',
    label: 'Other loss',
    kind: QuantityChangeKind.loss,
  ),
];
