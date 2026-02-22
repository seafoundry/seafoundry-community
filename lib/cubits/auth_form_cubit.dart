// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State for auth form UI
class AuthFormState extends Equatable {
  final bool isSignUp;
  final bool obscurePassword;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final GlobalKey<FormState> formKey;

  const AuthFormState({
    required this.isSignUp,
    required this.obscurePassword,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.formKey,
  });

  AuthFormState copyWith({bool? isSignUp, bool? obscurePassword}) {
    return AuthFormState(
      isSignUp: isSignUp ?? this.isSignUp,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      emailController: emailController,
      passwordController: passwordController,
      nameController: nameController,
      formKey: formKey,
    );
  }

  @override
  List<Object?> get props => [isSignUp, obscurePassword, emailController, passwordController, nameController, formKey];
}

/// Cubit for managing auth form UI state
class AuthFormCubit extends Cubit<AuthFormState> {
  AuthFormCubit()
    : super(
        AuthFormState(
          isSignUp: false,
          obscurePassword: true,
          emailController: TextEditingController(),
          passwordController: TextEditingController(),
          nameController: TextEditingController(),
          formKey: GlobalKey<FormState>(),
        ),
      );

  /// Toggle between sign up and sign in modes
  void toggleAuthMode() {
    state.formKey.currentState?.reset();
    emit(state.copyWith(isSignUp: !state.isSignUp));
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    emit(state.copyWith(obscurePassword: !state.obscurePassword));
  }

  /// Set to sign up mode
  void setSignUpMode() {
    if (!state.isSignUp) {
      state.formKey.currentState?.reset();
      emit(state.copyWith(isSignUp: true));
    }
  }

  /// Set to sign in mode
  void setSignInMode() {
    if (state.isSignUp) {
      state.formKey.currentState?.reset();
      emit(state.copyWith(isSignUp: false));
    }
  }

  @override
  Future<void> close() {
    state.emailController.dispose();
    state.passwordController.dispose();
    state.nameController.dispose();
    return super.close();
  }
}
