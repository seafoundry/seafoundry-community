// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/models/organization.dart';

/// Container widget that provides access to current user and organization state.
/// Can be used either with a builder callback or by subclassing and overriding buildWidget.
class CurrentUserContainer extends StatelessWidget {
  /// Optional builder to construct the child widget
  final Widget Function(BuildContext context, User user, Organization organization)? builder;

  /// Optional child widget to display while loading
  final Widget? loadingWidget;

  /// Optional child widget to display when user is uninitialized
  final Widget Function(BuildContext context, String uuid)? uninitializedBuilder;

  /// Optional child widget to display when user has no organization
  final Widget Function(BuildContext context, User user)? noOrganizationBuilder;

  /// Optional child widget to display when organization is uninitialized
  final Widget Function(BuildContext context, User user)? organizationUninitializedBuilder;

  /// Optional child widget to display on error
  final Widget Function(BuildContext context, String error)? errorBuilder;

  const CurrentUserContainer({
    super.key,
    this.builder,
    this.loadingWidget,
    this.uninitializedBuilder,
    this.noOrganizationBuilder,
    this.organizationUninitializedBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrentUser, CurrentUserState>(
      builder: (context, state) {
        // Handle loading state
        if (state is CurrentUserInitial || state is CurrentUserLoading) {
          return loadingWidget ?? _buildDefaultLoading();
        }

        // Handle uninitialized user
        if (state is CurrentUserUninitialized) {
          return uninitializedBuilder?.call(context, state.uuid) ?? _buildDefaultUninitialized(context, state.uuid);
        }

        // Handle user with no organization
        if (state is CurrentUserLoadedUser) {
          return noOrganizationBuilder?.call(context, state.user) ?? _buildDefaultNoOrganization(context, state.user);
        }

        // Handle organization uninitialized
        if (state is CurrentUserOrganizationUninitialized) {
          return organizationUninitializedBuilder?.call(context, state.user) ??
              _buildDefaultOrganizationUninitialized(context, state.user);
        }

        // Handle error state
        if (state is CurrentUserError) {
          return errorBuilder?.call(context, state.message) ?? _buildDefaultError(state.message);
        }

        // Handle loaded state
        if (state is CurrentUserLoaded) {
          if (builder != null) {
            return builder!(context, state.user, state.organization);
          } else {
            return buildWidget(context, state.user, state.organization);
          }
        }

        // Fallback (should not reach here)
        return _buildDefaultError('Unknown state');
      },
    );
  }

  /// Override this method in subclasses to build the widget when user and organization are loaded
  Widget buildWidget(BuildContext context, User user, Organization organization) {
    // Default implementation - can be overridden by subclasses
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text('User: ${user.name}'), Text('Organization: ${organization.name}')],
        ),
      ),
    );
  }

  Widget _buildDefaultLoading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildDefaultUninitialized(BuildContext context, String uuid) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Welcome! Please complete your profile setup.'),
            const SizedBox(height: 8),
            Text('User ID: $uuid', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultNoOrganization(BuildContext context, User user) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Welcome, ${user.name}!'),
            const SizedBox(height: 8),
            const Text('Please join or create an organization to continue.'),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultOrganizationUninitialized(BuildContext context, User user) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text('Hi ${user.name},'),
            const SizedBox(height: 8),
            const Text('Your organization needs to be set up.'),
            const Text('Please contact support if this persists.'),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultError(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('An error occurred:'),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Example of using CurrentUserContainer with a builder
class CurrentUserExample extends StatelessWidget {
  const CurrentUserExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CurrentUserContainer(
      builder: (context, user, organization) {
        return Scaffold(
          appBar: AppBar(title: Text('${organization.name} - ${user.name}')),
          body: Center(child: Text('Welcome to ${organization.name}!')),
        );
      },
      uninitializedBuilder: (context, uuid) {
        // Handle uninitialized user - could navigate to onboarding
        return const Center(child: Text('Please complete onboarding'));
      },
      noOrganizationBuilder: (context, user) {
        // Handle user with no organization - could navigate to org creation
        return const Center(child: Text('Please create or join an organization'));
      },
    );
  }
}

/// Example of subclassing CurrentUserContainer
class MyCustomContainer extends CurrentUserContainer {
  const MyCustomContainer({super.key});

  @override
  Widget buildWidget(BuildContext context, User user, Organization organization) {
    return Scaffold(
      appBar: AppBar(
        title: Text(organization.name),
        actions: [CircleAvatar(child: Text(user.name[0]))],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text('Welcome, ${user.name}!'), Text('You are part of ${organization.name}')],
        ),
      ),
    );
  }
}
