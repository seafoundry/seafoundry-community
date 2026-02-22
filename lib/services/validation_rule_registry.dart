// @tier: community
import 'dart:collection';
import 'dart:convert';

import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/validation/validation_result.dart';
import 'package:seafoundry_app/models/validation/validation_rule_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:yaml/yaml.dart';

typedef ValidationRuleEvaluator =
    ValidationResult Function(ValidationRuleContext context);
typedef ValidationRuleRegistryListener = void Function();

class ValidationRuleRegistry {
  ValidationRuleRegistry._();

  static final ValidationRuleRegistry instance = ValidationRuleRegistry._();

  final Map<OrganismKind, List<_ValidationRuleEntry>> _rules = {};
  final List<ValidationRuleRegistryListener> _listeners = [];

  void addListener(ValidationRuleRegistryListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ValidationRuleRegistryListener listener) {
    _listeners.remove(listener);
  }

  void registerRule({
    required OrganismKind organismKind,
    LifeStage? lifeStage,
    String? physicalForm,
    required ValidationRule rule,
    bool overrideExisting = false,
  }) {
    final entries = _rules.putIfAbsent(
      organismKind,
      () => <_ValidationRuleEntry>[],
    );
    if (overrideExisting) {
      entries.removeWhere(
        (entry) =>
            entry.rule.id == rule.id &&
            entry.lifeStage == lifeStage &&
            entry.physicalForm == physicalForm,
      );
    }
    entries.add(
      _ValidationRuleEntry(
        lifeStage: lifeStage,
        physicalForm: physicalForm,
        rule: rule,
      ),
    );
    _notifyListeners();
  }

  void clearRules(OrganismKind organismKind) {
    if (_rules.remove(organismKind) != null) {
      _notifyListeners();
    }
  }

  /// Clears all rules. Used during logout to prevent stale data.
  void reset() {
    if (_rules.isNotEmpty) {
      _rules.clear();
      _notifyListeners();
    }
  }

  List<ValidationRule> rulesFor({
    required OrganismKind organismKind,
    LifeStage? lifeStage,
    String? physicalForm,
  }) {
    final entries = _rules[organismKind];
    if (entries == null || entries.isEmpty) {
      return const <ValidationRule>[];
    }
    bool matches(_ValidationRuleEntry entry) {
      final lifeStageMatch =
          entry.lifeStage == null || entry.lifeStage == lifeStage;
      final physicalFormMatch =
          entry.physicalForm == null || entry.physicalForm == physicalForm;
      return lifeStageMatch && physicalFormMatch;
    }

    final matching = entries.where(matches).map((entry) => entry.rule).toList();
    return List<ValidationRule>.unmodifiable(matching);
  }

  Map<String, List<Map<String, dynamic>>> toSerializableMap() {
    return UnmodifiableMapView({
      for (final entry in _rules.entries)
        entry.key.name: entry.value
            .map((ruleEntry) => ruleEntry.toSerializableMap())
            .toList(growable: false),
    });
  }

  void loadRulesFromYaml(String yaml, {bool overrideExisting = false}) {
    final document = loadYaml(yaml);
    if (document is! YamlMap) {
      return;
    }
    document.forEach((dynamic organismKey, dynamic value) {
      final kind = OrganismKindX.tryParse(organismKey?.toString());
      if (kind == null) return;
      if (value is! YamlList) return;
      for (final node in value) {
        if (node is! YamlMap) continue;
        final map = Map<String, dynamic>.from(jsonDecode(jsonEncode(node)));
        final rule = ValidationRule.fromMap(map);
        final lifeStage = LifeStageX.tryParse(map['lifeStage']?.toString());
        final physicalForm = map['physicalForm']?.toString();
        registerRule(
          organismKind: kind,
          lifeStage: lifeStage,
          physicalForm: physicalForm,
          rule: rule,
          overrideExisting: overrideExisting,
        );
      }
    });
  }

  void _notifyListeners() {
    for (final listener in List<ValidationRuleRegistryListener>.from(
      _listeners,
    )) {
      listener();
    }
  }
}

class ValidationRuleContext {
  ValidationRuleContext({
    required this.organismKind,
    this.lifeStage,
    this.physicalForm,
    this.organismRecord,
    Map<String, dynamic>? extra,
  }) : extra = UnmodifiableMapView(extra ?? const {});

