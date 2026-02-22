// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/firestore_recovery_service.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Displays a subtle banner when Firestore stream recovery is in progress.
///
/// Place this widget above your main content (e.g., in a Column) to show
/// users that the app is automatically recovering from a connection issue.
///
/// The banner automatically hides when the connection is healthy.
class FirestoreRecoveryBanner extends StatelessWidget {
  const FirestoreRecoveryBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FirestoreRecoveryEvent>(
      stream: FirestoreRecoveryService.instance.recoveryStream,
      initialData: FirestoreRecoveryService.instance.currentEvent,
      builder: (context, snapshot) {
        // Handle stream errors gracefully - just show child without banner
        if (snapshot.hasError) {
          return child;
        }

        final event = snapshot.data;
        final state = event?.state ?? FirestoreRecoveryState.healthy;

        // Only show banner for non-healthy states
        final showBanner = state != FirestoreRecoveryState.healthy;

        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: showBanner
                  ? _RecoveryBannerContent(event: event!)
                  : const SizedBox.shrink(),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _RecoveryBannerContent extends StatelessWidget {
  const _RecoveryBannerContent({required this.event});

  final FirestoreRecoveryEvent event;

  @override
  Widget build(BuildContext context) {
    final (message, icon, color) = _getDisplayInfo(event.state);

    return Material(
      color: color.withValues(alpha: 0.1),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UI.spacingMd,
            vertical: UI.spacingSm,
          ),
          child: Row(
            children: [
              if (event.state == FirestoreRecoveryState.reconnecting ||
                  event.state == FirestoreRecoveryState.clearingCache)
                Padding(
                  padding: const EdgeInsets.only(right: UI.spacingSm),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: UI.spacingSm),
                  child: Icon(icon, size: 16, color: color),
                ),
              Expanded(
                child: Text(
                  _buildMessage(message, event),
                  style: TextStyle(
                    fontSize: UI.fontSizeXs,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (event.state == FirestoreRecoveryState.failed)
                TextButton(
                  onPressed: () {
                    FirestoreRecoveryService.instance.forceRecoveryAll();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: UI.fontSizeXs,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (event.state == FirestoreRecoveryState.recovered)
                IconButton(
                  onPressed: () {
                    FirestoreRecoveryService.instance.resetToHealthy();
                  },
                  icon: Icon(Icons.close, size: 16, color: color),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }

  (String, IconData, Color) _getDisplayInfo(FirestoreRecoveryState state) {
    return switch (state) {
      FirestoreRecoveryState.healthy => ('', Icons.check_circle, UI.successColor),
      FirestoreRecoveryState.errorDetected => (
          'Connection issue detected',
          Icons.warning_amber,
          UI.warningColor,
        ),
      FirestoreRecoveryState.reconnecting => (
          'Reconnecting',
          Icons.sync,
          UI.primaryColor,
        ),
      FirestoreRecoveryState.recovered => (
          'Connection restored',
          Icons.check_circle,
          UI.successColor,
        ),
      FirestoreRecoveryState.failed => (
          'Connection failed',
          Icons.error_outline,
          UI.errorColor,
        ),
      FirestoreRecoveryState.clearingCache => (
          'Clearing cache',
          Icons.cleaning_services,
          UI.primaryColor,
        ),
    };
  }

  String _buildMessage(String base, FirestoreRecoveryEvent event) {
    if (event.attemptNumber != null &&
        event.state == FirestoreRecoveryState.reconnecting) {
      return '$base (attempt ${event.attemptNumber}/${FirestoreRecoveryService.maxRetryAttempts})';
    }
    return base;
  }
}
