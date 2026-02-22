// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/spacing.dart';

/// Configuration for a step in the multi-step form
class FormStep {
  final String title;
  final String? subtitle;
  final Widget content;
  final bool isValid;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const FormStep({
    required this.title,
    this.subtitle,
    required this.content,
    required this.isValid,
    this.onNext,
    this.onPrevious,
  });
}

/// Configuration for the multi-step form
class MultiStepFormConfig {
  final Color primaryColor;
  final double indicatorSize;
  final double connectorWidth;
  final double connectorHeight;
  final EdgeInsets contentPadding;

  const MultiStepFormConfig({
    this.primaryColor = Colors.blue,
    this.indicatorSize = 24,
    this.connectorWidth = 40,
    this.connectorHeight = 2,
    this.contentPadding = const EdgeInsets.all(16),
  });
}

/// Multi-step form widget with progress indicator
class MultiStepForm extends StatelessWidget {
  final List<FormStep> steps;
  final int currentStep;
  final MultiStepFormConfig config;
  final bool showIndicator;
  final Widget? header;
  final Widget? footer;

  const MultiStepForm({
    super.key,
    required this.steps,
    required this.currentStep,
    this.config = const MultiStepFormConfig(),
    this.showIndicator = true,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        if (showIndicator) ...[_buildStepIndicator(), SizedBox(height: Spacing.lg)],
        Flexible(
          child: Padding(padding: config.contentPadding, child: _buildStepContent()),
        ),
        if (footer != null) footer!,
      ],
    );
  }

  Widget _buildStepIndicator() {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isEven) {
          // Step indicator
          final stepIndex = index ~/ 2;
          return _buildStepCircle(stepIndex);
        } else {
          // Connector
          final stepIndex = index ~/ 2;
          return _buildConnector(stepIndex);
        }
      }),
    );
  }

  Widget _buildStepCircle(int stepIndex) {
    final safeStep = _safeStepIndex;
    final isActive = stepIndex == safeStep;
    final isCompleted = stepIndex < safeStep;

    Color backgroundColor;
    Color textColor;
    Widget child;

    if (isCompleted) {
      backgroundColor = config.primaryColor;
      textColor = Colors.white;
      child = Icon(Icons.check, size: config.indicatorSize * 0.6, color: textColor);
    } else if (isActive) {
      backgroundColor = config.primaryColor;
      textColor = Colors.white;
      child = Text(
        '${stepIndex + 1}',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: config.indicatorSize * 0.5),
      );
    } else {
      backgroundColor = Colors.grey.shade300;
      textColor = Colors.grey.shade600;
      child = Text(
        '${stepIndex + 1}',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: config.indicatorSize * 0.5),
      );
    }

    return Container(
      width: config.indicatorSize,
      height: config.indicatorSize,
      decoration: BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
      child: Center(child: child),
    );
  }

  Widget _buildConnector(int stepIndex) {
    final isCompleted = stepIndex < _safeStepIndex;

    return Container(
      width: config.connectorWidth,
      height: config.connectorHeight,
      color: isCompleted ? config.primaryColor : Colors.grey.shade300,
    );
  }

  Widget _buildStepContent() {
    final step = steps[_safeStepIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (step.subtitle != null) ...[
          Text(
            step.subtitle!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Spacing.md),
        ],
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              child: step.content,
            ),
          ),
        ),
      ],
    );
  }

  int get _safeStepIndex {
    if (steps.isEmpty) return 0;
    if (currentStep < 0) return 0;
    if (currentStep >= steps.length) return steps.length - 1;
    return currentStep;
  }
}

/// Widget for form step navigation buttons
class StepNavigationButtons extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool canGoNext;
  final bool canGoBack;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final String? nextLabel;
  final String? backLabel;
  final String? cancelLabel;
  final String? submitLabel;
  final bool isLoading;

  const StepNavigationButtons({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.canGoNext = true,
    this.canGoBack = true,
    this.onNext,
    this.onPrevious,
    this.onCancel,
    this.onSubmit,
    this.nextLabel,
    this.backLabel,
    this.cancelLabel,
    this.submitLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.shrink();
    }

    final isLastStep = currentStep == totalSteps - 1;
    final shouldShowBack = canGoBack && currentStep > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: shouldShowBack ? onPrevious : onCancel,
          child: Text(shouldShowBack ? (backLabel ?? 'Back') : (cancelLabel ?? 'Cancel')),
        ),
        if (isLastStep)
          ElevatedButton(onPressed: canGoNext ? onSubmit : null, child: Text(submitLabel ?? 'Submit'))
        else
          ElevatedButton(onPressed: canGoNext ? onNext : null, child: Text(nextLabel ?? 'Next')),
      ],
    );
  }
}

/// Helper class for building multi-step forms
class MultiStepFormBuilder {
  final List<FormStep> _steps = [];
  final MultiStepFormConfig _config;

  MultiStepFormBuilder({MultiStepFormConfig? config}) : _config = config ?? const MultiStepFormConfig();

  /// Add a step to the form
  MultiStepFormBuilder addStep({
    required String title,
    String? subtitle,
    required Widget content,
    required bool isValid,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
  }) {
    _steps.add(
      FormStep(
        title: title,
        subtitle: subtitle,
        content: content,
        isValid: isValid,
        onNext: onNext,
        onPrevious: onPrevious,
      ),
    );
    return this;
  }

  /// Build the multi-step form
  MultiStepForm build({required int currentStep, bool showIndicator = true, Widget? header, Widget? footer}) {
    return MultiStepForm(
      steps: List.unmodifiable(_steps),
      currentStep: currentStep,
      config: _config,
      showIndicator: showIndicator,
      header: header,
      footer: footer,
    );
  }

  /// Get the number of steps
  int get stepCount => _steps.length;

  /// Get a specific step
  FormStep getStep(int index) => _steps[index];

  /// Check if all steps are valid up to a certain index
  bool areStepsValidUpTo(int index) {
    for (int i = 0; i <= index; i++) {
      if (!_steps[i].isValid) return false;
    }
    return true;
  }
}
