import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_community/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/user.dart';
import 'package:seafoundry_community/repositories/current_user_repository.dart';
import 'package:seafoundry_community/services/crash_reporting_service.dart';
import 'package:seafoundry_community/services/logging_service.dart';

/// Cubit for managing the current user's profile and organization data.
///
/// This cubit is the single source of truth (SOT) for user profile data.
/// Other components (including [AuthBloc]) should not cache or duplicate
/// user profile data but should instead access it through this cubit's state.
///
/// This ensures that:
/// - User profile changes (name, role, etc.) are immediately reflected
/// - There's no divergence between what different components see
/// - Role-based authorization always uses the current role
class CurrentUser extends Cubit<CurrentUserState>
    with CubitStreamSubscriptionMixin {
  final CurrentUserRepository _repository;
  final _logger = LoggingService.instance;
  User? _currentUser;
  Organization? _currentOrganization;

  CurrentUser({required CurrentUserRepository repository})
    : _repository = repository,
      super(CurrentUserInitial());

  /// Helper to emit state only if cubit is still open.
  /// Reduces boilerplate of repeated `if (isClosed) return; emit(...)` patterns.
  void _emitIfOpen(CurrentUserState newState) {
    if (!isClosed) emit(newState);
  }

  void _setupStreamListeners() {
    // Listen to user changes using keyed subscription
    listenWithKey<User?>(
      'user',
      _repository.userStream,
      onData: (user) {
        if (isClosed) return;
        _currentUser = user;
        _updateState();
      },
      onError: (error, stackTrace) {
        if (isClosed) return;
        LoggingService.instance.error('User stream failed', error, stackTrace);
        emit(
          CurrentUserError(message: 'Failed to load user: ${error.toString()}'),
        );
      },
    );

    // Listen to organization changes using keyed subscription
    listenWithKey<Organization?>(
      'organization',
      _repository.organizationStream,
      onData: (organization) {
        if (isClosed) return;
        _currentOrganization = organization;
        _updateState();
      },
      onError: (error, stackTrace) {
        if (isClosed) return;
        LoggingService.instance.error(
          'Organization stream failed',
          error,
          stackTrace,
        );
        emit(
          CurrentUserError(
            message: 'Failed to load organization: ${error.toString()}',
          ),
        );
      },
    );
  }

  void _updateState() {
    // Don't update if we're in initial or loading state
    if (state is CurrentUserInitial || state is CurrentUserLoading) {
      return;
    }

    // CRITICAL: Don't downgrade from CurrentUserLoaded to a less-complete state.
    // This prevents state oscillation when streams emit null temporarily before
    // the actual data arrives, which would cause RepositoriesProvider to rebuild
    // multiple times and create duplicate repository instances.
    if (state is CurrentUserLoaded) {
      // Only update if we have valid data to emit a new CurrentUserLoaded
      if (_currentUser != null && _currentOrganization != null) {
        emit(
          CurrentUserLoaded(
            user: _currentUser!,
            organization: _currentOrganization!,
          ),
        );
      } else {
        // Log when skipping state update to aid debugging
        _logger.warning(
          'CurrentUser: Skipping state update - user=${_currentUser != null}, org=${_currentOrganization != null}',
        );
      }
      // Otherwise, keep the current state - don't downgrade
      return;
    }

    // Update state based on current user and organization
    if (_currentUser != null && _currentOrganization != null) {
      emit(
        CurrentUserLoaded(
          user: _currentUser!,
          organization: _currentOrganization!,
        ),
      );
    } else if (_currentUser != null &&
        !_currentUser!.organizationId.isMissing) {
      emit(CurrentUserOrganizationUninitialized(user: _currentUser!));
    } else if (_currentUser != null) {
      emit(CurrentUserLoadedUser(user: _currentUser!));
    }
  }

  Future<void> loadUser(
    String userId, {
    String? targetPath,
  }) async {
    try {
      LoggingService.instance.debug(
        '👤 CurrentUser.loadUser called with userId: $userId',
      );
      emit(const CurrentUserLoading('Fetching user profile...'));

      // Fetch user from database (UID-keyed user docs)
      // On web, there's a race condition where Firebase Auth reports "authenticated"
      // but Firestore's auth token hasn't propagated yet. Retry with backoff.
      LoggingService.instance.debug('👤 Fetching user from database...');
      User? user;
      const maxRetries = 3;
      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        user = await _repository.getUser(userId);
        if (user != null || attempt == maxRetries) break;

        // User not found - might be auth token race condition on web
        LoggingService.instance.debug(
          '👤 User not found on attempt $attempt/$maxRetries, retrying after delay...',
        );
        await Future.delayed(Duration(milliseconds: 200 * attempt));
        if (isClosed) return;
      }
      LoggingService.instance.debug(
        '👤 User fetched: ${user != null ? "found (${user.email})" : "not found"}',
      );
      if (isClosed) return;

      if (user == null) {
        // User doesn't exist in database yet
        LoggingService.instance.debug(
          '👤 User not found - emitting CurrentUserUninitialized',
        );
        _emitIfOpen(CurrentUserUninitialized(uuid: userId));
        return;
      }

      // Fetch organization from database
      if (user.organizationId.isNotEmpty) {
        _emitIfOpen(const CurrentUserLoading('Loading organization data...'));
        LoggingService.instance.debug(
          '👤 Fetching organization: ${user.organizationId}',
        );

        // Apply same retry logic for organization fetch
        Organization? organization;
        for (var attempt = 1; attempt <= maxRetries; attempt++) {
          organization = await _repository.getOrganization(user.organizationId);
          if (organization != null || attempt == maxRetries) break;

          LoggingService.instance.debug(
            '👤 Organization not found on attempt $attempt/$maxRetries, retrying after delay...',
          );
          await Future.delayed(Duration(milliseconds: 200 * attempt));
          if (isClosed) return;
        }
        LoggingService.instance.debug(
          '👤 Organization fetched: ${organization != null ? "found (${organization.name})" : "not found"}',
        );
        if (isClosed) return;

        if (organization == null) {
          // Organization doesn't exist (shouldn't happen, but handle gracefully)
          LoggingService.instance.debug(
            '👤 Organization not found - emitting CurrentUserOrganizationUninitialized',
          );
          _emitIfOpen(CurrentUserOrganizationUninitialized(user: user));
          return;
        }

        // Both user and organization exist
        LoggingService.instance.debug(
          '👤 User and organization loaded successfully - emitting CurrentUserLoaded',
        );

        // NOTE: membership is created atomically during onboarding and
        // invitation-accept, so no client-side backfill is needed. Under the
        // hardened rules a self-create backfill would fail closed anyway (a user
        // may only self-join via onboarding, creatorship, or an invitation
        // index), so the previous ensureMembershipExists() call was removed.

        _emitIfOpen(
          CurrentUserLoaded(
            user: user,
            organization: organization,
            targetPath: targetPath,
          ),
        );
        CrashReportingService.instance.setUser(
          userId: user.id,
          email: user.email,
          name: user.name,
          organization: organization.name,
        );
      } else {
        // User exists but has no organization
        LoggingService.instance.debug(
          '👤 User exists but no organization - emitting CurrentUserOrganizationUninitialized',
        );
        _emitIfOpen(CurrentUserOrganizationUninitialized(user: user));
      }

      // Subscribe to streams for real-time updates
      _repository.subscribeToUser(user.id);
      if (user.organizationId.isNotEmpty) {
        _repository.subscribeToOrganization(user.organizationId);
      }

      // Setup stream listeners after subscriptions are established
      _setupStreamListeners();
    } catch (error, stackTrace) {
      if (isClosed) return;
      LoggingService.instance.error('👤 Error loading user', error, stackTrace);
      _emitIfOpen(CurrentUserError(message: error.toString()));
    }
  }

  Future<void> createUser({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    try {
      _emitIfOpen(const CurrentUserLoading('Creating user profile...'));

      // Create user in database
      final user = await _repository.createUser(
        userId: userId,
        email: email,
        name: displayName,
      );
      if (isClosed) return;

      _emitIfOpen(CurrentUserLoadedUser(user: user));

      // Subscribe to user stream
      _repository.subscribeToUser(user.id);

      // Setup stream listeners after subscription is established
      _setupStreamListeners();
    } catch (error) {
      if (isClosed) return;
      _emitIfOpen(CurrentUserError(message: error.toString()));
    }
  }

  Future<void> updateUserOrganization({
    required String userId,
    required String organizationId,
  }) async {
    try {
      final currentState = state;
      if (currentState is! CurrentUserLoadedUser &&
          currentState is! CurrentUserOrganizationUninitialized) {
        return;
      }

      _emitIfOpen(const CurrentUserLoading('Updating organization...'));

      // Get current user
      final user = currentState is CurrentUserLoadedUser
          ? currentState.user
          : (currentState as CurrentUserOrganizationUninitialized).user;

      // Update user's organization
      final updatedUser = await _repository.updateUserOrganization(
        user: user,
        organizationId: organizationId,
      );
      if (isClosed) return;

      // Fetch the organization
      _emitIfOpen(const CurrentUserLoading('Fetching organization details...'));
      final organization = await _repository.getOrganization(organizationId);
      if (isClosed) return;

      if (organization == null) {
        _emitIfOpen(CurrentUserOrganizationUninitialized(user: updatedUser));
        return;
      }

      _emitIfOpen(
        CurrentUserLoaded(user: updatedUser, organization: organization),
      );

      // Subscribe to organization stream
      _repository.subscribeToOrganization(organizationId);

      // Setup stream listeners after subscription is established
      _setupStreamListeners();
    } catch (error) {
      if (isClosed) return;
      _emitIfOpen(CurrentUserError(message: error.toString()));
    }
  }

  Future<void> updateProfile({
    String? name,
    String? tagline,
    String? imageUrl,
  }) async {
    try {
      final currentState = state;
      if (currentState is! CurrentUserLoaded) return;

      _emitIfOpen(const CurrentUserLoading('Updating profile...'));

      final updatedUser = await _repository.updateUserProfile(
        user: currentState.user,
        name: name,
        tagline: tagline,
        imageUrl: imageUrl,
      );
      if (isClosed) return;

      _emitIfOpen(
        CurrentUserLoaded(
          user: updatedUser,
          organization: currentState.organization,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _emitIfOpen(CurrentUserError(message: error.toString()));
    }
  }

  /// Reset the cubit to initial state.
  /// Cancels cubit subscriptions, resets repository streams, and emits initial state.
  Future<void> reset() async {
    // Cancel cubit's own subscriptions via mixin
    cancelAllSubscriptions();

    // Clear cached state
    _currentUser = null;
    _currentOrganization = null;

    // Emit initial state immediately so UI sees the reset synchronously.
    // This prevents race conditions where the UI tries to render stale state
    // while waiting for the async repository reset.
    emit(CurrentUserInitial());

    // Reset repository to get fresh stream controllers (non-blocking for UI)
    await _repository.reset();
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin
  // DO NOT call repository.dispose() - it's a singleton managed at app level
}
