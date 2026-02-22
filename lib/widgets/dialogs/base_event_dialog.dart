// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:seafoundry_app/widgets/forms/base_create_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Base dialog for all event creation
abstract class BaseEventDialog<
  E extends Event,
  B extends EventFormBloc<E, S>,
  S extends EventFormState<E>
>
    extends BaseCreateDialog<E, B, S> {
  const BaseEventDialog({super.key});

  /// Show task creation option
  bool get showTaskOption => false;

  @override
  Widget buildContent(BuildContext context, S state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event-specific content
        ...buildEventContent(context, state),

        // Common options
        if (showTaskOption) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('Options', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
        ],

        // Task creation toggle
        if (showTaskOption) _buildTaskToggle(context, state),
      ],
    );
  }

  /// Build event-specific content
  List<Widget> buildEventContent(BuildContext context, S state);

  Widget _buildTaskToggle(BuildContext context, S state) {
    final bloc = context.read<B>();
    if (!bloc.allowTaskCreation) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Follow-up Task'),
                Text(
                  'Create a task for future action',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: bloc.createTask,
            onChanged: (value) {
              bloc.add(EventFormTaskToggled(value));
            },
          ),
        ],
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context, S state) {
    final isEditing = state.isEditing;
    return [
      TextButton(
        onPressed: state.submissionStatus == FormzSubmissionStatus.inProgress
            ? null
            : () => popSafeDialogContext(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: state.submissionStatus == FormzSubmissionStatus.inProgress
            ? null
            : () => context.read<B>().add(const RecordFormSubmit()),
        child: state.submissionStatus == FormzSubmissionStatus.inProgress
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(isEditing ? 'Update Event' : 'Create Event'),
      ),
    ];
  }

  /// Static show method to be implemented by subclasses.
  ///
  /// **IMPORTANT**: Always capture providers BEFORE showDialog and use
  /// `useRootNavigator: false` to stay within provider scope.
  ///
  /// Example:
  /// ```dart
  /// static Future<FeedingEvent?> show(
  ///   BuildContext context, {
  ///   required GraphNode targetNode,
  /// }) {
  ///   // 1. Read dependencies BEFORE showDialog to ensure provider scope
  ///   final eventRepository = context.read<EventRepository>();
  ///   final propagationService = context.read<EventPropagationService>();
  ///
  ///   // 2. Use showDialog with useRootNavigator: false
  ///   return showDialog<FeedingEvent>(
  ///     context: context,
  ///     barrierDismissible: false,
  ///     useRootNavigator: false, // Stay in provider scope
  ///     builder: (_) => BlocProvider(
  ///       create: (_) => FeedingFormBloc(
  ///         eventRepository: eventRepository,
  ///         propagationService: propagationService,
  ///         targetNode: targetNode,
  ///       )..add(EventFormTargetChanged(targetNode)),
  ///       child: const FeedingEventDialog(),
  ///     ),
  ///   );
  /// }
  /// ```
}