  final OrganismKind organismKind;
  final LifeStage? lifeStage;
  final String? physicalForm;
  final OrganismRecord? organismRecord;
  final Map<String, dynamic> extra;

  dynamic operator [](String key) => extra[key];
}

class ValidationRule {
  ValidationRule({
    required this.id,
    required this.description,
    this.severity = ValidationSeverity.error,
    required this.type,
    Map<String, dynamic>? config,
    ValidationRuleEvaluator? evaluator,
  }) : _config = config ?? const <String, dynamic>{},
       _evaluator =
           evaluator ??
           _buildEvaluator(type, config ?? const <String, dynamic>{});

  factory ValidationRule.fromMap(Map<String, dynamic> map) {
    final type = ValidationRuleType.values.firstWhere(
      (value) => value.name == (map['type']?.toString() ?? ''),
      orElse: () => ValidationRuleType.requiredField,
    );
    final severity = ValidationSeverity.values.firstWhere(
      (value) => value.name == (map['severity']?.toString() ?? 'error'),
      orElse: () => ValidationSeverity.error,
    );

    return ValidationRule(
      id:
          map['id']?.toString() ??
          'rule_${DateTime.now().millisecondsSinceEpoch}',
      description: map['description']?.toString() ?? '',
      severity: severity,
      type: type,
      config: Map<String, dynamic>.from(map['config'] ?? map),
    );
  }

  final String id;
  final String description;
  final ValidationSeverity severity;
  final ValidationRuleType type;

