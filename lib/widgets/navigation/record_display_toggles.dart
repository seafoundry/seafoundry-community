// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/record_display_preferences/record_display_preferences_cubit.dart';

/// Toggle buttons for controlling how organism records are displayed.
///
/// Provides two toggles:
/// 1. UUID/Name toggle: Switch between showing recordName and recordUUID
/// 2. Show/Hide toggle: Hide all record identifiers entirely
class RecordDisplayToggles extends StatelessWidget {
  const RecordDisplayToggles({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordDisplayPreferencesCubit,
        RecordDisplayPreferencesState>(
      builder: (context, state) {
        final cubit = context.read<RecordDisplayPreferencesCubit>();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // UUID/Name toggle
            Tooltip(
              message: state.showUuid
                  ? 'Showing UUIDs - Click to show names'
                  : 'Showing names - Click to show UUIDs',
              child: IconButton(
                icon: Icon(
                  state.showUuid ? Icons.tag : Icons.badge,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: cubit.toggleShowUuid,
                visualDensity: VisualDensity.compact,
              ),
            ),
            // Show/Hide identifier toggle
            Tooltip(
              message: state.showIdentifier
                  ? 'Identifiers visible - Click to hide'
                  : 'Identifiers hidden - Click to show',
              child: IconButton(
                icon: Icon(
                  state.showIdentifier
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: cubit.toggleShowIdentifier,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        );
      },
    );
  }
}
