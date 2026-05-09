
/// Defines the platform-specific contract for saving CSV content.
abstract class CsvDownloadAdapter {
  const CsvDownloadAdapter();

  /// Whether this adapter can handle downloads on the current platform.
  bool get isSupported;

  /// Persists the CSV [content] using the provided [fileName] and [mimeType].
  Future<void> save({
    required String content,
    required String fileName,
    required String mimeType,
  });
}
