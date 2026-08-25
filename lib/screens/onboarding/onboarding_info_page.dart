import 'package:flutter/material.dart';
import 'package:seafoundry_community/screens/onboarding/onboarding_page.dart';

class OnboardingInfoPage extends OnboardingPage {
  const OnboardingInfoPage({
    super.key,
    required super.title,
    required super.description,
    required super.onNext,
    this.contentBuilder,
    required super.nextButtonText,
  }) : super(isPure: false);

  final Widget Function(BuildContext context)? contentBuilder;

  @override
  Widget buildContent(BuildContext context) {
    return contentBuilder?.call(context) ?? const SizedBox.shrink();
  }

  @override
  bool validateForm() {
    return true;
  }
}
