import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/onboarding/five_axis_education_widget.dart';

class EducationPage extends StatelessWidget {
  const EducationPage({
    super.key,
    required this.onNext,
    this.onBack,
  });

  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Understanding the 5-Axis Model'),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              )
            : null,
      ),
      body: FiveAxisEducationWidget(
        onContinue: onNext,
        onSkip: onNext, // Both actions proceed to next step
      ),
    );
  }

  factory EducationPage.empty() {
    return EducationPage(
      onNext: () {},
    );
  }
}
