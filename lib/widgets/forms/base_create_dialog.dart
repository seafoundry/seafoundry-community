// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/components/core/action_button.dart';
import 'package:seafoundry_app/components/core/empty_state.dart';
import 'package:seafoundry_app/components/core/loading_indicator.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_primary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';

import 'form_step_indicator.dart';
import '../dialogs/components/dialog_scroll_view.dart';

/// Configuration for create dialog appearance
class CreateDialogConfig {
  final String title;
  final IconData icon;
  final Color iconColor;
  final double width;
  final bool barrierDismissible;

  const CreateDialogConfig({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.width = 400,
    this.barrierDismissible = false,
  });
}

/// Base create dialog widget with common structure
abstract class BaseCreateDialog<
  T extends Record,
  B extends RecordFormBloc<T, S>,
  S extends RecordFormState<T>
>
    extends StatelessWidget {
  const BaseCreateDialog({super.key});

  ModelType get modelType;

  /// Configuration for this dialog
  CreateDialogConfig get config;

  /// Build the main content based on state
  Widget buildContent(BuildContext context, S state);

  /// Build the action buttons based on state
  List<Widget> buildActions(BuildContext context, S state);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, S>(
      listener: (context, state) {
        if (state.submissionStatus == FormzSubmissionStatus.success) {
          popSafeDialogContext(context, state.createdRecord);
        }
      },
      builder: (context, state) {
        return OceanicDialog(
          title: _getTitle(state),
          icon: config.icon,
          iconColor: config.iconColor,
          width: config.width,
          content: _buildContentContainer(context, state),
          actions: buildActions(context, state),
        );
      },
    );
  }

  String _getTitle(S state) {
    String title = config.title;
    if (state.isEditing) {
      // Replace "Record" with "Edit" or "Create" with "Edit" for edit mode
      title = title
          .replaceFirst('Record', 'Edit')
          .replaceFirst('Create', 'Edit');
    }
    return title;
  }

  Widget _buildContentContainer(BuildContext context, S state) {
    Widget content;

    if (state.submissionStatus == FormzSubmissionStatus.failure) {
      content = EmptyState.error(
        title: 'Creation Failed',
        subtitle: state.submissionError,
      );
    } else if (state.submissionStatus == FormzSubmissionStatus.inProgress) {
      content = LoadingIndicator.large(message: 'Creating...');
    } else {
      content = buildContent(context, state);
    }

    return SizedBox(width: config.width, child: content);
  }
}

/// Multi-step create dialog base class
abstract class MultiStepCreateDialog<
  T extends Record,
  B extends RecordFormBloc<T, S>,
  S extends RecordFormState<T>
>
    extends BaseCreateDialog<T, B, S> {
  const MultiStepCreateDialog({super.key});

  /// Build content for a specific step
  Widget buildStepContent(BuildContext context, S state);

  @override
  Widget buildContent(BuildContext context, S state) {
    if (state.submissionStatus == FormzSubmissionStatus.inProgress ||
        state.submissionStatus == FormzSubmissionStatus.failure) {
      return super._buildContentContainer(context, state);
    }

    return DialogScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormStepIndicator(
            totalSteps: state.steps.length,
            currentStep: state.steps.indexOf(state.currentStep),
            iconColor: config.iconColor,
          ),
          SizedBox(height: Spacing.lg),
          buildStepContent(context, state),
        ],
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context, S state) {
    if (state.submissionStatus == FormzSubmissionStatus.failure) {
      return [
        ActionButton.text(
          label: 'Cancel',
          onPressed: () => popSafeDialogContext(context),
        ),
        ActionButton.primary(
          label: 'Try Again',
          onPressed: () => onRetry(context),
        ),
      ];
    }

    if (state.submissionStatus == FormzSubmissionStatus.inProgress) {
      return [];
    }
    final bloc = context.read<B>();

    return [
      OceanicSecondaryButton(
        label: state.canGoBack ? 'Back' : 'Cancel',
        onPressed: () {
          if (state.canGoBack) {
            bloc.add(const RecordFormPreviousStep());
          } else {
            popSafeDialogContext(context);
          }
        },
      ),
      if (state.isLastStep)
        OceanicPrimaryButton(
          label: getSubmitButtonLabel(),
          onPressed: state.isValid
              ? () => bloc.add(const RecordFormSubmit())
              : null,
        )
      else if (!state.isLastStep)
        OceanicPrimaryButton(
          label: 'Next',
          onPressed: state.canGoForward
              ? () => bloc.add(const RecordFormNextStep())
              : null,
        ),
    ];
  }

  /// Override to customize the submit button label
  String getSubmitButtonLabel() => 'Create';

  /// Handle retry action after error
  void onRetry(BuildContext context) {
    // Override in subclasses
  }
}

/// Simple create dialog base class (single step)
abstract class SimpleCreateDialog<
  T extends Record,
  B extends RecordFormBloc<T, S>,
  S extends RecordFormState<T>
>
    extends BaseCreateDialog<T, B, S> {
  const SimpleCreateDialog({super.key});

  /// Handle form cancellation
  void onCancel(BuildContext context) {
    popSafeDialogContext(context);
  }

  @override
  List<Widget> buildActions(BuildContext context, S state) {
    if (state.submissionStatus == FormzSubmissionStatus.failure) {
      return [
        ActionButton.text(label: 'Cancel', onPressed: () => onCancel(context)),
        ActionButton.primary(
          label: 'Try Again',
          onPressed: () => onRetry(context),
        ),
      ];
    }

    if (state.submissionStatus == FormzSubmissionStatus.inProgress) {
      return [];
    }

    final bloc = context.read<B>();

    return [
      OceanicSecondaryButton(
        label: 'Cancel',
        onPressed: () => onCancel(context),
      ),
      OceanicPrimaryButton(
        label: getSubmitButtonLabel(),
        onPressed: state.isValid
            ? () => bloc.add(const RecordFormSubmit())
            : null,
      ),
    ];
  }

  /// Override to customize the submit button label
  String getSubmitButtonLabel() => 'Create';

  /// Handle retry action after error
  void onRetry(BuildContext context) {
    // Override in subclasses
  }
}