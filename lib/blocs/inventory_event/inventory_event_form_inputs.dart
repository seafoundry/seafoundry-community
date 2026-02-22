// @tier: community
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/models/types/coral_size.dart';
import 'package:seafoundry_app/models/types/disease_type.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/types/population_gain_reason.dart';

class QuantityError extends RequiredInputError {
  static const QuantityError nonNegative = QuantityError(
    'Quantity must be greater than zero',
  );
  static const QuantityError tooLarge = QuantityError(
    'Quantity must be less than 1000',
  );
  const QuantityError(super.message);
}

class QuantityInput
    extends RecordFormInput<int?, QuantityError, QuantityChanged> {
  const QuantityInput.pure() : super.pure();
  const QuantityInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Quantity';

  @override
  String? get hintText => 'Number of organisms';

  @override
  QuantityError? validator(int? value) {
    if (value == null) return QuantityError('Quantity is required');
    if (value < 0) return QuantityError.nonNegative;
    if (value > 1000) return QuantityError.tooLarge;
    return null;
  }

  @override
  QuantityInput copyWith({required int? value}) {
    if (value == this.value) return this;
    if (value == null) return QuantityInput.pure();
    return QuantityInput.dirty(value);
  }
}

class InventoryEventCommentChanged extends RecordFormInputEvent<String> {
  const InventoryEventCommentChanged(super.value);
}

class InventoryEventComment
    extends
        RecordFormInput<
          String,
          RecordFormInputError,
          InventoryEventCommentChanged
        > {
  const InventoryEventComment.pure() : super.pure();
  const InventoryEventComment.dirty(super.value) : super.dirty();

  @override
  String get label => 'Comment';

  @override
  String? get hintText => 'Add a comment (optional)';

  @override
  InventoryEventComment copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null) return InventoryEventComment.pure();
    return InventoryEventComment.dirty(value);
  }
}

class SizeClassInput
    extends RecordFormInput<String, RecordFormInputError, SizeClassChanged> {
  const SizeClassInput.pure() : super.pure();
  const SizeClassInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Size class';

  @override
  String? get hintText => 'XS, S, M, L, XL';

  @override
  SizeClassInput copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null || value.trim().isEmpty) return SizeClassInput.pure();
    return SizeClassInput.dirty(value.trim());
  }
}

class MeasuredDimensionInput
    extends
        RecordFormInput<
          double,
          RecordFormInputError,
          MeasuredDimensionChanged
        > {
  const MeasuredDimensionInput.pure() : super.pure();
  const MeasuredDimensionInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Measured dimension';

  @override
  String? get hintText => 'Enter length or diameter';

  @override
  RecordFormInputError? validator(double? value) {
    if (value == null) return null;
    if (value <= 0) {
      return const RecordFormInputError(
        'Measured dimension must be greater than zero',
      );
    }
    return null;
  }

  @override
  MeasuredDimensionInput copyWith({required double? value}) {
    if (value == this.value) return this;
    if (value == null) return const MeasuredDimensionInput.pure();
    return MeasuredDimensionInput.dirty(value);
  }
}

class DimensionUnitInput
    extends
        RecordFormInput<
          MeasurementUnit,
          RecordFormInputError,
          DimensionUnitChanged
        > {
  const DimensionUnitInput.pure() : super.pure();
  const DimensionUnitInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Measurement unit';

  @override
  String? get hintText => 'cm, mm, m';

  @override
  DimensionUnitInput copyWith({required MeasurementUnit? value}) {
    if (value == this.value) return this;
    if (value == null) return const DimensionUnitInput.pure();
    return DimensionUnitInput.dirty(value);
  }
}

class InventoryEventPopulationLossReasonChanged
    extends RecordFormInputEvent<PopulationLossReason?> {
  const InventoryEventPopulationLossReasonChanged(super.value);
}

class InventoryEventPopulationLossReason
    extends
        RecordFormInput<
          PopulationLossReason,
          RequiredInputError,
          InventoryEventPopulationLossReasonChanged
        > {
  const InventoryEventPopulationLossReason.pure() : super.pure();
  const InventoryEventPopulationLossReason.dirty(super.value) : super.dirty();

  @override
  String get label => 'Loss Reason';

  @override
  String? get hintText => 'Select the reason for population loss';

  @override
  RequiredInputError? validator(PopulationLossReason? value) {
    // Loss reason is only required when quantity decreases
    // It's optional when quantity increases (population gain)
    // This will be enforced by the bloc's business logic
    return null;
  }

  @override
  InventoryEventPopulationLossReason copyWith({
    required PopulationLossReason? value,
  }) {
    if (value == this.value) return this;
    if (value == null) return InventoryEventPopulationLossReason.pure();
    return InventoryEventPopulationLossReason.dirty(value);
  }
}

class InventoryEventPopulationGainReasonChanged
    extends RecordFormInputEvent<PopulationGainReason?> {
  const InventoryEventPopulationGainReasonChanged(super.value);
}

class InventoryEventPopulationGainReason
    extends
        RecordFormInput<
          PopulationGainReason,
          RequiredInputError,
          InventoryEventPopulationGainReasonChanged
        > {
  const InventoryEventPopulationGainReason.pure() : super.pure();
  const InventoryEventPopulationGainReason.dirty(super.value) : super.dirty();

  @override
  String get label => 'Gain Reason';

  @override
  String? get hintText => 'Select the reason for population gain';

  @override
  RequiredInputError? validator(PopulationGainReason? value) {
    if (value == null) {
      return RequiredInputError('Please select a gain reason');
    }
    return null;
  }

  @override
  InventoryEventPopulationGainReason copyWith({
    required PopulationGainReason? value,
  }) {
    if (value == this.value) return this;
    if (value == null) return InventoryEventPopulationGainReason.pure();
    return InventoryEventPopulationGainReason.dirty(value);
  }
}

