// @tier: community
// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/types/record_type.dart';

class PopulationGainReason extends BuiltinRecordType {
  const PopulationGainReason({required super.id, required super.name});

  static final Map<String, PopulationGainReason> builtins = {
    fragmentation.id: fragmentation,
    recruitment.id: recruitment,
    rescue.id: rescue,
    transferIn.id: transferIn,
    other.id: other,
  };

  /// Additional fragments created or attached to the structure
  static const PopulationGainReason fragmentation = PopulationGainReason(
    id: 'population_gain_reason_fragmentation',
    name: 'Fragmentation',
  );

  /// Natural settlement or spawning recruitment
  static const PopulationGainReason recruitment = PopulationGainReason(
    id: 'population_gain_reason_recruitment',
    name: 'Recruitment',
  );

  /// New specimens rescued or collected from the field
  static const PopulationGainReason rescue = PopulationGainReason(
    id: 'population_gain_reason_rescue',
    name: 'Rescue / Collection',
  );

  /// Inventory received from another structure or organization
  static const PopulationGainReason transferIn = PopulationGainReason(
    id: 'population_gain_reason_transfer_in',
    name: 'Transfer In',
  );

  static const PopulationGainReason other = PopulationGainReason(
    id: 'population_gain_reason_other',
    name: 'Other',
  );

  static const PopulationGainReason unknown = PopulationGainReason(
    id: 'population_gain_reason_unknown',
    name: 'Unknown',
  );
}
