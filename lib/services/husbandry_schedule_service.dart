// @tier: community
import 'package:seafoundry_app/models/husbandry/husbandry_schedule_entry.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/husbandry_schedule_registry.dart';

class HusbandryScheduleService {
  HusbandryScheduleService({HusbandryScheduleRegistry? registry})
    : _registry = registry ?? HusbandryScheduleRegistry.instance;

  final HusbandryScheduleRegistry _registry;

  List<HusbandryScheduleEntry> scheduleFor({
    required OrganismKind organismKind,
    LifeStage? lifeStage,
  }) {
    return _registry.entriesFor(
      organismKind: organismKind,
      lifeStage: lifeStage,
    );
  }
}
