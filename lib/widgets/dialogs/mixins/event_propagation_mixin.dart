// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import '../../notifications/toast_overlay.dart';
import '../components/dialog_scroll_view.dart';

/// Unified mixin for event propagation with optional enhanced features
///
/// This mixin provides a simple interface for propagating events to parent nodes
/// without needing to worry about GraphNode access or error handling.
///
/// When combined with [NotificationMixin], enhanced features become available:
/// - Automatic success/error notifications
/// - Batch propagation
/// - Retry logic
/// - Progress indicators
///
/// Usage (basic):
/// ```dart
/// class MyDialog extends StatefulWidget {
///   @override
///   State<MyDialog> createState() => _MyDialogState();
/// }
///
/// class _MyDialogState extends State<MyDialog> with EventPropagationMixin {
///   Future<void> _handleSave() async {
///     await propagateEvent(
///       event: event,
///       activityType: 'Coral Health Check',
///       description: 'Health status updated',
///     );
///   }
/// }
/// ```
///
/// Usage (enhanced with notifications):
/// ```dart
/// class _MyDialogState extends State<MyDialog>
///     with EventPropagationMixin, NotificationMixin {
///   Future<void> _handleSave() async {
///     await propagateEventWithNotification(
///       event: event,
///       activityType: 'Coral Health Check',
///       successMessage: 'Health status updated and propagated',
///     );
///   }
/// }
/// ```
mixin EventPropagationMixin<T extends StatefulWidget> on State<T> {
  /// Propagate an event to parent nodes
  ///
  /// This method handles:
  /// - Getting the current node from NavigationCubit
  /// - Accessing EventPropagationService
  /// - Error handling and logging
  /// - Graceful failures (won't crash if propagation fails)
  Future<void> propagateEvent({
    required Event event,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
    bool showSnackbarOnError = false,
  }) async {
    try {
      // Get the current node from navigation
      final navigationCubit = _getNavigationCubit();
      if (navigationCubit == null) {
        LoggingService.instance.warning(
          'Cannot propagate event: Navigation cubit not available',
        );
        return;
      }
      final currentNode = navigationCubit.currentNode;

      if (currentNode == null) {
        LoggingService.instance.warning(
          'Cannot propagate event: No current node in navigation',
        );
        return;
      }

      // Get propagation service
      final propagationService = context.read<EventPropagationService?>();
      if (propagationService == null) {
        LoggingService.instance.warning(
          'EventPropagationService not found in context; skipping propagation for ${event.eventTypeId}',
        );
        return;
      }

      // Propagate the event
      final propagatedEvents = await propagationService.propagateToParents(
        sourceEvent: event,
        sourceNode: currentNode,
        activityType: activityType,
        description: description,
        parameters: parameters,
      );

      LoggingService.instance.info(
        'Successfully propagated event to ${propagatedEvents.length} parent(s)',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to propagate event', e, stackTrace);

      if (showSnackbarOnError && mounted) {
        showSafeDialogSnackBar(
          context,
          'Failed to propagate event: $e',
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  /// Propagate an event with automatic success/error notifications (enhanced feature)
  ///
  /// This method is only available when [NotificationMixin] is also included.
  /// It provides automatic loading, success, and error notifications.
  Future<bool> propagateEventWithNotification({
    required Event event,
    required String activityType,
    String? description,
    String? successMessage,
    String? errorMessage,
    Map<String, dynamic>? parameters,
    bool showLoadingNotification = true,
    bool showSuccessNotification = true,
    bool showErrorNotification = true,
  }) async {
    // Check if NotificationMixin is available
    if (!_hasNotificationMixin) {
      LoggingService.instance.warning(
        'NotificationMixin not found. Falling back to basic propagateEvent.',
      );
      await propagateEvent(
        event: event,
        activityType: activityType,
        description: description,
        parameters: parameters,
      );
      return true;
    }

    // Show loading notification
    ToastController? loadingController;
    if (showLoadingNotification && mounted) {
      loadingController = (this as dynamic).showLoadingNotification(
        'Propagating event to parent structures...',
      );
    }

    try {
      // Get navigation state
      final navigationCubit = _getNavigationCubit();
      if (navigationCubit == null) {
        if (loadingController != null && mounted) {
          loadingController.close();
        }
        if (showErrorNotification && mounted) {
          final message = errorMessage ??
              'Failed to propagate event: navigation not available';
          (this as dynamic).showErrorNotification(message);
        }
        return false;
      }
      final currentNode = navigationCubit.currentNode;

      if (currentNode == null) {
        throw Exception('No current node in navigation');
      }

      // Get propagation service
      final propagationService = context.read<EventPropagationService?>();
      if (propagationService == null) {
        if (loadingController != null && mounted) {
          loadingController.close();
        }

        LoggingService.instance.warning(
          'EventPropagationService not found; skipping propagation for ${event.eventTypeId}',
        );

        if (showErrorNotification && mounted) {
          final message = errorMessage ??
              'Failed to propagate event: upstream propagation service unavailable';
          (this as dynamic).showErrorNotification(message);
        }

        return false;
      }

      // Propagate the event
      final propagatedEvents = await propagationService.propagateToParents(
        sourceEvent: event,
        sourceNode: currentNode,
        activityType: activityType,
        description: description,
        parameters: parameters,
      );

      // Dismiss loading
      if (loadingController != null && mounted) {
        loadingController.close();
      }

      // Show success
      if (showSuccessNotification && mounted) {
        final message =
            successMessage ??
            'Event propagated to ${propagatedEvents.length} parent structure${propagatedEvents.length != 1 ? 's' : ''}';
        (this as dynamic).showSuccessNotification(message);
      }

      LoggingService.instance.info(
        'Successfully propagated event to ${propagatedEvents.length} parent(s)',
      );

      return true;
    } catch (e, stackTrace) {
      // Dismiss loading
      if (loadingController != null && mounted) {
        loadingController.close();
      }

      LoggingService.instance.error('Event propagation failed', e, stackTrace);

      // Show error
      if (showErrorNotification && mounted) {
        final message =
            errorMessage ?? 'Failed to propagate event: ${e.toString()}';
        (this as dynamic).showErrorNotification(message);
      }

      return false;
    }
  }

  /// Batch propagate multiple events (enhanced feature)
  ///
  /// This method is only available when [NotificationMixin] is also included.
  Future<BatchPropagationResult> batchPropagateEvents({
    required List<EventPropagationRequest> requests,
    bool continueOnError = true,
    bool showProgress = true,
    bool showSummary = true,
  }) async {
    final results = BatchPropagationResult();
    ToastController? progressController;

    if (showProgress && mounted && _hasNotificationMixin) {
      progressController = (this as dynamic).showLoadingNotification(
        'Propagating ${requests.length} events...',
      );
    }

    for (var i = 0; i < requests.length; i++) {
      final request = requests[i];

      // Update progress
      if (showProgress && mounted && progressController != null && _hasNotificationMixin) {
        progressController.close();
        progressController = (this as dynamic).showLoadingNotification(
          'Propagating event ${i + 1} of ${requests.length}...',
        );
      }

      try {
        // Get navigation state
        final navigationCubit = _getNavigationCubit();
        if (navigationCubit == null) {
          results.failed.add(
            PropagationFailure(
              event: request.event,
              error: 'Navigation unavailable for propagation',
            ),
          );
          if (!continueOnError) {
            break;
          }
          continue;
        }
        final currentNode = navigationCubit.currentNode;

        if (currentNode == null) {
          throw Exception('No current node in navigation');
        }

        // Get propagation service
        final propagationService = context.read<EventPropagationService?>();
        if (propagationService == null) {
          results.failed.add(
            PropagationFailure(
              event: request.event,
              error: 'EventPropagationService not available',
            ),
          );

          if (!continueOnError) {
            break;
          }
          continue;
        }

        // Propagate the event
        final propagatedEvents = await propagationService.propagateToParents(
          sourceEvent: request.event,
          sourceNode: request.sourceNode ?? currentNode,
          activityType: request.activityType,
          description: request.description,
          parameters: request.parameters,
        );

        results.successful.add(
          PropagationSuccess(
            event: request.event,
            propagatedCount: propagatedEvents.length,
          ),
        );
      } catch (e) {
        results.failed.add(
          PropagationFailure(event: request.event, error: e.toString()),
        );

        if (!continueOnError) {
          break;
        }
      }
    }

    // Dismiss progress
    if (progressController != null && mounted) {
      progressController.close();
    }

    // Show summary
    if (showSummary && mounted && _hasNotificationMixin) {
      _showBatchSummary(results);
    }

    return results;
  }

  /// Propagate with retry on failure (enhanced feature)
  ///
  /// This method is only available when [NotificationMixin] is also included.
  Future<bool> propagateEventWithRetry({
    required Event event,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final navigationCubit = _getNavigationCubit();
        if (navigationCubit == null) {
          throw Exception('Navigation not available');
        }
        final currentNode = navigationCubit.currentNode;

        if (currentNode == null) {
          throw Exception('No current node in navigation');
        }

        final propagationService = context.read<EventPropagationService?>();
        if (propagationService == null) {
          throw Exception('EventPropagationService not available');
        }

        await propagationService.propagateToParents(
          sourceEvent: event,
          sourceNode: currentNode,
          activityType: activityType,
          description: description,
          parameters: parameters,
        );

        if (mounted && _hasNotificationMixin) {
          (this as dynamic).showSuccessNotification(
            'Event propagated successfully',
          );
        }
        return true;
      } catch (e) {
        if (attempt < maxRetries) {
          LoggingService.instance.warning(
            'Event propagation failed (attempt $attempt of $maxRetries), retrying...',
          );

          if (mounted && _hasNotificationMixin) {
            (this as dynamic).showWarningNotification(
              'Propagation failed, retrying ($attempt/$maxRetries)...',
            );
          }

          await Future.delayed(retryDelay);
        } else {
          LoggingService.instance.error(
            'Event propagation failed after $maxRetries attempts',
            e,
          );

          if (mounted && _hasNotificationMixin) {
            (this as dynamic).showErrorNotification(
              'Failed to propagate event after $maxRetries attempts',
            );
          }
          return false;
        }
      }
    }
    return false;
  }

  /// Check if event propagation is available
  ///
  /// Returns true if:
  /// - NavigationCubit has a current node
  /// - EventPropagationService is available
  bool get canPropagateEvents {
    try {
      final navigationCubit = _getNavigationCubit();
      final hasNode = navigationCubit?.currentNode != null;
      final hasService = context.read<EventPropagationService?>();
      return hasNode && hasService != null;
    } catch (_) {
      return false;
    }
  }

  /// Check if propagation is available and show appropriate message (enhanced feature)
  Future<bool> checkPropagationAvailable({bool showNotification = true}) async {
    try {
      final navigationCubit = _getNavigationCubit();
      if (navigationCubit == null) {
        if (showNotification && mounted) {
          if (_hasNotificationMixin) {
            (this as dynamic).showWarningNotification(
              'Event propagation not available - navigation not ready',
            );
          } else {
            showSafeDialogSnackBar(
              context,
              'Event propagation not available - navigation not ready',
            );
          }
        }
        return false;
      }
      final currentNode = navigationCubit.currentNode;

      if (currentNode == null) {
        if (showNotification && mounted) {
          if (_hasNotificationMixin) {
            (this as dynamic).showWarningNotification(
              'Event propagation not available - no current location',
            );
          } else {
            showSafeDialogSnackBar(
              context,
              'Event propagation not available - no current location',
            );
          }
        }
        return false;
      }

      // Check if node has parents
      if (currentNode.parent == null) {
        if (showNotification && mounted) {
          if (_hasNotificationMixin) {
            (this as dynamic).showInfoNotification(
              'This is a root location - no parent structures to propagate to',
            );
          } else {
            showSafeDialogSnackBar(
              context,
              'This is a root location - no parent structures to propagate to',
            );
          }
        }
        return false;
      }

      return true;
    } catch (e) {
      LoggingService.instance.error(
        'Failed to check propagation availability',
        e,
      );
      if (showNotification && mounted) {
        if (_hasNotificationMixin) {
          (this as dynamic).showErrorNotification(
            'Failed to check propagation availability',
          );
        } else {
          showSafeDialogSnackBar(
            context,
            'Failed to check propagation availability: $e',
          );
        }
      }
      return false;
    }
  }

  /// Override in widgets to supply a navigation cubit explicitly when
  /// the dialog is not under the usual provider scope.
  NavigationCubit? get navigationCubitOverride => null;

  NavigationCubit? _getNavigationCubit() {
    if (navigationCubitOverride != null) {
      return navigationCubitOverride!.isClosed ? null : navigationCubitOverride;
    }
    try {
      final cubit = context.read<NavigationCubit>();
      return cubit.isClosed ? null : cubit;
    } catch (_) {
      return null;
    }
  }

  /// Get a user-friendly activity type from an event
  ///
  /// This generates a human-readable activity type string based on the event type.
  /// Override this method to customize activity types for specific events.
  String getActivityTypeForEvent(Event event) {
    final eventType = event.eventTypeId;

    // Convert event type to human-readable format
    // e.g., "health_observation" -> "Health Observation"
    final words = eventType.split('_');
    final formatted = words
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return formatted;
  }

  /// Generate a default description for an event
  ///
  /// Override this method to provide custom descriptions
  String getDefaultDescription(Event event) {
    return '${getActivityTypeForEvent(event)} recorded';
  }

  // === Private helpers ===

  /// Check if NotificationMixin is available
  /// Uses capability checking (method existence) instead of type checking
  /// to avoid import dependency and ensure robustness in production builds
  bool get _hasNotificationMixin {
    try {
      // Check for method existence instead of type name
      // This is robust against minification and compiler optimizations
      final dynamic self = this;
      // Accessing the method getter will throw if it doesn't exist
      self.showSuccessNotification;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Show batch propagation summary (enhanced feature)
  void _showBatchSummary(BatchPropagationResult results) {
    if (!_hasNotificationMixin) return;

    final total = results.successful.length + results.failed.length;
    if (total == 0) {
      (this as dynamic).showInfoNotification(
        'No events were propagated.',
      );
      return;
    }

    final successRate = results.successful.length / total * 100;

    if (results.failed.isEmpty) {
      (this as dynamic).showSuccessNotification(
        'All $total events propagated successfully!',
      );
    } else if (results.successful.isEmpty) {
      (this as dynamic).showErrorNotification(
        'All $total events failed to propagate',
      );
    } else {
      (this as dynamic).showWarningNotification(
        '${results.successful.length} of $total events propagated (${successRate.toStringAsFixed(0)}% success)',
        action: SnackBarAction(
          label: 'Details',
          onPressed: () => _showBatchDetails(results),
        ),
      );
    }
  }

  /// Show detailed batch results
  void _showBatchDetails(BatchPropagationResult results) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Propagation Results'),
        content: DialogScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (results.successful.isNotEmpty) ...[
                Text(
                  'Successful (${results.successful.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...results.successful.map(
                  (success) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${success.event.eventTypeId} - ${success.propagatedCount} parents',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (results.failed.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Failed (${results.failed.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...results.failed.map(
                  (failure) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                failure.event.eventTypeId,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                failure.error,
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(color: Colors.red, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Extension to make event propagation even simpler
extension EventPropagationExtension on Event {
  /// Quick propagation with sensible defaults
  ///
  /// Usage:
  /// ```dart
  /// await event.propagateFrom(context);
  /// ```
  Future<void> propagateFrom(
    BuildContext context, {
    String? activityType,
    String? description,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      NavigationCubit? navigationState;
      try {
        navigationState = context.read<NavigationCubit>();
      } catch (_) {
        return;
      }
      if (navigationState.isClosed) return;
      final currentNode = navigationState.currentNode;

      if (currentNode == null) return;

      final propagationService = context.read<EventPropagationService?>();
      if (propagationService == null) {
        LoggingService.instance.warning(
          'EventPropagationService not found in context; quick propagation skipped for $eventTypeId',
        );
        return;
      }

      await propagationService.propagateToParents(
        sourceEvent: this,
        sourceNode: currentNode,
        activityType: activityType ?? _getDefaultActivityType(),
        description: description,
        parameters: parameters,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Quick propagation failed', e, stackTrace);
    }
  }

  String _getDefaultActivityType() {
    final words = eventTypeId.split('_');
    return words
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Request for batch event propagation
class EventPropagationRequest {
  final Event event;
  final String activityType;
  final String? description;
  final Map<String, dynamic>? parameters;
  final GraphNode? sourceNode; // Optional, uses current if null

  const EventPropagationRequest({
    required this.event,
    required this.activityType,
    this.description,
    this.parameters,
    this.sourceNode,
  });
}

/// Result of batch propagation
class BatchPropagationResult {
  final List<PropagationSuccess> successful = [];
  final List<PropagationFailure> failed = [];

  bool get hasFailures => failed.isNotEmpty;
  bool get isFullySuccessful => failed.isEmpty;
  double get successRate {
    final total = successful.length + failed.length;
    return total > 0 ? successful.length / total : 0;
  }
}

/// Successful propagation record
class PropagationSuccess {
  final Event event;
  final int propagatedCount;

  const PropagationSuccess({
    required this.event,
    required this.propagatedCount,
  });
}

/// Failed propagation record
class PropagationFailure {
  final Event event;
  final String error;

  const PropagationFailure({required this.event, required this.error});
}
