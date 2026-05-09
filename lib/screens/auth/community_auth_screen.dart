import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/auth/auth_bloc.dart';
import 'package:seafoundry_app/cubits/auth/auth_state.dart';
import 'package:seafoundry_app/cubits/auth_form_cubit.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/auth/promo_carousel.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simplified authentication screen for Community tier.
/// Supports email/password authentication without demo mode.
class CommunityAuthScreen extends StatefulWidget {
  /// Whether to show a back button to return to the public map.
  final bool showBackButton;

  /// Callback when back button is pressed. If null, uses Navigator.pop.
  final VoidCallback? onBackPressed;

  const CommunityAuthScreen({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  State<CommunityAuthScreen> createState() => _CommunityAuthScreenState();
}

class _CommunityAuthScreenState extends State<CommunityAuthScreen> {
  static const String _githubRepoUrl = String.fromEnvironment(
    'SF_GITHUB_REPO_URL',
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthFormCubit(),
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated && widget.showBackButton) {
            Navigator.of(context).pop();
            return;
          }

          if (state is AuthError) {
            // Handle user-not-found by switching to sign-up mode
            if (state.code == 'user-not-found') {
              context.read<AuthFormCubit>().setSignUpMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'No account found. Please create one below.',
                  ),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: AppColors.surface,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
              context.read<AuthBloc>().clearError();
              return;
            }

            if (state.code == 'email-already-in-use' ||
                state.code == 'account-exists-with-different-credential' ||
                state.code == 'credential-already-in-use') {
              context.read<AuthFormCubit>().setSignInMode();
              _showExistingAccountDialog(context);
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: AppColors.surface,
                  onPressed: () {
                    context.read<AuthBloc>().clearError();
                  },
                ),
              ),
            );
          } else if (state is AuthPasswordResetSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Password reset email sent to ${state.email}'),
                backgroundColor: AppColors.success,
                action: SnackBarAction(
                  label: 'Resend',
                  textColor: AppColors.surface,
                  onPressed: () {
                    context.read<AuthBloc>().sendPasswordReset(
                          email: state.email,
                        );
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  UI.spacingVerticalMd,
                  UIText.bodyMedium(state.message),
                ],
              ),
            );
          }

          return BlocBuilder<AuthFormCubit, AuthFormState>(
            builder: (context, formState) {
              return SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: formState.formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.showBackButton) ...[
                              _buildBackButton(context),
                              UI.spacingVerticalMd,
                            ],
                            const PromoCarousel(),
                            UI.spacingVerticalXl,
                            _buildHeader(formState),
                            UI.spacingVerticalXl,
                            if (formState.isSignUp) ...[
                              _buildNameField(formState),
                              UI.spacingVerticalMd,
                            ],
                            _buildEmailField(formState, state),
                            UI.spacingVerticalMd,
                            _buildPasswordField(context, formState, state),
                            UI.spacingVerticalSm,
                            if (!formState.isSignUp)
                              _buildForgotPasswordButton(context, formState),
                            UI.spacingVerticalXl,
                            _buildSubmitButton(context, state, formState),
                            UI.spacingVerticalXl,
                            _buildToggleAuthModeButton(context, formState),
                            UI.spacingVerticalMd,
                            _buildFooterLinks(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed:
            widget.onBackPressed ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back, size: 20),
        label: const Text('Back to Map'),
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildHeader(AuthFormState formState) {
    return Column(
      children: [
        Image.asset(
          'assets/provenance_logo.png',
          height: 128,
          color: AppColors.background,
          colorBlendMode: BlendMode.multiply,
        ),
        UI.spacingVerticalMd,
        UIText.h3('SeaFoundry Community'),
        UI.spacingVerticalSm,
        UIText.bodyMedium(
          'Open-source marine aquaculture tracking',
          color: AppColors.textSecondary,
          textAlign: TextAlign.center,
        ),
        UI.spacingVerticalXs,
        UIText.bodyMedium(
          formState.isSignUp ? 'Create your account' : 'Sign in to continue',
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildEmailField(AuthFormState formState, AuthState authState) {
    String? errorText;
    if (authState is AuthError) {
      if ([
        'user-not-found',
        'invalid-email',
        'missing-email',
        'email-already-in-use',
        'credential-already-in-use',
        'account-exists-with-different-credential',
      ].contains(authState.code)) {
        errorText = authState.message;
      }
    }

    return TextFormField(
      controller: formState.emailController,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'your@email.com',
        prefixIcon: const Icon(Icons.email_outlined),
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildNameField(AuthFormState formState) {
    return TextFormField(
      controller: formState.nameController,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Full Name',
        hintText: 'Your name',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (!formState.isSignUp) return null;
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your full name';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(
    BuildContext context,
    AuthFormState formState,
    AuthState authState,
  ) {
    String? errorText;
    if (authState is AuthError) {
      if ([
        'wrong-password',
        'weak-password',
        'missing-password',
        'invalid-credential',
        'invalid-password',
      ].contains(authState.code)) {
        errorText = authState.message;
      }
    }

    return TextFormField(
      controller: formState.passwordController,
      obscureText: formState.obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        errorText: errorText,
        suffixIcon: IconButton(
          icon: Icon(
            formState.obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            context.read<AuthFormCubit>().togglePasswordVisibility();
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (formState.isSignUp && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildForgotPasswordButton(
    BuildContext context,
    AuthFormState formState,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => _showForgotPasswordDialog(context, formState),
        child: const Text('Forgot password?'),
      ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    AuthState state,
    AuthFormState formState,
  ) {
    final isLoading = state is AuthLoading;

    return ElevatedButton(
      onPressed: isLoading ? null : () => _handleSubmit(context, formState),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        formState.isSignUp ? 'Create Account' : 'Sign In',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildToggleAuthModeButton(
    BuildContext context,
    AuthFormState formState,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: [
        UIText.bodyMedium(
          formState.isSignUp
              ? 'Already have an account?'
              : "Don't have an account?",
          color: AppColors.textSecondary,
        ),
        TextButton(
          onPressed: () {
            context.read<AuthFormCubit>().toggleAuthMode();
          },
          child: Text(
            formState.isSignUp ? 'Sign In' : 'Sign Up',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => _launchGitHubRepo(context),
          icon: const Icon(Icons.code, size: 16),
          label: const Text('View on GitHub'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _handleSubmit(BuildContext context, AuthFormState formState) {
    if (formState.formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();

      if (formState.isSignUp) {
        context.read<AuthBloc>().signUp(
          email: formState.emailController.text.trim(),
          password: formState.passwordController.text,
          displayName: formState.nameController.text.trim(),
        );
      } else {
        context.read<AuthBloc>().signIn(
          email: formState.emailController.text.trim(),
          password: formState.passwordController.text,
        );
      }
    }
  }

  void _showForgotPasswordDialog(
    BuildContext context,
    AuthFormState formState,
  ) {
    final emailController = TextEditingController(
      text: formState.emailController.text,
    );

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a password reset link.',
            ),
            UI.spacingVerticalMd,
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'your@email.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                BlocProvider.of<AuthBloc>(
                  context,
                ).sendPasswordReset(email: email);
                Navigator.pop(context);
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    ).whenComplete(emailController.dispose);
  }

  void _showExistingAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Account already exists'),
        content: const Text(
          'An account with this email already exists. Please sign in or reset your password, then try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
        ],
      ),
    ).whenComplete(() {
      if (context.mounted) {
        context.read<AuthBloc>().clearError();
      }
    });
  }

  Future<void> _launchGitHubRepo(BuildContext context) async {
    final url = _githubRepoUrl.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GitHub repository link is not configured.'),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      LoggingService.instance.warning('Invalid GitHub repository URL: $url');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid GitHub repository link.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open GitHub repository.')),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to launch GitHub repository',
        e,
        stackTrace,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to open GitHub repository.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
