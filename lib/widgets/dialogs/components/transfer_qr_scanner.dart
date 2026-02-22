// @tier: community
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR code scanner component for transfer manifest scanning.
class TransferQrScanner extends StatelessWidget {
  const TransferQrScanner({
    super.key,
    required this.controller,
    required this.onCapture,
    required this.enabled,
  });

  final MobileScannerController controller;
  final bool enabled;
  final void Function(BarcodeCapture data) onCapture;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'QR scanning is not available on web. Paste the manifest payload below.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueGrey.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MobileScanner(controller: controller, onDetect: onCapture),
        ),
      ),
    );
  }
}
