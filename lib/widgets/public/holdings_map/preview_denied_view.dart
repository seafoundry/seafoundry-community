// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/public/public_preview_access_service.dart';

/// View shown when preview access is denied.
class PreviewDeniedView extends StatelessWidget {
  const PreviewDeniedView({
    super.key,
    required this.reason,
  });

  final PreviewAccessBlockReason? reason;

  @override
  Widget build(BuildContext context) {
    final message = reason == PreviewAccessBlockReason.unauthenticated
        ? 'Sign in as an organization admin to preview unpublished map data.'
        : 'Preview is limited to organization admins. Publish holdings/outplants '
            'to share this map.';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.https_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Preview unavailable',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
