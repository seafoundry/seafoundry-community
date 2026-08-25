import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_event.dart';

class RecordFormInputError {
  final String message;
  const RecordFormInputError(this.message);
}

class RequiredInputError extends RecordFormInputError {
  const RequiredInputError([super.message = 'This field is required']);
}

abstract class RecordFormInput<T, E extends RecordFormInputError, EventType extends RecordFormEvent>
    extends FormzInput<T?, E>
    with EquatableMixin {
  const RecordFormInput.pure() : eventType = EventType, super.pure(null);
  const RecordFormInput.dirty(super.value) : eventType = EventType, super.dirty();

  final Type eventType;
  bool get isHidden => false;

  RecordFormInput copyWith({required T? value});
  
  String get label;
  String? get hintText;

  @override
  E? validator(T? value) {
    if (E == RequiredInputError && value == null) {
      return RequiredInputError() as E;
    }
    return null;
  }

  @override
  List<Object?> get props => [value, eventType, isPure];
}

class RecordNameInputError extends RequiredInputError {
  static const RecordNameInputError tooShort = RecordNameInputError('Name must be at least 2 characters');
  static const RecordNameInputError tooLong = RecordNameInputError('Name must be less than 50 characters');
  static const RecordNameInputError invalidCharacters = RecordNameInputError('Name contains invalid characters');
  const RecordNameInputError(super.message) : super();
}

class RecordNameInput extends RecordFormInput<String, RequiredInputError, RecordNameChanged> {
  const RecordNameInput.pure() : super.pure();
  const RecordNameInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Name';
  
  @override
  String? get hintText => 'Enter a name';

  @override
  RequiredInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return RequiredInputError();
    }
    if (trimmed.length < 2) return RecordNameInputError.tooShort;
    if (trimmed.length > 50) return RecordNameInputError.tooLong;

    // Check for invalid characters (only alphanumeric, spaces, hyphens, underscores)
    if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(trimmed)) {
      return RecordNameInputError.invalidCharacters;
    }

    return null;
  }

  @override
  RecordNameInput copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null) return RecordNameInput.pure();
    return RecordNameInput.dirty(value);
  }
}

class RecordIdSetInput
    extends RecordFormInput<Set<String>, RecordFormInputError, RecordIdSetChanged> {
  const RecordIdSetInput.pure({
    this.isRequired = false,
    this.emptyMessage,
  }) : super.pure();

  const RecordIdSetInput.dirty({
    Set<String>? value,
    this.isRequired = false,
    this.emptyMessage,
  }) : super.dirty(value ?? const <String>{});

  final bool isRequired;
  final String? emptyMessage;

  @override
  String get label => 'Selection';

  @override
  String? get hintText => 'Select items';

  @override
  RecordFormInputError? validator(Set<String>? value) {
    if (isRequired && (value == null || value.isEmpty)) {
      return RecordFormInputError(emptyMessage ?? 'Select at least one item');
    }
    return null;
  }

  @override
  RecordIdSetInput copyWith({required Set<String>? value}) {
    if (value == null || value.isEmpty) {
      return RecordIdSetInput.pure(isRequired: isRequired, emptyMessage: emptyMessage);
    }
    return RecordIdSetInput.dirty(
      value: value,
      isRequired: isRequired,
      emptyMessage: emptyMessage,
    );
  }
}

class QuantityMapInput
    extends RecordFormInput<Map<String, int>, RecordFormInputError, QuantityMapChanged> {
  const QuantityMapInput.pure({
    this.isRequired = false,
    this.allowZero = true,
    this.maxForKey,
    this.labelOverride,
    this.hintOverride,
  }) : super.pure();

  const QuantityMapInput.dirty({
    Map<String, int>? value,
    this.isRequired = false,
    this.allowZero = true,
    this.maxForKey,
    this.labelOverride,
    this.hintOverride,
  }) : super.dirty(value ?? const <String, int>{});

  final bool isRequired;
  final bool allowZero;
  final int? Function(String)? maxForKey;
  final String? labelOverride;
  final String? hintOverride;

  @override
  String get label => labelOverride ?? 'Quantities';

  @override
  String? get hintText => hintOverride ?? 'Enter quantity per item';

  @override
  RecordFormInputError? validator(Map<String, int>? value) {
    if (value == null || value.isEmpty) {
      if (isRequired) {
        return const RecordFormInputError('At least one quantity is required');
      }
      return null;
    }
    for (final entry in value.entries) {
      if (entry.value < 0) {
        return RecordFormInputError('Quantity for ${entry.key} cannot be negative');
      }
      if (!allowZero && entry.value == 0) {
        return RecordFormInputError('Quantity for ${entry.key} must be greater than zero');
      }
      final max = maxForKey?.call(entry.key);
      if (max != null && entry.value > max) {
        return RecordFormInputError('Quantity for ${entry.key} exceeds maximum of $max');
      }
    }
    return null;
  }

  @override
  QuantityMapInput copyWith({required Map<String, int>? value}) {
    if (value == null || value.isEmpty) {
      return QuantityMapInput.pure(
        isRequired: isRequired,
        allowZero: allowZero,
        maxForKey: maxForKey,
        labelOverride: labelOverride,
        hintOverride: hintOverride,
      );
    }
    return QuantityMapInput.dirty(
      value: value,
      isRequired: isRequired,
      allowZero: allowZero,
      maxForKey: maxForKey,
      labelOverride: labelOverride,
      hintOverride: hintOverride,
    );
  }
}
