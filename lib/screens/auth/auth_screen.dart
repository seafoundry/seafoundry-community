// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/auth/auth.dart';
import 'package:seafoundry_app/cubits/auth_form_cubit.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/auth/promo_carousel.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class AuthScreen extends StatefulWidget {
  /// Whether to show a back button to return to the public map.
  /// Set to true when navigating from the public landing page.
  final bool showBackButton;

  /// Callback when back button is pressed. If null, uses Navigator.pop.
  final VoidCallback? onBackPressed;

  const AuthScreen({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthFormCubit(),
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          // Try to access AuthBloc, but handle case where it might not be available
          try {
            return BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                // When authentication succeeds, pop this screen if it was pushed
                // (e.g., from public map). The SimpleRouter will handle navigation.
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

                // Handle existing account errors by switching to sign-in mode
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

          // For all other states (AuthUnauthenticated, AuthInitial, AuthError, etc.), show the form
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
                            // Demo mode: Users sign in with demo credentials directly
                            // (pro@provenance.app / DemoPassword123!)
                            // Demo mode auto-activates based on email pattern
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
            );
          } catch (e) {
            // Fallback if AuthBloc is not available - show basic auth UI
            LoggingService.instance.warning('AuthBloc not available in AuthScreen context', e);
            return _buildFallbackAuthUI(context);
          }
        },
      ),
    );
  }

  Widget _buildFallbackAuthUI(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/provenance_logo.png',
                height: 128,
                color: AppColors.background,
                colorBlendMode: BlendMode.multiply,
              ),
              UI.spacingVerticalXl,
              UIText.h3('Provenance'),
              UI.spacingVerticalMd,
              UIText.bodyMedium(
                'Please sign in to continue',
                color: AppColors.textSecondary,
              ),
              UI.spacingVerticalXl,
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed:
            widget.onBackPressed ??
            () {
              // Navigate back to public map by triggering a rebuild
              // The SimpleRouter will show the public map when not authenticated
              // and on a main app domain
              Navigator.of(context).maybePop();
            },
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
        UIText.h3('Provenance'),
        UI.spacingVerticalSm,
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
      // Map specific error codes to the email field
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
      // Map specific error codes to the password field
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
}
