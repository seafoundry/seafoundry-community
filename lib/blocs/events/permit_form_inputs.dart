// @tier: community
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';

/// Record-form inputs for optional permit metadata fields shared across event
/// dialogs. Each input is optional and simply captures trimmed user values so
/// downstream blocs can assemble an [EventPermitMetadata].

class PermitIdChanged extends RecordFormInputEvent<String?> {
  const PermitIdChanged(super.value);
}

class PermitTypeChanged extends RecordFormInputEvent<String?> {
  const PermitTypeChanged(super.value);
}

class IssuingAuthorityChanged extends RecordFormInputEvent<String?> {
  const IssuingAuthorityChanged(super.value);
}

class PermitValidFromChanged extends RecordFormInputEvent<DateTime?> {
  const PermitValidFromChanged(super.value);
}

class PermitValidToChanged extends RecordFormInputEvent<DateTime?> {
  const PermitValidToChanged(super.value);
}

class PermitAttachmentUrlsChanged extends RecordFormInputEvent<String?> {
  const PermitAttachmentUrlsChanged(super.value);
}

class PermitIdInput
    extends RecordFormInput<String, RecordFormInputError, PermitIdChanged> {
  const PermitIdInput.pure() : super.pure();
  const PermitIdInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Permit ID';

  @override
  String? get hintText => 'Enter permit identifier (optional)';

  @override
  RecordFormInputError? validator(String? value) => null;

  @override
  PermitIdInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? const PermitIdInput.pure()
        : PermitIdInput.dirty(trimmed);
  }
}

class PermitTypeInput
    extends RecordFormInput<String, RecordFormInputError, PermitTypeChanged> {
  const PermitTypeInput.pure() : super.pure();
  const PermitTypeInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Permit Type';

  @override
  String? get hintText => 'e.g., Collection, Outplant, Research';

  @override
  RecordFormInputError? validator(String? value) => null;

  @override
  PermitTypeInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? const PermitTypeInput.pure()
        : PermitTypeInput.dirty(trimmed);
  }
}

class IssuingAuthorityInput
    extends
        RecordFormInput<String, RecordFormInputError, IssuingAuthorityChanged> {
  const IssuingAuthorityInput.pure() : super.pure();
  const IssuingAuthorityInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Issuing Authority';

  @override
  String? get hintText => 'Agency, permitting office, or jurisdiction';

  @override
  RecordFormInputError? validator(String? value) => null;

  @override
  IssuingAuthorityInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? const IssuingAuthorityInput.pure()
        : IssuingAuthorityInput.dirty(trimmed);
  }
}

class PermitValidFromInput
    extends
        RecordFormInput<
          DateTime,
          RecordFormInputError,
          PermitValidFromChanged
        > {
  const PermitValidFromInput.pure() : super.pure();
  const PermitValidFromInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Permit Valid From';

  @override
  String? get hintText => 'Select start date';

  @override
  RecordFormInputError? validator(DateTime? value) => null;

  @override
  PermitValidFromInput copyWith({required DateTime? value}) {
    return value == null
        ? const PermitValidFromInput.pure()
        : PermitValidFromInput.dirty(value);
  }
}

class PermitValidToInput
    extends
        RecordFormInput<DateTime, RecordFormInputError, PermitValidToChanged> {
  const PermitValidToInput.pure() : super.pure();
  const PermitValidToInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Permit Valid To';

  @override
  String? get hintText => 'Select end date';

  @override
  RecordFormInputError? validator(DateTime? value) => null;

  @override
  PermitValidToInput copyWith({required DateTime? value}) {
    return value == null
        ? const PermitValidToInput.pure()
        : PermitValidToInput.dirty(value);
  }
}

class PermitAttachmentUrlsInput
    extends
        RecordFormInput<
          String,
          RecordFormInputError,
          PermitAttachmentUrlsChanged
        > {
  const PermitAttachmentUrlsInput.pure() : super.pure();
  const PermitAttachmentUrlsInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Attachment URLs';

  @override
  String? get hintText => 'One URL per line (optional)';

  @override
  RecordFormInputError? validator(String? value) => null;

  @override
  PermitAttachmentUrlsInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? const PermitAttachmentUrlsInput.pure()
        : PermitAttachmentUrlsInput.dirty(trimmed);
  }
}
