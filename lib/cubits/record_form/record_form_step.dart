import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_inputs.dart';

abstract class RecordFormStep extends Equatable with FormzMixin {
  RecordFormStep({required this.inputs, required this.title})
    : inputsMap = {for (final input in inputs) input.eventType: input};

  @override
  final List<RecordFormInput> inputs;
  final Map<Type, RecordFormInput> inputsMap;
  final String title;

  @override
  List<Object?> get props => [inputs, title];

  String? get validationErrorMessage {
    if (isValid) return null;
    // Use validator() directly instead of displayError to catch errors on
    // pure inputs that were programmatically set (e.g., auto-populated fields)
    final errors = <String>[];
    for (final input in inputs) {
      final error = input.validator(input.value);
      if (error != null) {
        errors.add('${input.label}: ${error.message}');
      }
    }
    return errors.isEmpty ? null : errors.join('\n');
  }

  RecordFormStep copyWith({required RecordFormInput copiedInput});

  /// Helper method to update inputs with a modified input
  List<RecordFormInput> updateInputs(RecordFormInput copiedInput) {
    return inputs.map((input) {
      if (input.runtimeType == copiedInput.runtimeType) {
        return copiedInput;
      }
      return input;
    }).toList();
  }
}

/// Base implementation of RecordFormStep for simple cases
final class BaseRecordFormStep extends RecordFormStep {
  BaseRecordFormStep({required super.inputs, required super.title});

  @override
  BaseRecordFormStep copyWith({required RecordFormInput copiedInput}) {
    return BaseRecordFormStep(inputs: updateInputs(copiedInput), title: title);
  }
}

class RecordFormReviewStep extends RecordFormStep {
  RecordFormReviewStep() : super(inputs: [], title: 'Review');

  @override
  RecordFormReviewStep copyWith({required RecordFormInput copiedInput}) {
    // Review step has no inputs, so just return self
    return this;
  }
}