  final Map<String, dynamic> _config;
  final ValidationRuleEvaluator _evaluator;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'description': description,
        'severity': severity.name,
        'type': type.name,
        'config': Map<String, dynamic>.from(_config),
      };

  ValidationResult evaluate(ValidationRuleContext context) {
    final result = _evaluator(context);
    if (result.isValid || result.message == null) {
      return result;
    }
    return ValidationResult.invalid(
      message: result.message!,
      severity: result.severity,
    );
  }

  static ValidationRuleEvaluator _buildEvaluator(
    ValidationRuleType type,
    Map<String, dynamic> config,
  ) {
    switch (type) {
      case ValidationRuleType.requiredField:
        final field = config['field']?.toString();
        final physicalForms = _stringSet(config['physicalForms']);
        return (context) {
          // Skip validation if physicalForms is specified and current form
          // doesn't match
          if (physicalForms.isNotEmpty) {
            final currentForm = context.physicalForm;
            if (currentForm == null || !physicalForms.contains(currentForm)) {
              return const ValidationResult.valid();
            }
          }
          final value = _readField(field, context);
          final isEmpty =
              value == null ||
              (value is String && value.trim().isEmpty) ||
              (value is num && value == 0);
          if (isEmpty) {
            return ValidationResult.invalid(
              message:
                  config['message']?.toString() ??
                  '$field is required for ${context.organismKind.name}.',
            );
          }
          return const ValidationResult.valid();
        };
      case ValidationRuleType.measurementRange:
        final min = safeDouble(config['min']);
        final max = safeDouble(config['max']);
        return (context) {
          final measurement = context.organismRecord?.measurement;
          final value = measurement?.value;
          if (value == null) {
            return ValidationResult.invalid(
              message: config['message']?.toString() ?? 'Measurement required.',
            );
          }
          if (min != null && value < min) {
            return ValidationResult.invalid(
              message:
                  config['message']?.toString() ??
                  'Measurement must be >= $min.',
            );
          }
          if (max != null && value > max) {
            return ValidationResult.invalid(
              message:
                  config['message']?.toString() ??
                  'Measurement must be <= $max.',
            );
          }
          return const ValidationResult.valid();
        };
      case ValidationRuleType.sizeRange:
        final min = safeDouble(config['min']);
        final max = safeDouble(config['max']);
        final unit = MeasurementUnitX.tryParse(config['unit']?.toString());
        final requireMeasurement = config['requireMeasurement'] != false;
        final message = config['message']?.toString();
        final physicalForms = _stringSet(config['physicalForms']);
        return (context) {
          // Skip validation if physicalForms is specified and current form
          // doesn't match
          if (physicalForms.isNotEmpty) {
            final currentForm = context.physicalForm;
            if (currentForm == null || !physicalForms.contains(currentForm)) {
              return const ValidationResult.valid();
            }
          }
          final sizeSpec = context.organismRecord?.sizeSpec;
          final value = sizeSpec?.measuredDimension;
          final measuredUnit = sizeSpec?.dimensionUnit;
          if (value == null) {
            if (!requireMeasurement) return const ValidationResult.valid();
            return ValidationResult.invalid(
              message: message ??
                  'A measured size value is required for ${context.organismKind.name}.',
            );
          }
          if (unit != null && measuredUnit != null && unit != measuredUnit) {
            return ValidationResult.invalid(
              message: message ??
                  'Size measurements must use ${unit.label} for this organism.',
            );
          }
          if (min != null && value < min) {
            return ValidationResult.invalid(
              message:
                  message ??
                  'Measured size must be greater than or equal to $min.',
            );
          }
          if (max != null && value > max) {
            return ValidationResult.invalid(
              message:
                  message ??
                  'Measured size must be less than or equal to $max.',
            );
          }
          return const ValidationResult.valid();
        };
      case ValidationRuleType.allowedPhysicalForm:
        final ids =
            (config['physicalForms'] as List?)
                ?.map((value) => value?.toString())
                .whereType<String>()
                .toSet() ??
            const <String>{};
        return (context) {
          final physicalForm = context.physicalForm;
          if (physicalForm == null) {
            return const ValidationResult.valid();
          }
          if (ids.isNotEmpty && !ids.contains(physicalForm)) {
            return ValidationResult.invalid(
              message:
                  config['message']?.toString() ??
                  'Physical form $physicalForm is not allowed.',
            );
          }
          return const ValidationResult.valid();
        };
      case ValidationRuleType.physicalFormTransition:
        final allowedTargets = _stringSet(config['targets']);
        final disallowedTargets = _stringSet(config['disallowedTargets']);
        final fromPhysicalForms = _stringSet(config['from']);
        final requireChange = config['requireChange'] != false;
        final message = config['message']?.toString();
        return (context) {
          final current = context.extra['currentPhysicalForm']?.toString();
          final target = context.physicalForm;
          if (requireChange && (target == null || target == current)) {
            return ValidationResult.invalid(
              message:
                  message ??
                  'Select a different physical form before continuing.',
            );
          }
          if (fromPhysicalForms.isNotEmpty &&
              (current == null || !fromPhysicalForms.contains(current))) {
            return const ValidationResult.valid();
          }
          if (disallowedTargets.contains(target)) {
            return ValidationResult.invalid(
              message:
                  message ??
                  'Transition to ${target ?? 'target'} is not allowed.',
            );
          }
          if (allowedTargets.isNotEmpty &&
              (target == null || !allowedTargets.contains(target))) {
            return ValidationResult.invalid(
              message:
                  message ??
                  'Physical form ${target ?? 'target'} is not an allowed transition.',
            );
          }
          return const ValidationResult.valid();
        };
      case ValidationRuleType.custom:
        throw ArgumentError(
          'Custom validation rules must provide an evaluator.',
        );
    }
  }

  static dynamic _readField(String? field, ValidationRuleContext context) {
    if (field == null || field.isEmpty) return null;
    switch (field) {
      case 'sizeClass':
        return context.organismRecord?.sizeSpec.sizeClass;
      case 'physicalForm':
        return context.physicalForm;
      case 'measurement':
        return context.organismRecord?.measurement.value;
      case 'quantity':
        return context.organismRecord?.measurement.value;
      default:
        return context.extra[field];
    }
  }
}

class _ValidationRuleEntry {
  _ValidationRuleEntry({required this.rule, this.lifeStage, this.physicalForm});

  final ValidationRule rule;
  final LifeStage? lifeStage;
  final String? physicalForm;

  Map<String, dynamic> toSerializableMap() {
    final payload = rule.toJson();
    if (lifeStage != null) {
      payload['lifeStage'] = lifeStage!.id;
    }
    if (physicalForm != null) {
      payload['physicalForm'] = physicalForm;
    }
    return payload;
  }
}

Set<String> _stringSet(dynamic value) {
  if (value == null) return const <String>{};
  if (value is String && value.trim().isNotEmpty) {
    return {value.trim()};
  }
  if (value is Iterable) {
    return value
        .map((entry) => entry?.toString())
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }
  return const <String>{};
}
