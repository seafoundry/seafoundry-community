// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/crab_pond_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/finfish_pen_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/mangrove_plot_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/oyster_bag_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/sea_cucumber_tank_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/seagrass_module_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/seeded_line_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/config/urchin_tank_holding_config.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

/// Registry of holding dialog configurations by organism kind.
/// Provides factory method to retrieve the appropriate config for each organism.
class HoldingDialogConfigs {
  HoldingDialogConfigs._();

  static final Map<OrganismKind, HoldingDialogConfig> _configs = {
    OrganismKind.crab: crabPondHoldingConfig,
    OrganismKind.finfish: finfishPenHoldingConfig,
    OrganismKind.oyster: oysterBagHoldingConfig,
    OrganismKind.mangrove: mangrovePlotHoldingConfig,
    OrganismKind.kelp: seededLineHoldingConfig,
    OrganismKind.seagrass: seagrassModuleHoldingConfig,
    OrganismKind.echinoid: urchinTankHoldingConfig,
    OrganismKind.seaCucumber: seaCucumberTankHoldingConfig,
  };

  /// Retrieves the holding dialog configuration for a given organism kind.
  /// Returns null if no configuration exists for the organism.
  static HoldingDialogConfig? getConfigForKind(OrganismKind kind) {
    return _configs[kind];
  }

  /// Checks if a configuration exists for the given organism kind.
  static bool hasConfigForKind(OrganismKind kind) {
    return _configs.containsKey(kind);
  }

  /// Returns all registered organism kinds that have dialog configurations.
  static Iterable<OrganismKind> get supportedKinds => _configs.keys;
}
