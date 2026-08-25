import 'package:equatable/equatable.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';

abstract class RecordFormEvent extends Equatable {
  const RecordFormEvent();
}

class RecordFormBaseEvent extends RecordFormEvent {
  const RecordFormBaseEvent();

  @override
  List<Object?> get props => [];
}

class RecordFormReset extends RecordFormBaseEvent {
  const RecordFormReset();
}

class RecordFormNextStep extends RecordFormBaseEvent {
  const RecordFormNextStep();
}

class RecordFormPreviousStep extends RecordFormBaseEvent {
  const RecordFormPreviousStep();
}

class RecordFormSubmit extends RecordFormBaseEvent {
  const RecordFormSubmit();
}

abstract class RecordFormInputEvent<T> extends RecordFormEvent {
  const RecordFormInputEvent(this.value, {this.inputType});

  final T value;
  final Type? inputType;

  @override
  List<Object?> get props => [value, inputType];
}

class RecordNameChanged extends RecordFormInputEvent<String?> {
  const RecordNameChanged(super.value, {super.inputType});
}

class RecordFormInitialize extends RecordFormBaseEvent {
  const RecordFormInitialize();
}

class RecordIdSetChanged extends RecordFormInputEvent<Set<String>?> {
  const RecordIdSetChanged(super.value, {super.inputType});
}

class QuantityChanged extends RecordFormInputEvent<int?> {
  const QuantityChanged(super.value, {super.inputType});
}

class QuantityMapChanged extends RecordFormInputEvent<Map<String, int>?> {
  const QuantityMapChanged(super.value, {super.inputType});
}

class TargetGroupChanged extends RecordFormInputEvent<String?> {
  const TargetGroupChanged(super.value, {super.inputType});
}

/// Event to initialize a form for editing an existing record
class RecordFormInitializeForEdit extends RecordFormEvent {
  const RecordFormInitializeForEdit(this.originalRecord);

  // Use dynamic to avoid conflict with Dart's Record type
  final dynamic originalRecord;

  @override
  List<Object?> get props => [originalRecord];
}

class SizeClassChanged extends RecordFormInputEvent<String?> {
  const SizeClassChanged(super.value, {super.inputType});
}

class MeasuredDimensionChanged extends RecordFormInputEvent<double?> {
  const MeasuredDimensionChanged(super.value, {super.inputType});
}

class DimensionUnitChanged extends RecordFormInputEvent<MeasurementUnit?> {
  const DimensionUnitChanged(super.value, {super.inputType});
}
