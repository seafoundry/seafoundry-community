// @tier: community
import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/widgets/dialogs/observation/observation_dialog_config.dart';

/// Submission lifecycle for the observation dialog form.
enum ObservationFormStatus {
  initial,
  editing,
  submitting,
  success,
  failure,
}

/// Represents the state of a single field within the form.
class ObservationFieldState extends Equatable {
  const ObservationFieldState({
    this.value,
    this.isDirty = false,
    this.error,
  });

  final Object? value;
  final bool isDirty;
  final String? error;

  ObservationFieldState copyWith({
    Object? value,
    bool? isDirty,
    String? error,
  }) {
    return ObservationFieldState(
      value: value ?? this.value,
      isDirty: isDirty ?? this.isDirty,
      error: error,
    );
  }

  @override
  List<Object?> get props => [value, isDirty, error];
}

/// Immutable state for the observation form cubit.
class ObservationFormState extends Equatable {
  ObservationFormState({
    required this.config,
    required Map<ObservationDialogField, ObservationFieldState> fields,
    this.status = ObservationFormStatus.initial,
    this.errorMessage,
  }) :
        fields = UnmodifiableMapView(Map<ObservationDialogField, ObservationFieldState>.from(fields));

  final ObservationDialogConfig config;
  final Map<ObservationDialogField, ObservationFieldState> fields;
  final ObservationFormStatus status;
  final String? errorMessage;

  /// Returns `true` when all required fields are provided and no field reports an error.
  bool get isValid {
    for (final field in config.requiredFields) {
      final state = fields[field];
      if (state == null) {
        return false;
      }
      if (!_hasValue(state.value)) {
        return false;
      }
      if (state.error != null) {
        return false;
      }
    }
    for (final entry in fields.entries) {
      if (entry.value.error != null) {
        return false;
      }
    }
    return true;
  }

  ObservationFieldState fieldState(ObservationDialogField field) {
    return fields[field] ?? const ObservationFieldState();
  }

  Object? valueFor(ObservationDialogField field) => fieldState(field).value;

  String? errorFor(ObservationDialogField field) => fieldState(field).error;

  ObservationFormState copyWith({
    Map<ObservationDialogField, ObservationFieldState>? fields,
    ObservationFormStatus? status,
    String? errorMessage,
  }) {
    return ObservationFormState(
      config: config,
      fields: fields ?? this.fields,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        config,
        status,
        errorMessage,
        fields.entries.map((entry) => MapEntry(entry.key, entry.value)).toList(growable: false),
      ];

  static bool _hasValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }
}

/// Form cubit that manages validation and state transitions for the observation dialog.
class ObservationFormCubit extends Cubit<ObservationFormState> {
  ObservationFormCubit({
    required ObservationDialogConfig config,
    Map<ObservationDialogField, Object?> initialValues = const {},
    OrganismContext? organismContext,
  })  : organismContext =
            organismContext ?? OrganismContext.forKind(OrganismKind.coral),
        super(
          ObservationFormState(
            config: config,
            fields: _initialFieldStates(config, initialValues),
          ),
        );

  final OrganismContext organismContext;

  static Map<ObservationDialogField, ObservationFieldState> _initialFieldStates(
    ObservationDialogConfig config,
    Map<ObservationDialogField, Object?> initialValues,
  ) {
    final entries = <ObservationDialogField, ObservationFieldState>{};
    for (final fieldConfig in config.fields) {
      final initial = initialValues.containsKey(fieldConfig.field)
          ? initialValues[fieldConfig.field]
          : fieldConfig.defaultValue;
      final validated = _validate(fieldConfig, initial, config.isFieldRequired(fieldConfig.field));
      entries[fieldConfig.field] = ObservationFieldState(
        value: validated.value,
        error: validated.error,
      );
    }
    return entries;
  }

  /// Updates a specific field in the form and re-validates the form.
  void updateField(ObservationDialogField field, Object? value) {
    final fieldConfig = state.config.fieldConfig(field);
    if (fieldConfig == null) {
      return;
    }

    final validation = _validate(fieldConfig, value, state.config.isFieldRequired(field));
    final updatedFields = Map<ObservationDialogField, ObservationFieldState>.from(state.fields)
      ..update(
        field,
        (existing) => existing.copyWith(
          value: validation.value,
          isDirty: true,
          error: validation.error,
        ),
        ifAbsent: () => ObservationFieldState(
          value: validation.value,
          isDirty: true,
          error: validation.error,
        ),
      );

    emit(
      state.copyWith(
        fields: updatedFields,
        status: ObservationFormStatus.editing,
      ),
    );
  }

  /// Marks the form as submitting; intended to be followed by either [setSuccess] or [setFailure].
  void setSubmitting() {
    emit(state.copyWith(status: ObservationFormStatus.submitting));
  }

  /// Marks the form as successfully submitted.
  void setSuccess() {
    emit(state.copyWith(status: ObservationFormStatus.success, errorMessage: null));
  }

  /// Marks the form as failed, storing an optional message.
  void setFailure(String? message) {
    emit(state.copyWith(status: ObservationFormStatus.failure, errorMessage: message));
  }

  /// Returns the current value map, useful when applying form state to event models.
  Map<ObservationDialogField, Object?> snapshotValues() {
    return Map<ObservationDialogField, Object?>.fromEntries(
      state.fields.entries.map((entry) => MapEntry(entry.key, entry.value.value)),
    );
  }

  static _ValidationResult _validate(
    ObservationFieldConfig config,
    Object? rawValue,
    bool isRequired,
  ) {
    final value = _coerceValue(config, rawValue);
    String? error;

    if (isRequired) {
      if (!ObservationFormState._hasValue(value)) {
        error = 'Required field';
        return _ValidationResult(null, error);
      }
    }

    switch (config.kind) {
      case ObservationFieldKind.numeric:
        if (value == null) {
          if (isRequired) {
            error = 'Required field';
          }
          break;
        }
        if (value is! num) {
          error = 'Enter a number';
          break;
        }
        if (config.min != null && value < config.min!) {
          error = 'Must be ≥ ${config.min}';
        } else if (config.max != null && value > config.max!) {
          error = 'Must be ≤ ${config.max}';
        }
        break;
      default:
        break;
    }

    return _ValidationResult(value, error);
  }

  static Object? _coerceValue(ObservationFieldConfig config, Object? value) {
    if (value == null) {
      return config.kind == ObservationFieldKind.toggle ? false : null;
    }
    switch (config.kind) {
      case ObservationFieldKind.numeric:
        if (value is num) return value.toDouble();
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isEmpty) return null;
          final parsed = double.tryParse(trimmed);
          return parsed ?? value;
        }
        return value;
      case ObservationFieldKind.toggle:
        if (value is bool) return value;
        if (value is String) {
          final lower = value.toLowerCase();
          if (lower == 'true') return true;
          if (lower == 'false') return false;
        }
        return value == true;
      default:
        return value;
    }
  }
}

class _ValidationResult {
  const _ValidationResult(this.value, this.error);

  final Object? value;
  final String? error;
}
