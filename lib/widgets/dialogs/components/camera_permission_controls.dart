// @tier: community
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Standardized camera permission helper used by dialogs that capture images.
///
/// The widget renders a single button whose label/icon adapts to the current
/// [permissionStatus]:
/// - `granted`: shows the capture label and calls [onCapture]
/// - `denied`: shows the request label and calls [onRequestPermission]
/// - `permanentlyDenied`: shows the settings label and calls [onOpenSettings]
///
/// If permission is denied, an inline notice is displayed so dialogs don't
/// need to duplicate copy/patterns.
class CameraPermissionControls extends StatelessWidget {
  const CameraPermissionControls({
    super.key,
    required this.permissionStatus,
    required this.isBusy,
    required this.onCapture,
    required this.onRequestPermission,
    this.onOpenSettings,
    this.enabled = true,
    this.captureLabel = 'Capture Photo',
    this.requestPermissionLabel = 'Request Camera Permission',
    this.settingsLabel = 'Open Settings',
    this.busyLabel = 'Capturing...',
    this.permissionDeniedMessage =
        'Camera access is currently denied. Grant permission when prompted to attach photos.',
    this.permissionPermanentlyDeniedMessage =
        'Camera access is disabled for SeaFoundry. Enable it in system settings to attach evidence.',
  });

  final PermissionStatus? permissionStatus;
  final bool isBusy;
  final bool enabled;
  final VoidCallback onCapture;
  final VoidCallback onRequestPermission;
  final VoidCallback? onOpenSettings;
  final String captureLabel;
  final String requestPermissionLabel;
  final String settingsLabel;
  final String busyLabel;
  final String permissionDeniedMessage;
  final String permissionPermanentlyDeniedMessage;

  @override
  Widget build(BuildContext context) {
    final status = permissionStatus;
    final granted = status == PermissionStatus.granted;
    final permanentlyDenied = status == PermissionStatus.permanentlyDenied;
    final denied = status == PermissionStatus.denied;
    final effectiveLabel = isBusy
        ? busyLabel
        : granted
        ? captureLabel
        : permanentlyDenied
        ? settingsLabel
        : requestPermissionLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          icon: Icon(granted ? Icons.camera_alt : Icons.camera_alt_outlined),
          label: Text(effectiveLabel),
          onPressed: (!enabled || isBusy)
              ? null
              : () {
                  if (granted) {
                    onCapture();
                  } else if (permanentlyDenied) {
                    if (onOpenSettings != null) {
                      onOpenSettings!();
                    } else {
                      openAppSettings();
                    }
                  } else {
                    onRequestPermission();
                  }
                },
        ),
        if (permanentlyDenied || denied) ...[
          const SizedBox(height: 8),
          _PermissionNotice(
            message: permanentlyDenied
                ? permissionPermanentlyDeniedMessage
                : permissionDeniedMessage,
          ),
        ],
      ],
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
