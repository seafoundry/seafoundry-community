import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/models/graph/graph_node_streams.dart';
import 'package:seafoundry_app/models/graph/graph_node_events.dart';
import 'package:seafoundry_app/cubits/group_creation/group_creation_bloc.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/group/group.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Group creation dialog implementation.
///
/// This widget displays a multi-step wizard for creating or editing groups,
/// using the [GroupCreationBloc] for state management. Steps include:
/// - Group type selection
/// - Group details (name, description, capacity)
/// - Review and submission
///
/// Integrates with [StructureCapacityService] to prevent over-capacity
/// situations when creating nested groups.
class GroupCreationDialog extends StatefulWidget {
  const GroupCreationDialog({super.key, required this.parentNode});

  final GraphNode parentNode;

  @override
  State<GroupCreationDialog> createState() => _GroupCreationDialogState();
}

class _GroupCreationDialogState extends State<GroupCreationDialog>
    with SafeDialogMixin<GroupCreationDialog> {
  StructureCapacityResult? _capacityResult;
  bool _isCapacityLoading = false;
  bool _capacityRequestInFlight = false;
  String? _pendingCapacityKey;

  void _maybeEvaluateCapacity(BuildContext context, GroupFormState state) {
    final onReviewStep = state.currentStep is RecordFormReviewStep;
    final childType = state.groupType.value;
    final parentRecord = widget.parentNode.initialRecord;
    if (!onReviewStep || childType == null || parentRecord is! Group) {
      if (_capacityResult != null ||
          _isCapacityLoading ||
          _capacityRequestInFlight) {
        _pendingCapacityKey = null;
        _capacityRequestInFlight = false;
        _scheduleCapacityStateUpdate(() {
          _capacityResult = null;
          _isCapacityLoading = false;
        });
      }
      return;
    }

    final key =
        '${parentRecord.id}:${childType.id}:${state.originalRecord?.id ?? ''}';
    if (_pendingCapacityKey == key &&
        (_capacityRequestInFlight || _capacityResult != null)) {
      return;
    }
    _pendingCapacityKey = key;
    _capacityRequestInFlight = true;
    _scheduleCapacityStateUpdate(() {
      _isCapacityLoading = true;
      _capacityResult = null;
    });
    final repository = context.read<GroupRepository>();
    repository
        .previewChildCapacity(
          parent: parentRecord,
          childTypeId: childType.id,
          excludeRecordId: state.originalRecord?.id,
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        )
        .then((result) {
          if (!mounted) return;
          if (_pendingCapacityKey != key) return;
          _capacityRequestInFlight = false;
          setState(() {
            _capacityResult = result;
            _isCapacityLoading = false;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          if (_pendingCapacityKey != key) return;
          _capacityRequestInFlight = false;
          setState(() {
            _capacityResult = null;
            _isCapacityLoading = false;
          });
        });
  }

  void _scheduleCapacityStateUpdate(VoidCallback update) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(update);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupCreationBloc, GroupFormState>(
      listener: (context, state) {
        if (state.submissionStatus == FormzSubmissionStatus.success) {
          if (!widget.parentNode.isClosed) {
            widget.parentNode.add(const GraphNodeReloadRequested());
          }
          popDialog();
        }
      },
      builder: (context, state) {
        _maybeEvaluateCapacity(context, state);
        return AlertDialog(
          scrollable: true,
          title: _buildTitle(context, state),
          content: _buildContent(context, state),
          actions: _buildActions(context, state),
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context, GroupFormState state) {
    return Row(
      children: [
        UI.iconMedium(Icons.folder, color: AppColors.groupColor),
        UI.spacingHorizontalSm,
        Expanded(
          child: Text(
            state.submissionStatus == FormzSubmissionStatus.inProgress
                ? (state.isEditing ? 'Updating Group...' : 'Creating Group...')
                : (state.isEditing ? 'Edit Group' : state.currentStep.title),
          ),
        ),
        if (state.submissionStatus != FormzSubmissionStatus.inProgress)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => popDialog(),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, GroupFormState state) {
    if (state.submissionError != null) {
      return SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            UI.spacingVerticalMd,
            Text(state.submissionError!),
          ],
        ),
      );
    }

    if (state.submissionStatus == FormzSubmissionStatus.inProgress) {
      return const SizedBox(
        width: 400,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.currentStep is RecordFormReviewStep) {
      return GroupReviewStepWidget(
        formState: state,
        parentNode: widget.parentNode,
        capacityResult: _capacityResult,
        isCapacityLoading: _isCapacityLoading,
      );
    } else if (state.currentStep == state.steps.first) {
      return GroupTypeSelectionStepWidget(
        formState: state,
        parentNode: widget.parentNode,
      );
    } else {
      return GroupDetailsStepWidget(formState: state);
    }
  }

  List<Widget> _buildActions(BuildContext context, GroupFormState state) {
    final bloc = context.read<GroupCreationBloc>();
    if (state.submissionError != null) {
      return [
        TextButton(
          onPressed: () => popDialog(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            bloc.add(const RecordFormReset());
          },
          child: const Text('Try Again'),
        ),
      ];
    }

    if (state.submissionStatus == FormzSubmissionStatus.inProgress) {
      return [];
    }

    return [
      TextButton(
        onPressed: () {
          if (state.canGoBack) {
            bloc.add(const RecordFormPreviousStep());
          } else {
            popDialog();
          }
        },
        child: Text(state.canGoBack ? 'Back' : 'Cancel'),
      ),
      if (state.currentStep is RecordFormReviewStep)
        ElevatedButton(
          onPressed: _canSubmitGroup(state)
              ? () => bloc.add(const RecordFormSubmit())
              : null,
          child: Text(state.isEditing ? 'Update Group' : 'Create Group'),
        )
      else if (!state.isLastStep)
        ElevatedButton(
          onPressed: state.canGoForward
              ? () => bloc.add(const RecordFormNextStep())
              : null,
          child: const Text('Next'),
        ),
    ];
  }

  bool _canSubmitGroup(GroupFormState state) {
    if (_isCapacityLoading) return false;
    if (_capacityResult?.isOverCapacity == true) return false;
    return true;
  }
}