class InventoryEventMortalityReasonChanged
    extends RecordFormInputEvent<MortalityReason?> {
  const InventoryEventMortalityReasonChanged(super.value);
}

class InventoryEventMortalityReason
    extends
        RecordFormInput<
          MortalityReason,
          RecordFormInputError,
          InventoryEventMortalityReasonChanged
        > {
  const InventoryEventMortalityReason.pure() : super.pure();
  const InventoryEventMortalityReason.dirty(super.value) : super.dirty();

  @override
  String get label => 'Mortality Reason';

  @override
  String? get hintText => 'Select the specific cause of mortality';

  @override
  InventoryEventMortalityReason copyWith({required MortalityReason? value}) {
    if (value == this.value) return this;
    if (value == null) return InventoryEventMortalityReason.pure();
    return InventoryEventMortalityReason.dirty(value);
  }
}

class InventoryEventSizeIncreased extends RecordFormInputEvent<CoralSize> {
  const InventoryEventSizeIncreased(super.value);
}

class InventoryEventSizeIncrease
    extends
        RecordFormInput<
          CoralSize,
          RequiredInputError,
          InventoryEventSizeIncreased
        > {
  const InventoryEventSizeIncrease.pure({required this.initialSize})
    : super.pure();
  const InventoryEventSizeIncrease.dirty(
    super.value, {
    required this.initialSize,
  }) : super.dirty();
  final CoralSize initialSize;

  @override
  String get label => 'New Size';

  @override
  String? get hintText => 'Select the new coral size';

  @override
  InventoryEventSizeIncrease copyWith({required CoralSize? value}) {
    if (value == this.value) return this;
    if (value == null) {
      return InventoryEventSizeIncrease.pure(initialSize: initialSize);
    }
    return InventoryEventSizeIncrease.dirty(value, initialSize: initialSize);
  }

  @override
  RequiredInputError? validator(CoralSize? value) {
    if (value == null) return RequiredInputError('Please select a new size');
    if (value.index <= initialSize.index) {
      return RequiredInputError('New size must be greater than old size');
    }
    return null;
  }
}

class InventoryEventSizeDecreased extends RecordFormInputEvent<CoralSize> {
  const InventoryEventSizeDecreased(super.value);
}

class InventoryEventSizeDecrease
    extends
        RecordFormInput<
          CoralSize,
          RequiredInputError,
          InventoryEventSizeDecreased
        > {
  const InventoryEventSizeDecrease.pure({required this.initialSize})
    : super.pure();
  const InventoryEventSizeDecrease.dirty(
    super.value, {
    required this.initialSize,
  }) : super.dirty();
  final CoralSize initialSize;

  @override
  String get label => 'New Size';

  @override
  String? get hintText => 'Select the smaller size';

  @override
  InventoryEventSizeDecrease copyWith({required CoralSize? value}) {
    if (value == this.value) return this;
    if (value == null) {
      return InventoryEventSizeDecrease.pure(initialSize: initialSize);
    }
    return InventoryEventSizeDecrease.dirty(value, initialSize: initialSize);
  }

  @override
  RequiredInputError? validator(CoralSize? value) {
    if (value == null) return RequiredInputError('Please select a new size');
    if (value.index >= initialSize.index) {
      return RequiredInputError('New size must be less than old size');
    }
    return null;
  }
}

class InventoryEventSizeAdded extends RecordFormInputEvent<CoralSize> {
  const InventoryEventSizeAdded(super.value);
}

class InventoryEventAddSize
    extends
        RecordFormInput<
          CoralSize,
          RequiredInputError,
          InventoryEventSizeAdded
        > {
  const InventoryEventAddSize.pure() : super.pure();
  const InventoryEventAddSize.dirty(super.value) : super.dirty();

  @override
  String get label => 'Size';

  @override
  String? get hintText => 'Select coral size';

  @override
  InventoryEventAddSize copyWith({required CoralSize? value}) {
    if (value == this.value) return this;
    if (value == null) return InventoryEventAddSize.pure();
    return InventoryEventAddSize.dirty(value);
  }
}

class InventoryEventDiseaseTypeChanged
    extends RecordFormInputEvent<DiseaseType?> {
  const InventoryEventDiseaseTypeChanged(super.value);
}

class InventoryEventDiseaseType
    extends
        RecordFormInput<
          DiseaseType,
          RecordFormInputError,
          InventoryEventDiseaseTypeChanged
        > {
  const InventoryEventDiseaseType.pure() : super.pure();
  const InventoryEventDiseaseType.dirty(super.value) : super.dirty();

  @override
  String get label => 'Disease Type';

  @override
  String? get hintText => 'Select the type of disease';

  @override
  InventoryEventDiseaseType copyWith({required DiseaseType? value}) {
    if (value == this.value) return this;
    if (value == null) return InventoryEventDiseaseType.pure();
    return InventoryEventDiseaseType.dirty(value);
  }
}

class EventTypeSelected extends RecordFormInputEvent<EventType> {
  const EventTypeSelected(super.value);
}

class EventTypeSelection
    extends
        RecordFormInput<EventType, RecordFormInputError, EventTypeSelected> {
  const EventTypeSelection.pure({required this.options}) : super.pure();
  const EventTypeSelection.dirty(super.value, {required this.options})
    : super.dirty();

  final List<EventType> options;

  @override
  String get label => 'Event Type';

  @override
  String get hintText => 'Select the event type';

  @override
  EventTypeSelection copyWith({required EventType? value}) {
    if (value == this.value) return this;
    if (value == null) {
      return EventTypeSelection.pure(options: options);
    }
    return EventTypeSelection.dirty(value, options: options);
  }
}
