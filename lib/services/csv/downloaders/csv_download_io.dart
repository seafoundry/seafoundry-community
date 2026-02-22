// @tier: community
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:seafoundry_app/services/csv/downloaders/csv_download_interface.dart';
import 'package:seafoundry_app/services/logging_service.dart';

CsvDownloadAdapter createCsvDownloadAdapter() => _IoCsvDownloadAdapter();

class _IoCsvDownloadAdapter extends CsvDownloadAdapter {
  Directory? _cachedDirectory;

  @override
  bool get isSupported => true;

  @override
  Future<void> save({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    final directory = await _resolveDirectory();
    final sanitizedName = _sanitizeFileName(fileName, mimeType);
    final filePath = _join(directory.path, sanitizedName);
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(content);
    LoggingService.instance.info('CSV saved to ${file.path}');
  }

  Future<Directory> _resolveDirectory() async {
    if (_cachedDirectory != null) return _cachedDirectory!;
    Directory? directory;

    try {
      directory = await getDownloadsDirectory();
    } catch (e) {
      LoggingService.instance.debug(
        'Downloads directory unavailable, falling back to documents: $e',
      );
    }

    directory ??= await getApplicationDocumentsDirectory();
    _cachedDirectory = directory;
    return directory;
  }

  String _sanitizeFileName(String fileName, String mimeType) {
    final trimmed = fileName.trim();
    final candidate = (trimmed.isEmpty ? 'export' : trimmed)
        .replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');
    if (mimeType == 'text/csv' &&
        !candidate.toLowerCase().endsWith('.csv')) {
      return '$candidate.csv';
    }
    if (mimeType == 'image/png' &&
        !candidate.toLowerCase().endsWith('.png')) {
      return '$candidate.png';
    }
    return candidate;
  }

  String _join(String directoryPath, String fileName) {
    if (directoryPath.endsWith(Platform.pathSeparator)) {
      return '$directoryPath$fileName';
    }
    return '$directoryPath${Platform.pathSeparator}$fileName';
  }
}
