import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/group_creation/group_creation_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Group details step widget for the group creation dialog.
///
/// Collects the group name, description (optional), and capacity (optional).
/// Includes validation feedback for the required name field.
class GroupDetailsStepWidget extends StatelessWidget {
  const GroupDetailsStepWidget({
    super.key,
    required this.formState,
  });

  final GroupFormState formState;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GroupCreationBloc>();
    final groupTypeName =
        formState.groupType.value?.name.toLowerCase() ?? 'group';

    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UIText.bodyMedium('Enter details for your $groupTypeName:'),
          UI.spacingVerticalMd,
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Group Name',
              hintText: 'Enter group name',
              prefixIcon: const Icon(Icons.folder),
              border: const OutlineInputBorder(),
              errorText: formState.name.displayError?.message,
            ),
            initialValue: formState.name.value,
            onChanged: (value) {
              bloc.add(RecordNameChanged(value));
            },
            autofocus: true,
          ),
          UI.spacingVerticalMd,
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Enter group description',
              prefixIcon: const Icon(Icons.description),
              border: const OutlineInputBorder(),
              errorText: formState.description.displayError?.message,
            ),
            initialValue: formState.description.value,
            maxLines: 3,
            onChanged: (value) {
              bloc.add(GroupDescriptionChanged(value));
            },
          ),
          UI.spacingVerticalMd,
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Capacity (optional)',
              hintText: 'Enter maximum capacity',
              prefixIcon: const Icon(Icons.groups),
              border: const OutlineInputBorder(),
              errorText: formState.capacity.displayError?.message,
            ),
            initialValue: formState.capacity.value?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final capacity = int.tryParse(value) ?? 0;
              bloc.add(GroupCapacityChanged(capacity));
            },
          ),
        ],
      ),
    );
  }
}
