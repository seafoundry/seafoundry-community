// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// A horizontal step progress indicator for multi-step workflows.
///
/// Displays a series of numbered steps connected by lines, with visual states
/// indicating completed, active, and upcoming steps. Completed steps can be
/// tapped to navigate backward in the workflow.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
    this.onStepTapped,
  });

  /// List of step labels
  final List<String> steps;

  /// Current step index (0-based)
  final int currentStep;

  /// Callback when a completed step is tapped (for navigation)
  final void Function(int)? onStepTapped;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _StepItem(
                    label: steps[i],
                    stepNumber: i + 1,
                    state: _getStepState(i),
                    isFirst: i == 0,
                    isLast: i == steps.length - 1,
                    onTap: () => _handleStepTap(i),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  _StepState _getStepState(int index) {
    if (index < currentStep) return _StepState.completed;
    if (index == currentStep) return _StepState.active;
    return _StepState.upcoming;
  }

  void _handleStepTap(int index) {
    // Only allow navigation to completed steps
    if (index < currentStep && onStepTapped != null) {
      onStepTapped!(index);
    }
  }
}

enum _StepState { completed, active, upcoming }

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.label,
    required this.stepNumber,
    required this.state,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final int stepNumber;
  final _StepState state;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = state == _StepState.completed;

    return InkWell(
      onTap: canTap ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step indicator row with connecting lines
          Row(
            children: [
              // Left line
              if (!isFirst)
                Expanded(
                  child: Container(
                    height: 2,
                    color: state == _StepState.upcoming
                        ? AppColors.disabled
                        : AppColors.success,
                  ),
                )
              else
                const Spacer(),
              // Circle with number or checkmark
              _buildCircle(),
              // Right line
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: state == _StepState.active ||
                            state == _StepState.upcoming
                        ? AppColors.disabled
                        : AppColors.success,
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  state == _StepState.active ? FontWeight.bold : FontWeight.normal,
              color: _getLabelColor(),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCircle() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getCircleColor(),
        border: Border.all(
          color: _getBorderColor(),
          width: 2,
        ),
      ),
      child: Center(
        child: state == _StepState.completed
            ? const Icon(
                Icons.check,
                size: 18,
                color: Colors.white,
              )
            : Text(
                stepNumber.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getNumberColor(),
                ),
              ),
      ),
    );
  }

  Color _getCircleColor() {
    switch (state) {
      case _StepState.completed:
        return AppColors.success;
      case _StepState.active:
        return AppColors.primary;
      case _StepState.upcoming:
        return Colors.white;
    }
  }

  Color _getBorderColor() {
    switch (state) {
      case _StepState.completed:
        return AppColors.success;
      case _StepState.active:
        return AppColors.primary;
      case _StepState.upcoming:
        return AppColors.disabled;
    }
  }

  Color _getNumberColor() {
    switch (state) {
      case _StepState.completed:
        return Colors.white;
      case _StepState.active:
        return Colors.white;
      case _StepState.upcoming:
        return AppColors.textSecondary;
    }
  }

  Color _getLabelColor() {
    switch (state) {
      case _StepState.completed:
        return AppColors.textPrimary;
      case _StepState.active:
        return AppColors.primary;
      case _StepState.upcoming:
        return AppColors.textSecondary;
    }
  }
}
