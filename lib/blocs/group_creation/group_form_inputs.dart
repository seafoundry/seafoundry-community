// @tier: community
import 'package:seafoundry_app/blocs/group_creation/group_creation_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/models/types/group_type.dart';

class GroupTypeSelection
    extends RecordFormInput<GroupType?, RequiredInputError, GroupTypeSelected> {
  const GroupTypeSelection.pure() : super.pure();
  const GroupTypeSelection.dirty([super.value]) : super.dirty();

  @override
  String get label => 'Group Type';

  @override
  String? get hintText => 'Select the type of group';

  @override
  GroupTypeSelection copyWith({required GroupType? value}) {
    if (value == this.value) return this;
    if (value == null) return GroupTypeSelection.pure();
    return GroupTypeSelection.dirty(value);
  }
}

class GroupDescription
    extends
        RecordFormInput<String, RecordFormInputError, GroupDescriptionChanged> {
  const GroupDescription.pure() : super.pure();
  const GroupDescription.dirty(super.value) : super.dirty();

  @override
  String get label => 'Description';

  @override
  String? get hintText => 'Enter a description (optional)';

  @override
  RecordFormInputError? validator(String? value) {
    if (value != null && value.length > 500) {
      return RecordFormInputError(
        'Description must be less than 500 characters',
      );
    }
    return null;
  }

  @override
  GroupDescription copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null) return GroupDescription.pure();
    return GroupDescription.dirty(value);
  }
}

class GroupCapacity
    extends RecordFormInput<int, RecordFormInputError, GroupCapacityChanged> {
  const GroupCapacity.pure() : super.pure();
  const GroupCapacity.dirty(super.value) : super.dirty();

  @override
  String get label => 'Capacity';

  @override
  String? get hintText => 'Maximum number of corals (optional)';

  @override
  RecordFormInputError? validator(int? value) {
    if (value == null) return null;
    if (value < 0) {
      return RecordFormInputError('Capacity must be greater than zero');
    }
    if (value > 1000) {
      return RecordFormInputError('Capacity must be less than 1000');
    }
    return null;
  }

  @override
  GroupCapacity copyWith({required int? value}) {
    if (value == this.value) return this;
    if (value == null) return GroupCapacity.pure();
    return GroupCapacity.dirty(value);
  }
}
