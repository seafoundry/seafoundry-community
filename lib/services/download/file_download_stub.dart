// @tier: community
import 'dart:typed_data';

import 'package:seafoundry_app/services/download/file_download_interface.dart';

FileDownloadAdapter createFileDownloadAdapter() =>
    const _UnsupportedFileDownloadAdapter();

class _UnsupportedFileDownloadAdapter extends FileDownloadAdapter {
  const _UnsupportedFileDownloadAdapter();

  @override
  bool get isSupported => false;

  @override
  Future<void> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    throw UnsupportedError(
      'Binary downloads are not supported on this platform.',
    );
  }
}
