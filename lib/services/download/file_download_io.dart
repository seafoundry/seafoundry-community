// @tier: community
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:seafoundry_app/services/download/file_download_interface.dart';
import 'package:seafoundry_app/services/logging_service.dart';

FileDownloadAdapter createFileDownloadAdapter() => _IoFileDownloadAdapter();

class _IoFileDownloadAdapter extends FileDownloadAdapter {
  Directory? _cachedDirectory;

  @override
  bool get isSupported => true;

  @override
  Future<void> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final directory = await _resolveDirectory();
    final sanitized = _sanitizeFileName(fileName);
    final path = _join(directory.path, sanitized);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    LoggingService.instance.info('File saved to $path');
  }

  Future<Directory> _resolveDirectory() async {
    if (_cachedDirectory != null) return _cachedDirectory!;

    Directory? resolved;
    try {
      resolved = await getDownloadsDirectory();
    } catch (error) {
      LoggingService.instance.debug(
        'Downloads directory unavailable, using documents directory: $error',
      );
    }
    resolved ??= await getApplicationDocumentsDirectory();
    _cachedDirectory = resolved;
    return resolved;
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    final sanitized = (trimmed.isEmpty ? 'download' : trimmed).replaceAll(
      RegExp(r'[<>:"/\\|?*]+'),
      '_',
    );
    if (sanitized.contains('.')) {
      return sanitized;
    }
    return '$sanitized.bin';
  }

  String _join(String directoryPath, String fileName) {
    if (directoryPath.endsWith(Platform.pathSeparator)) {
      return '$directoryPath$fileName';
    }
    return '$directoryPath${Platform.pathSeparator}$fileName';
  }
}
