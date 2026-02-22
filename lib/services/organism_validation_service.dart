// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/validation/validation_result.dart';
import 'package:seafoundry_app/services/validation_rule_registry.dart';

class OrganismValidationService {
  OrganismValidationService({
    ValidationRuleRegistry? registry,
  }) : _registry = registry ?? ValidationRuleRegistry.instance;

  final ValidationRuleRegistry _registry;

  List<ValidationResult> validateRecord(
    OrganismRecord record, {
    Map<String, dynamic>? attributes,
  }) {
    final context = ValidationRuleContext(
      organismKind: record.organismKind,
      lifeStage: record.lifeStage.stage,
      physicalForm: record.physicalForm?.formId,
      organismRecord: record,
      extra: attributes,
    );
    final rules = _registry.rulesFor(
      organismKind: record.organismKind,
      lifeStage: record.lifeStage.stage,
      physicalForm: record.physicalForm?.formId,
    );
    final results = <ValidationResult>[];
    for (final rule in rules) {
      final result = rule.evaluate(context);
      if (!result.isValid) {
        results.add(result);
      }
    }
    return results;
  }
}
