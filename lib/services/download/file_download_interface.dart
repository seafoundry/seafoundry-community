// @tier: community
import 'dart:typed_data';

/// Defines a platform-specific contract for saving arbitrary binary payloads.
abstract class FileDownloadAdapter {
  const FileDownloadAdapter();

  /// Whether downloads are supported on the current platform.
  bool get isSupported;

  /// Persists the provided [bytes] as [fileName] using the given [mimeType].
  Future<void> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });
}
