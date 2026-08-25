import 'package:flutter/material.dart';
import 'package:seafoundry_community/widgets/buttons.dart';
import 'package:seafoundry_community/widgets/ui.dart';
import 'package:seafoundry_community/widgets/ui_text.dart';

abstract class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    required super.key,
    required this.title,
    required this.description,
    required this.isPure,
    required this.onNext,
    this.onBack,
    this.nextButtonText = 'Continue',
    this.footer,
    this.footerText,
  });

  final String title;
  final String description;
  final bool isPure;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final String? nextButtonText;
  final Widget? footer;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UI.surfaceColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: UI.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              UI.dividerXl,
              // Title - centered
              Center(child: UIText.h3(title)),
              UI.dividerMd,
              // Description - centered text alignment
              UIText.bodyLarge(description, color: UI.textSecondaryColor, textAlign: TextAlign.center),
              UI.dividerXl,
              // Content area - to be implemented by subclasses
              buildContent(context),
              if (footerText != null) ...[
                UI.dividerMd,
                UIText.bodySmall(footerText!, color: UI.textSecondaryColor, textAlign: TextAlign.center),
              ],
              if (footer != null) ...[UI.dividerMd, footer!],
            ],
          ),
        ),
      ),
      persistentFooterAlignment: AlignmentDirectional.center,
      persistentFooterButtons: [
        if (onBack != null) ...[
          AppButtons.secondaryLarge(text: 'Back', onPressed: onBack),
          const SizedBox(width: 16),
        ],
        AppButtons.primaryLarge(text: nextButtonText!, onPressed: !isPure && validateForm() ? onNext : null),
      ],
    );
  }

  /// Build the main content area for the onboarding screen
  Widget buildContent(BuildContext context);

  /// Validate the form before proceeding
  bool validateForm();
}
