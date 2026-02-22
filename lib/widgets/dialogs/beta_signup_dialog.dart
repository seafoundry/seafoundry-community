// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/repositories/beta_signup_repository.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Shows a dialog to collect email for beta/early access signup.
///
/// Returns `true` if signup was successful, `false` otherwise.
Future<bool?> showBetaSignupDialog({
  required BuildContext context,
  String? featureName,
}) {
  // Capture FirebaseFirestore from parent context before showDialog
  // (showDialog creates a new overlay context that doesn't inherit providers)
  final firestore = context.read<FirebaseService>().firestore;
  final repository = BetaSignupRepository(firestore: firestore);

  return showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => RepositoryProvider<BetaSignupRepository>.value(
      value: repository,
      child: BetaSignupDialog(featureName: featureName),
    ),
  );
}

/// Dialog for collecting beta signup emails.
class BetaSignupDialog extends StatefulWidget {
  const BetaSignupDialog({
    super.key,
    this.featureName,
  });

  final String? featureName;

  @override
  State<BetaSignupDialog> createState() => _BetaSignupDialogState();
}

class _BetaSignupDialogState extends State<BetaSignupDialog>
    with SafeDialogMixin<BetaSignupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;

    safeSetState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final repository = context.read<BetaSignupRepository>();

      await repository.recordSignup(
        email: email,
        featureInterest: widget.featureName,
        source: 'upgrade_cta',
      );

      if (!mounted) return;

      // Show success dialog
      await _showSuccessDialog();

      if (!mounted) return;
      popDialog(true);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to record beta signup',
        e,
        stackTrace,
      );
      if (!mounted) return;
      safeSetState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to sign up. Please try again.';
      });
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 48,
        ),
        title: const Text("You're on the list!"),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "We'll notify you at ${_emailController.text.trim()} when new features become available.",
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              SizedBox(height: Spacing.md),
              Text(
                'Thank you for your interest in SeaFoundry Pro!',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final email = value.trim();
    // Simple email validation
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.rocket_launch_outlined,
        color: theme.colorScheme.primary,
        size: 40,
      ),
      title: const Text('Get Early Access'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New features are coming soon! Sign up to be notified when they launch and get early access.',
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: Spacing.lg),
              TextFormField(
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validateEmail,
                onFieldSubmitted: (_) => _submitSignup(),
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: Spacing.sm),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              SizedBox(height: Spacing.md),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        "We'll only use your email to notify you about new features. No spam, ever.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => popDialog(false),
          child: const Text('Maybe Later'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submitSignup,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text(_isSubmitting ? 'Signing up...' : 'Notify Me'),
        ),
      ],
    );
  }
}
