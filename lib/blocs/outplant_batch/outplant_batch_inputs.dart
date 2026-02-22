// @tier: community
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';

class OutplantSiteChanged extends RecordFormInputEvent<String?> {
  const OutplantSiteChanged(super.value);
}

class OutplantSiteInput
    extends RecordFormInput<String, RequiredInputError, OutplantSiteChanged> {
  const OutplantSiteInput.pure() : super.pure();
  const OutplantSiteInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Outplant Site';

  @override
  String? get hintText => 'Select site';

  @override
  RequiredInputError? validator(String? value) {
    if (value == null || value.isEmpty) {
      return const RequiredInputError('Select an outplant site');
    }
    return null;
  }

  @override
  OutplantSiteInput copyWith({required String? value}) {
    if (value == null || value.isEmpty) {
      return const OutplantSiteInput.pure();
    }
    if (value == this.value) return this;
    return OutplantSiteInput.dirty(value);
  }
}

class OutplantDateChanged extends RecordFormInputEvent<DateTime?> {
  const OutplantDateChanged(super.value);
}

class OutplantDateInput
    extends RecordFormInput<DateTime, RequiredInputError, OutplantDateChanged> {
  const OutplantDateInput.pure() : super.pure();
  const OutplantDateInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Outplant Date';

  @override
  String? get hintText => 'Pick a date';

  @override
  RequiredInputError? validator(DateTime? value) {
    if (value == null) {
      return const RequiredInputError('Select an outplant date');
    }
    return null;
  }

  @override
  OutplantDateInput copyWith({required DateTime? value}) {
    if (value == null) {
      return const OutplantDateInput.pure();
    }
    if (value == this.value) return this;
    return OutplantDateInput.dirty(value);
  }
}

class OutplantTagMapChanged
    extends RecordFormInputEvent<Map<String, String>?> {
  const OutplantTagMapChanged(super.value);
}

class OutplantTagMapInput extends RecordFormInput<
    Map<String, String>,
    RecordFormInputError,
    OutplantTagMapChanged> {
  const OutplantTagMapInput.pure() : super.pure();
  const OutplantTagMapInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Tags';

  @override
  String? get hintText => 'Optional tag assignments';

  @override
  RecordFormInputError? validator(Map<String, String>? value) {
    return null; // Tags are optional; validation handled elsewhere if needed
  }

  @override
  OutplantTagMapInput copyWith({required Map<String, String>? value}) {
    if (value == null) {
      return const OutplantTagMapInput.pure();
    }
    if (value == this.value) return this;
    return OutplantTagMapInput.dirty(Map<String, String>.from(value));
  }
}

class OutplantGroupMapChanged
    extends RecordFormInputEvent<Map<String, String>?> {
  const OutplantGroupMapChanged(super.value);
}

class OutplantGroupMapInput extends RecordFormInput<
    Map<String, String>,
    RecordFormInputError,
    OutplantGroupMapChanged> {
  const OutplantGroupMapInput.pure() : super.pure();
  const OutplantGroupMapInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Plot/Patch';

  @override
  String? get hintText => 'Optional plot/patch assignments';

  @override
  RecordFormInputError? validator(Map<String, String>? value) {
    return null; // Group assignments are optional
  }

  @override
  OutplantGroupMapInput copyWith({required Map<String, String>? value}) {
    if (value == null) {
      return const OutplantGroupMapInput.pure();
    }
    if (value == this.value) return this;
    return OutplantGroupMapInput.dirty(Map<String, String>.from(value));
  }
}

class OutplantGeometryTextChanged extends RecordFormInputEvent<String?> {
  const OutplantGeometryTextChanged(super.value);
}

class OutplantGeometryTextInput extends RecordFormInput<
    String,
    RecordFormInputError,
    OutplantGeometryTextChanged> {
  const OutplantGeometryTextInput.pure() : super.pure();
  const OutplantGeometryTextInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Geometry Coordinates';

  @override
  String? get hintText => 'lat,lng per line';

  @override
  RecordFormInputError? validator(String? value) {
    return null; // Validation handled during submission when parsed
  }

  @override
  OutplantGeometryTextInput copyWith({required String? value}) {
    if (value == null) {
      return const OutplantGeometryTextInput.pure();
    }
    if (value == this.value) return this;
    return OutplantGeometryTextInput.dirty(value);
  }
}

class OutplantDeliverableChanged extends RecordFormInputEvent<String?> {
  const OutplantDeliverableChanged(super.value);
}

class OutplantDeliverableInput extends RecordFormInput<
    String,
    RecordFormInputError,
    OutplantDeliverableChanged> {
  const OutplantDeliverableInput.pure() : super.pure();
  const OutplantDeliverableInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Deliverable';

  @override
  String? get hintText => 'Optional permit deliverable';

  @override
  RecordFormInputError? validator(String? value) {
    return null; // Deliverable selection is optional
  }

  @override
  OutplantDeliverableInput copyWith({required String? value}) {
    if (value == null || value.isEmpty) {
      return const OutplantDeliverableInput.pure();
    }
    if (value == this.value) return this;
    return OutplantDeliverableInput.dirty(value);
  }
}

class OutplantAttachmentMethodChanged extends RecordFormInputEvent<String?> {
  const OutplantAttachmentMethodChanged(super.value);
}

class OutplantAttachmentMethodInput extends RecordFormInput<
    String,
    RecordFormInputError,
    OutplantAttachmentMethodChanged> {
  const OutplantAttachmentMethodInput.pure() : super.pure();
  const OutplantAttachmentMethodInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Attachment Method';

  @override
  String? get hintText => 'Optional attachment method';

  @override
  RecordFormInputError? validator(String? value) {
    return null; // Attachment method is optional
  }

  @override
  OutplantAttachmentMethodInput copyWith({required String? value}) {
    if (value == null || value.isEmpty) {
      return const OutplantAttachmentMethodInput.pure();
    }
    if (value == this.value) return this;
    return OutplantAttachmentMethodInput.dirty(value);
  }
}
