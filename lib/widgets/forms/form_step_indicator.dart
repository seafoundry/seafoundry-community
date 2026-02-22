// @tier: community
import 'package:flutter/material.dart';

class FormStepIndicator extends StatelessWidget {
  const FormStepIndicator({super.key, required this.totalSteps, required this.currentStep, required this.iconColor});
  final int totalSteps;
  final int currentStep;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;

        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive || isCompleted ? iconColor : Colors.grey.shade300,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
            if (index < totalSteps - 1)
              Container(width: 40, height: 2, color: index < currentStep ? iconColor : Colors.grey.shade300),
          ],
        );
      }),
    );
  }
}
