// @tier: community
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';

/// Event fired whenever the user updates the raw geometry text field.
class GeometryTextChanged extends RecordFormInputEvent<String?> {
  const GeometryTextChanged(super.value);
}

/// Lightweight form input that simply tracks the raw geometry coordinates text.
/// Parsing and validation occurs in the owning bloc once the field changes.
class GeometryTextInput
    extends RecordFormInput<String, RecordFormInputError, GeometryTextChanged> {
  const GeometryTextInput.pure() : super.pure();
  const GeometryTextInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Geometry Coordinates';

  @override
  String? get hintText => 'lat,lng per line';

  @override
  RecordFormInputError? validator(String? value) {
    return null; // Validation handled when parsing in the owning bloc.
  }

  @override
  GeometryTextInput copyWith({required String? value}) {
    if (value == null) {
      return const GeometryTextInput.pure();
    }
    if (value == this.value) return this;
    return GeometryTextInput.dirty(value);
  }
}
