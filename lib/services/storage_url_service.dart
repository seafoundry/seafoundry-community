// @tier: community
import 'package:firebase_storage/firebase_storage.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Resolves Firebase Storage `gs://` URLs into launchable HTTPS URLs.
///
/// Attempts `getDownloadURL()` first (works for private buckets). If that
/// fails, falls back to the public `storage.googleapis.com` endpoint for
/// buckets that allow public access.
class StorageUrlService {
  StorageUrlService({
    FirebaseStorage? storage,
    LoggingService? logger,
  })  : _storage = storage ?? FirebaseService.instance.storage,
        _logger = logger ?? LoggingService.instance;

  final FirebaseStorage _storage;
  final LoggingService _logger;

  static final StorageUrlService instance = StorageUrlService();

  Future<Uri?> resolveLaunchUri(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (uri.scheme != 'gs') {
      return uri;
    }

    try {
      final downloadUrl = await _storage.refFromURL(trimmed).getDownloadURL();
      final downloadUri = Uri.tryParse(downloadUrl);
      if (downloadUri != null) {
        return downloadUri;
      }
    } catch (error) {
      _logger.warning('StorageUrlService: Failed to resolve $trimmed', error);
    }

    return _buildPublicStorageUri(uri);
  }

  Uri? _buildPublicStorageUri(Uri gsUri) {
    if (gsUri.scheme != 'gs') return null;
    final bucket = gsUri.host;
    final path = gsUri.path.startsWith('/') ? gsUri.path.substring(1) : gsUri.path;
    if (bucket.isEmpty || path.isEmpty) return null;
    return Uri.https('storage.googleapis.com', '$bucket/$path');
  }
}
