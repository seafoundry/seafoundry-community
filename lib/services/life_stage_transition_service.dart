import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/types/life_stage.dart';
import 'package:seafoundry_community/models/validation/validation_result.dart';
import 'package:seafoundry_community/services/validation_rule_registry.dart';

class LifeStageTransitionService {
  LifeStageTransitionService({ValidationRuleRegistry? registry})
    : _registry = registry ?? ValidationRuleRegistry.instance;

  final ValidationRuleRegistry _registry;

  ValidationResult canTransition({
    required OrganismRecord record,
    required LifeStage targetStage,
    Duration? minimumInterval,
  }) {
    final lastTransitionAt = _lastTransitionTimestamp(record);
    if (minimumInterval != null && lastTransitionAt != null) {
      final elapsed = DateTime.now().difference(lastTransitionAt);
      if (elapsed < minimumInterval) {
        return ValidationResult.invalid(
          message:
              'Must wait ${minimumInterval.inDays} days before transitioning again.',
        );
      }
    }

    final context = ValidationRuleContext(
      organismKind: record.organismKind,
      lifeStage: targetStage,
      organismRecord: record.copyWith(
        lifeStage: record.lifeStage.copyWith(stage: targetStage),
      ),
    );

    final rules = _registry.rulesFor(
      organismKind: record.organismKind,
      lifeStage: targetStage,
    );
    for (final rule in rules) {
      final result = rule.evaluate(context);
      if (!result.isValid) {
        return result;
      }
    }
    return const ValidationResult.valid();
  }

  ValidationResult transition({
    required OrganismRecord record,
    required LifeStage targetStage,
    Duration? minimumInterval,
  }) {
    final validation = canTransition(
      record: record,
      targetStage: targetStage,
      minimumInterval: minimumInterval,
    );
    if (!validation.isValid) {
      return validation;
    }
    record.appendLifeStageTransition(LifeStageSpec(stage: targetStage));
    return const ValidationResult.valid();
  }

  DateTime? _lastTransitionTimestamp(OrganismRecord record) {
    if (record.lifeStageHistory.isEmpty) {
      // If there's no history, return null (no previous transition)
      return null;
    }
    return record.lifeStageHistory.last.occurredAt;
  }
}
