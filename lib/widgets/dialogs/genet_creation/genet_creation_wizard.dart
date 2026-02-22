// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_creation/genet_details_step.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_creation/review_step.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_creation/type_specific_step.dart';
import 'package:seafoundry_app/widgets/ui.dart';

class GenetCreationWizard extends StatelessWidget {
  const GenetCreationWizard({super.key, required this.state});

  final GenetCreationState state;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(context),
      content: _buildContent(context),
      actions: _buildActions(context),
    );
  }

  Widget _buildTitle(BuildContext context) {
    if (state is! GenetCreationInProgress) {
      return Row(
        children: [
          UI.iconMedium(Icons.fingerprint, color: Colors.purple),
          UI.spacingHorizontalSm,
          const Text('Create New Genet'),
        ],
      );
    }

    final inProgress = state as GenetCreationInProgress;
    final step = inProgress.formState.currentStep;
    final editing = inProgress.isEditing;

    String title;
    switch (step) {
      case 0:
        title = editing ? 'Edit Identity' : 'Identity & Details';
        break;
      case 1:
        title = editing ? 'Update Type Details' : 'Type-Specific Details';
        break;
      case 2:
        title = editing ? 'Review Changes' : 'Review Genet';
        break;
      default:
        title = editing ? 'Edit Genet' : 'Create New Genet';
    }

    if (inProgress.formState.isSubmissionInProgress) {
      title = editing ? 'Saving Changes...' : 'Creating Genet...';
    }

    return Row(
      children: [
        UI.iconMedium(Icons.fingerprint, color: Colors.purple),
        UI.spacingHorizontalSm,
        Text(title),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    Widget body;

    if (state is GenetCreationError) {
      final error = state as GenetCreationError;
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          UI.spacingVerticalMd,
          Text(error.message),
        ],
      );
    } else if (state is! GenetCreationInProgress) {
      body = const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final inProgress = state as GenetCreationInProgress;
      final formState = inProgress.formState;

      if (formState.submissionError != null) {
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            UI.spacingVerticalMd,
            Text(formState.submissionError!),
          ],
        );
      } else if (formState.isSubmissionInProgress) {
        body = const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        );
      } else {
        body = switch (formState.currentStep) {
          0 => GenetDetailsStep(state: inProgress),
          1 => TypeSpecificStep(state: inProgress),
          2 => GenetReviewStep(state: inProgress),
          _ => const SizedBox.shrink(),
        };
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        maxWidth: 600,
      ),
      child: body,
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (state is! GenetCreationInProgress) {
      return [
        TextButton(
          onPressed: () {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Cancel'),
        ),
      ];
    }

    final bloc = context.read<GenetCreationBloc>();
    final inProgress = state as GenetCreationInProgress;
    final formState = inProgress.formState;

    if (formState.submissionError != null) {
      return [
        TextButton(
          onPressed: () {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => bloc.initialize(),
          child: const Text('Try Again'),
        ),
      ];
    }

    if (formState.isSubmissionInProgress) {
      return const [];
    }

    final currentStep = formState.currentStep;
    final canGoBack = currentStep > 0;
    final submitLabel = inProgress.isEditing ? 'Save Changes' : 'Create Genet';

    final canGoNext = () {
      switch (currentStep) {
        case 0:
          // Combined validation for merged step (Species + Details)
          final speciesValid = formState.species.isValid;
          final nameValid =
              formState.name.isValid &&
              (inProgress.nameValidationError == null);
          return speciesValid &&
              nameValid &&
              formState.provenanceType.isValid &&
              formState.lifeStage.isValid &&
              formState.clonalId.isValid &&
              formState.accessionNumber.isValid;
        case 1:
          return formState.isTypeSpecificValid;
        default:
          return false;
      }
    }();

    return [
      TextButton(
        onPressed: () {
          if (canGoBack) {
            bloc.onPreviousStep();
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Text(canGoBack ? 'Back' : 'Cancel'),
      ),
      if (currentStep == 2)
        ElevatedButton(
          onPressed: formState.isFormValid ? () => bloc.submit() : null,
          child: Text(submitLabel),
        )
      else if (canGoNext)
        ElevatedButton(
          onPressed: () => bloc.onNextStep(),
          child: const Text('Next'),
        ),
    ];
  }
}
