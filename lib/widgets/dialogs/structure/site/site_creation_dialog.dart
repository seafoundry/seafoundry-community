import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_community/models/graph/graph_node_events.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_community/cubits/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/models/types/site_type.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';
import 'package:seafoundry_community/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_community/widgets/dialogs/structure/site/site.dart';
import 'package:seafoundry_community/widgets/ui.dart';

/// Site creation dialog implementation.
///
/// This widget displays a multi-step wizard for creating or editing sites,
/// using the [SiteCreationBloc] for state management. Steps include:
/// - Site type selection
/// - Site details (name, description)
/// - Group types configuration
/// - Review and submission
class SiteCreationDialog extends StatefulWidget {
  const SiteCreationDialog({
    super.key,
    required this.organization,
    required this.graphRepository,
    required this.availableSiteTypes,
  });

  final Organization organization;
  final GraphRepository graphRepository;
  final List<SiteType> availableSiteTypes;

  @override
  State<SiteCreationDialog> createState() => _SiteCreationDialogState();
}

class _SiteCreationDialogState extends State<SiteCreationDialog>
    with SafeDialogMixin<SiteCreationDialog> {
  @override
  Widget build(BuildContext context) {
    final organizationNode = widget.graphRepository.root;
    return BlocConsumer<SiteCreationBloc, SiteFormState>(
      listener: (context, state) {
        if (state.submissionStatus == FormzSubmissionStatus.success) {
          organizationNode.add(const GraphNodeReloadRequested());
          if (state.createdRecord case final site?) {
            widget.graphRepository
                .getNodeForUrlPath(site.urlPath)
                .then((node) => node?.add(const GraphNodeLoadRequested()));
          }
          popDialog(state.createdRecord);
        }
      },
      builder: (context, state) {
        return AlertDialog(
          scrollable: true,
          title: _buildTitle(context, state),
          content: _buildContent(context, state),
          actions: _buildActions(context, state),
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context, SiteFormState state) {
    return Row(
      children: [
        UI.iconMedium(Icons.location_on, color: Colors.green),
        UI.spacingHorizontalSm,
        Expanded(
          child: Text(
            state.submissionStatus == FormzSubmissionStatus.inProgress
                ? (state.isEditing ? 'Updating Site...' : 'Creating Site...')
                : (state.isEditing ? 'Edit Site' : state.currentStep.title),
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

  Widget _buildContent(BuildContext context, SiteFormState state) {
    if (state.submissionError != null) {
      return SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
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

    switch (state.currentStep.runtimeType) {
      case const (SiteSelectTypeStep):
        return SiteTypeSelectionStep(
          formState: state,
          availableSiteTypes: widget.availableSiteTypes,
        );
      case const (SiteDetailsStep):
        return SiteDetailsStepWidget(
          formState: state,
          organization: widget.organization,
        );
      case const (SiteGroupTypesStep):
        return SiteGroupTypesStepWidget(
          formState: state,
          organization: widget.organization,
        );
      case const (RecordFormReviewStep):
        return SiteReviewStepWidget(
          formState: state,
          organization: widget.organization,
        );
    }

    return const SizedBox.shrink();
  }

  List<Widget> _buildActions(BuildContext context, SiteFormState state) {
    if (widget.availableSiteTypes.isEmpty) {
      return [
        TextButton(
          onPressed: () => popDialog(),
          child: const Text('Close'),
        ),
      ];
    }

    final bloc = context.read<SiteCreationBloc>();

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
          onPressed: state.isValid
              ? () => bloc.add(const RecordFormSubmit())
              : null,
          child: Text(state.isEditing ? 'Save Site' : 'Create Site'),
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
}
