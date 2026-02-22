// @tier: community
import 'dart:typed_data';

import 'package:seafoundry_app/services/download/file_download_interface.dart';
import 'package:universal_html/html.dart' as html;

FileDownloadAdapter createFileDownloadAdapter() =>
    const _WebFileDownloadAdapter();

class _WebFileDownloadAdapter extends FileDownloadAdapter {
  const _WebFileDownloadAdapter();

  @override
  bool get isSupported => true;

  @override
  Future<void> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
